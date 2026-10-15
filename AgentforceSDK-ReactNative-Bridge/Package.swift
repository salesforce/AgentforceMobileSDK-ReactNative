// swift-tools-version: 6.0
import Foundation
import PackageDescription

// React Native 0.87 creates these packages in the consuming app before SwiftPM
// resolves third-party native modules. SwiftPM sandboxes manifest evaluation,
// so checking whether the generated files exist outside this package fails.
// Derive the app root from the npm installation path instead.
let packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let bridgePrefix = FileManager.default.fileExists(
    atPath: packageDirectory.appendingPathComponent("AgentforceSDK-ReactNative-Bridge/ios/Agentforce").path
) ? "AgentforceSDK-ReactNative-Bridge/" : ""

func reactNativeBuildDirectory() -> URL {
    let components = packageDirectory.pathComponents
    if let nodeModulesIndex = components.firstIndex(of: "node_modules") {
        return URL(fileURLWithPath: NSString.path(withComponents: Array(components[..<nodeModulesIndex])))
            .appendingPathComponent("ios/build")
    }
    // Keep the source checkout inspectable from both manifest entry points.
    return packageDirectory.appendingPathComponent("ios/build")
}

let reactNativeBuild = reactNativeBuildDirectory()
let reactNativeHeaders: [Target.Dependency] = [
    .product(name: "ReactHeaders", package: "ReactNative"),
    .product(name: "ReactNativeHeaders", package: "ReactNative"),
    .product(name: "ReactNativeDependenciesHeaders", package: "ReactNative"),
    .product(name: "ReactAppHeaders", package: "React-GeneratedCode"),
]

let package = Package(
    name: "ReactNativeAgentforce",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ReactNativeAgentforce", targets: ["ReactNativeAgentforceSwift", "ReactNativeAgentforceObjC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/salesforce/AgentforceMobileSDK-iOS.git", from: "19.29.3"),
        .package(url: "https://github.com/forcedotcom/SalesforceMobileInterfaces-iOS.git", from: "1.0.0"),
        .package(name: "ReactNative", path: reactNativeBuild.appendingPathComponent("xcframeworks").path),
        .package(name: "React-GeneratedCode", path: reactNativeBuild.appendingPathComponent("generated/ios").path),
    ],
    targets: [
        .target(
            name: "ReactNativeAgentforceSwift",
            dependencies: reactNativeHeaders + [
                .product(name: "AgentforceSDK", package: "AgentforceMobileSDK-iOS"),
                .product(name: "AgentforceVoice", package: "AgentforceMobileSDK-iOS"),
                .product(name: "SalesforceLogging", package: "SalesforceMobileInterfaces-iOS"),
                .product(name: "SalesforceNavigation", package: "SalesforceMobileInterfaces-iOS"),
                .product(name: "SalesforceNetwork", package: "SalesforceMobileInterfaces-iOS"),
                .product(name: "SalesforceUser", package: "SalesforceMobileInterfaces-iOS"),
            ],
            path: "\(bridgePrefix)ios/Agentforce",
            exclude: ["ObjC"],
            swiftSettings: [.define("SPM_BUILD")]
        ),
        .target(
            name: "ReactNativeAgentforceObjC",
            dependencies: reactNativeHeaders,
            path: "\(bridgePrefix)ios/Agentforce/ObjC",
            publicHeadersPath: "include"
        ),
    ],
    swiftLanguageModes: [.v5]
)
