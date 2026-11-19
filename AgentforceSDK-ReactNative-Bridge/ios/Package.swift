// swift-tools-version: 6.0
import Foundation
import PackageDescription

// React Native 0.87+ generates these local packages in the consuming app.
// Resolve the first node_modules ancestor, including pnpm's nested store
// layout. The override permits validating a source checkout against a test app.
let manifestPath = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().path
let appRoot = ProcessInfo.processInfo.environment["AGENTFORCE_RN_SPM_APP_ROOT"]
    ?? manifestPath.range(of: "/node_modules/").map { String(manifestPath[..<$0.lowerBound]) }
    ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let rnBuildRoot = URL(fileURLWithPath: appRoot).appendingPathComponent("ios/build")

let reactHeaders: [Target.Dependency] = [
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
        // This release manifest selects the -spm XCFrameworks and their matched
        // AgentforceService binary. Do not add the Service package separately.
        .package(url: "https://github.com/salesforce/AgentforceMobileSDK-iOS.git", exact: "264.1.0"),
        .package(url: "https://github.com/forcedotcom/SalesforceMobileInterfaces-iOS.git", from: "1.0.0"),
        .package(name: "ReactNative", path: rnBuildRoot.appendingPathComponent("xcframeworks").path),
        .package(name: "React-GeneratedCode", path: rnBuildRoot.appendingPathComponent("generated/ios").path),
    ],
    targets: [
        .target(
            name: "ReactNativeAgentforceSwift",
            dependencies: reactHeaders + [
                .product(name: "AgentforceSDK", package: "AgentforceMobileSDK-iOS"),
                .product(name: "AgentforceVoice", package: "AgentforceMobileSDK-iOS"),
                .product(name: "SalesforceLogging", package: "SalesforceMobileInterfaces-iOS"),
                .product(name: "SalesforceNavigation", package: "SalesforceMobileInterfaces-iOS"),
                .product(name: "SalesforceNetwork", package: "SalesforceMobileInterfaces-iOS"),
                .product(name: "SalesforceUser", package: "SalesforceMobileInterfaces-iOS"),
            ],
            path: "Agentforce",
            exclude: ["ObjC"]
        ),
        .target(
            name: "ReactNativeAgentforceObjC",
            dependencies: reactHeaders,
            path: "Agentforce/ObjC",
            publicHeadersPath: "include"
        ),
    ],
    swiftLanguageModes: [.v5]
)
