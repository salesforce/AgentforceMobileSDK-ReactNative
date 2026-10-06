/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Reads the mounted Fabric root's content height. The surface hosting view can
 * remain at its temporary 1-point size after its child has laid out, so its
 * own sizeThatFits and intrinsicContentSize are not always useful to SwiftUI.
 */

import UIKit

enum FabricContentHeight {
    static func height(in view: UIView) -> CGFloat? {
        if NSStringFromClass(type(of: view)).hasSuffix("RCTRootComponentView") {
            let height = view.bounds.height
            return height.isFinite ? height : nil
        }
        for child in view.subviews {
            if let height = height(in: child) {
                return height
            }
        }
        return nil
    }
}
