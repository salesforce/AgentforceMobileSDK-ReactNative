/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge navigation bar builder for Agentforce SDK
 */

import Foundation
import AgentforceSDK

/// Navigation bar builder that overrides the conversation header title with a
/// client-supplied agent label.
///
/// The Employee Agent `agentLabel` from the JS config has no first-class field on
/// `AgentforceConfiguration`, and `createAgentforceChatView` exposes no title
/// parameter. The only public hook for the header title is `NavigationBarBuilder`,
/// which lets the host set `toolbarItems.title` per screen.
///
/// Behavior: when a non-empty label is provided, it is applied to the main
/// conversation screen's title (client wins). When the label is empty/nil, no
/// builder is installed at all (see `AgentforceModule`), so the SDK falls back to
/// the server-provided agent label / default. `showDefaults` is left at its
/// default (`true`) so the close button and overflow menu are preserved.
final class BridgeNavigationBarBuilder: NavigationBarBuilder {

    var handleNavigation: HandleNavigationClosure?
    weak var refreshHandler: NavigationRefreshable?

    /// - Parameter agentLabel: Non-empty client-supplied label to display as the
    ///   conversation header title.
    init(agentLabel: String) {
        handleNavigation = { screenType, toolbarItems, _ in
            // Only override the main conversation feed title. Form / pre-chat /
            // onboarding screens keep their own SDK-provided titles.
            if screenType == .conversation {
                toolbarItems.title = agentLabel
            }
        }
    }
}
