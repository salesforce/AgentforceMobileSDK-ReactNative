import Foundation

/// Platform-neutral props passed to a registered React Native view.
struct BridgeViewComponentData {
    let definition: String
    let name: String?
    let properties: [String: Any]
    let subComponents: [BridgeViewComponentData]

    /// The currently pinned iOS SDK has no `name` member. Read it when a newer
    /// SDK supplies one without making this bridge source require that release.
    static func name(of component: Any) -> String? {
        Mirror(reflecting: component).descendant("name") as? String
    }

    var props: [String: Any] {
        var result: [String: Any] = [
            "definition": definition,
            "properties": properties,
        ]
        if let name {
            result["name"] = name
        }
        if !subComponents.isEmpty {
            result["subComponents"] = subComponents.map(\.props)
        }
        return result
    }
}
