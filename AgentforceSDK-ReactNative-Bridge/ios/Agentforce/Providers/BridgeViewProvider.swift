/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Bridges the native AgentforceViewProviding protocol to React Native.
 * When enabled, delegates rendering of specified component types to a
 * registered React Native component in the host app's runtime.
 */

import Foundation
import UIKit
import SwiftUI
import React
import AgentforceSDK

/// Implements AgentforceViewProviding by delegating to a React Native component.
/// Component types are registered synchronously from JS.
class BridgeViewProvider: AgentforceViewProviding {

    /// Maps component definition strings to React Native component names (1:1).
    /// e.g. ["copilot/richText": "CustomRichTextView", "copilot/markdown": "CustomMarkdownView"]
    /// Protected by `lock` — `canHandle` may be called from the SDK rendering thread
    /// while `register`/`reset` are called from the JS thread.
    private var componentMap: [String: String] = [:]

    /// Protects all reads/writes to `componentMap`.
    private let lock = NSLock()

    /// Reference to the RCT bridge for creating root views
    private weak var bridge: RCTBridge?

    init(bridge: RCTBridge?) {
        self.bridge = bridge
    }

    /// Register a 1:1 mapping of component definition strings to React component names.
    /// Called from JS via the native module before launching conversation.
    func register(componentMap: [String: String]) {
        lock.withLock { self.componentMap = componentMap }
    }

    /// Clear all registrations
    func reset() {
        lock.withLock { componentMap.removeAll() }
    }

    var isRegistered: Bool {
        lock.withLock { !componentMap.isEmpty }
    }

    // MARK: - AgentforceViewProviding

    func canHandle(type: String) -> Bool {
        lock.withLock { componentMap[type] != nil }
    }

    @MainActor
    func view(for type: String, data: [String: Any]) -> AnyView {
        guard let moduleName = lock.withLock({ componentMap[type] }) else {
            return AnyView(EmptyView())
        }
        // Note: The iOS SDK protocol only provides (type, data). Android's SDK
        // provides a full AgentforceComponent with name and subComponents.
        // Consumers should handle missing name/subComponents gracefully.
        let props: [String: Any] = [
            "definition": type,
            "properties": data,
        ]
        return AnyView(ReactNativeViewWrapper(
            bridge: bridge,
            moduleName: moduleName,
            initialProperties: props
        ))
    }
}

// MARK: - SwiftUI wrapper for React Native root views

/// Wraps a legacy root or Fabric surface in a UIViewRepresentable for SwiftUI.
private struct ReactNativeViewWrapper: View {
    @State private var fabricHeight: CGFloat?

    let bridge: RCTBridge?
    let moduleName: String
    let initialProperties: [String: Any]

    var body: some View {
        ReactNativeRootView(
            bridge: bridge,
            moduleName: moduleName,
            initialProperties: initialProperties,
            measuredHeight: fabricHeight,
            onFabricHeightChange: { fabricHeight = $0 }
        )
        .frame(height: fabricHeight)
    }
}

private struct ReactNativeRootView: UIViewRepresentable {
    let bridge: RCTBridge?
    let moduleName: String
    let initialProperties: [String: Any]
    let measuredHeight: CGFloat?
    let onFabricHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onHeightChange: onFabricHeightChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = AgentforceReactNativeRootView.makeView(
            bridge: bridge,
            moduleName: moduleName,
            initialProperties: initialProperties,
            sizeFlexibility: .widthAndHeight
        )
        if let rootView = view as? RCTSurfaceHostingProxyRootView {
            context.coordinator.observe(rootView)
        }
        return view
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // React Native updates the hosted view through its runtime. Refresh the
        // callback when SwiftUI recreates this value around an existing UIView.
        context.coordinator.onHeightChange = onFabricHeightChange
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        let proposedWidth = proposal.width ?? 0
        let width = proposedWidth.isFinite && proposedWidth > 0
            ? proposedWidth
            : UIScreen.main.bounds.width
        if uiView is RCTSurfaceHostingProxyRootView,
           let measuredHeight {
            return CGSize(width: width, height: measuredHeight)
        }
        let maxHeight: CGFloat = uiView is RCTSurfaceHostingProxyRootView
            ? 10_000
            : CGFloat.greatestFiniteMagnitude
        let size = uiView.sizeThatFits(CGSize(width: width, height: maxHeight))
        if size.height <= 0, uiView is RCTSurfaceHostingProxyRootView {
            // The Fabric surface initially measures zero while preparing. Give it
            // a frame so it can mount and report its actual content height.
            return CGSize(width: width, height: 1)
        }
        guard size.height > 0 else { return nil }
        return CGSize(width: width, height: size.height)
    }

    final class Coordinator: NSObject, RCTRootViewDelegate {
        private weak var rootView: RCTSurfaceHostingProxyRootView?
        private var timer: Timer?
        private var lastHeight: CGFloat = 0
        var onHeightChange: (CGFloat) -> Void

        init(onHeightChange: @escaping (CGFloat) -> Void) {
            self.onHeightChange = onHeightChange
        }

        func observe(_ rootView: RCTSurfaceHostingProxyRootView) {
            self.rootView = rootView
            rootView.delegate = self
            // Fabric can change a mounted root component's frame without a
            // corresponding intrinsic-size notification. Keep observing while
            // this view is mounted, including while its parent is scrolling.
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.measure()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func stopObserving() {
            timer?.invalidate()
            timer = nil
            rootView?.delegate = nil
        }

        func rootViewDidChangeIntrinsicSize(_ rootView: RCTRootView) {
            DispatchQueue.main.async { [weak self] in self?.measure() }
        }

        private func measure() {
            guard let rootView, rootView.window != nil, rootView.bounds.width > 0 else { return }
            // Prefer the Fabric component's rendered frame. In the bridgeless
            // path it can already be 160pt while the proxy and surface still
            // report the 1pt fallback supplied by sizeThatFits below.
            let contentHeight = FabricContentHeight.height(in: rootView.view)
            let intrinsicHeight = rootView.intrinsicContentSize.height
            let height: CGFloat
            if let contentHeight, contentHeight > 1 || (lastHeight > 0 && contentHeight >= 0) {
                height = contentHeight
            } else if intrinsicHeight.isFinite, intrinsicHeight > 1 {
                height = intrinsicHeight
            } else {
                let fittingHeight = rootView.sizeThatFits(
                    CGSize(width: rootView.bounds.width, height: 10_000)
                ).height
                if fittingHeight.isFinite, fittingHeight > 1 {
                    height = fittingHeight
                } else {
                    return // Never publish the temporary 1pt host as content.
                }
            }
            guard abs(height - lastHeight) > 0.5 else { return }
            lastHeight = height
            DispatchQueue.main.async { [weak self] in
                guard let self, self.rootView != nil else { return }
                self.onHeightChange(height)
            }
        }
    }
}
