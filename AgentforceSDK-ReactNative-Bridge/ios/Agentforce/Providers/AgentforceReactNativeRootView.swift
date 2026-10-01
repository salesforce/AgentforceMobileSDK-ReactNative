/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Creates React Native roots inside the host app's existing runtime. Bridgeless
 * apps register their root view factory at startup; apps with a real RCTBridge
 * keep using RCTRootView without any additional setup.
 */

import UIKit
import React

@MainActor
public enum AgentforceReactNativeRootView {
    public typealias Factory = (_ moduleName: String, _ initialProperties: [String: Any]) -> UIView

    private static var factory: Factory?

    /// Register the host app's root view factory before showing an Agentforce conversation.
    /// Pass a closure backed by the app's existing RCTReactNativeFactory.rootViewFactory.
    public static func registerFactory(_ factory: @escaping Factory) {
        self.factory = factory
    }

    public static func clearFactory() {
        factory = nil
    }

    static func makeView(
        bridge: RCTBridge?,
        moduleName: String,
        initialProperties: [String: Any],
        sizeFlexibility: RCTRootViewSizeFlexibility
    ) -> UIView {
        let view: UIView
        if let bridge, bridge.isValid {
            view = RCTRootView(
                bridge: bridge,
                moduleName: moduleName,
                initialProperties: initialProperties
            )
        } else if let factory {
            view = factory(moduleName, initialProperties)
        } else {
            NSLog("[Agentforce] Cannot render React Native component '%@': register the host root view factory for bridgeless iOS apps", moduleName)
            return UIView()
        }

        view.backgroundColor = .clear
        if let rootView = view as? RCTRootView {
            rootView.sizeFlexibility = sizeFlexibility
        } else if let rootView = view as? RCTSurfaceHostingProxyRootView {
            // Fabric needs a real width to compute its content height.
            rootView.sizeFlexibility = sizeFlexibility == .widthAndHeight ? .height : sizeFlexibility
        }
        return view
    }
}
