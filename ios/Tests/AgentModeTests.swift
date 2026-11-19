/*
 * Unit tests for AgentMode config parsing.
 *
 * AgentMode.swift is Foundation-only and is compiled directly into this test
 * bundle (see ios/project.yml -> BridgeUnitTests), so its internal types are
 * visible here without importing the (pod-delivered) bridge module.
 */
import XCTest

final class AgentModeTests: XCTestCase {

    // MARK: - typeString

    func testTypeStringReflectsVariant() {
        let service = AgentMode.service(
            config: ServiceAgentModeConfig(
                serviceApiURL: "https://x",
                organizationId: "00D",
                esDeveloperName: "Agent",
                serviceUISettings: nil
            )
        )
        let employee = AgentMode.employee(
            config: EmployeeAgentModeConfig(
                instanceUrl: "https://x",
                organizationId: "00D",
                userId: "005",
                agentId: nil,
                agentLabel: nil,
                accessToken: "tok",
                authentication: .legacy(accessToken: "tok")
            )
        )
        XCTAssertEqual("service", service.typeString)
        XCTAssertEqual("employee", employee.typeString)
    }

    // MARK: - ServiceAgentModeConfig.from(dictionary:)

    func testServiceConfigParsesRequiredFields() {
        let config = ServiceAgentModeConfig.from(dictionary: [
            "serviceApiURL": "https://service",
            "organizationId": "00D",
            "esDeveloperName": "MyAgent",
        ])
        XCTAssertEqual("https://service", config?.serviceApiURL)
        XCTAssertEqual("00D", config?.organizationId)
        XCTAssertEqual("MyAgent", config?.esDeveloperName)
        XCTAssertNil(config?.serviceUISettings)
    }

    func testServiceConfigIsNilWhenFieldMissing() {
        let config = ServiceAgentModeConfig.from(dictionary: [
            "serviceApiURL": "https://service",
            "organizationId": "00D",
            // esDeveloperName missing
        ])
        XCTAssertNil(config)
    }

    func testServiceConfigParsesUISettings() {
        let config = ServiceAgentModeConfig.from(dictionary: [
            "serviceApiURL": "https://service",
            "organizationId": "00D",
            "esDeveloperName": "MyAgent",
            "serviceUISettings": ["downloadTranscript": false, "endConversation": true],
        ])
        XCTAssertEqual(false, config?.serviceUISettings?["downloadTranscript"])
        XCTAssertEqual(true, config?.serviceUISettings?["endConversation"])
    }

    func testServiceConfigLetsSDKDeriveForceConfigEndpoint() {
        let serviceApiURL = "https://example.sandbox.my.salesforce-scrt.com"
        let config = ServiceAgentModeConfig.from(dictionary: [
            "serviceApiURL": serviceApiURL,
            "organizationId": "00D",
            "esDeveloperName": "MyAgent",
        ])

        XCTAssertEqual(serviceApiURL, config?.serviceApiURL)
        XCTAssertEqual("", config?.forceConfigEndPoint)
    }

    // MARK: - EmployeeAgentModeConfig.from(dictionary:)

    private func identityConfig(
        _ authentication: EmployeeAuthentication = .directOAuth(accessToken: "old-token"),
        instanceUrl: String = "https://myorg",
        organizationId: String = "00D",
        userId: String = "005"
    ) -> EmployeeAgentModeConfig {
        EmployeeAgentModeConfig(
            instanceUrl: instanceUrl, organizationId: organizationId, userId: userId,
            agentId: nil, agentLabel: nil, accessToken: "", authentication: authentication
        )
    }

    func testTokenOnlyRefreshPreservesEmployeeClientIdentity() {
        XCTAssertTrue(identityConfig().hasSameIdentity(as: identityConfig(.directOAuth(accessToken: "new-token"))))
        XCTAssertTrue(
            identityConfig(.legacy(accessToken: "old-token"))
                .hasSameIdentity(as: identityConfig(.legacy(accessToken: "new-token")))
        )
    }

    func testUserOrgAndInstanceChangesInvalidateEmployeeClientIdentity() {
        for changed in [
            identityConfig(instanceUrl: "https://other-org"),
            identityConfig(organizationId: "other-org-id"),
            identityConfig(userId: "other-user-id"),
        ] {
            XCTAssertFalse(identityConfig().hasSameIdentity(as: changed))
        }
    }

    func testEveryAuthenticationSourceTransitionInvalidatesEmployeeClientIdentity() {
        let sources: [EmployeeAuthentication] = [
            .legacy(accessToken: "token"), .directOAuth(accessToken: "token"), .mobileSDKOAuth,
        ]
        for (previousIndex, previous) in sources.enumerated() {
            for (nextIndex, next) in sources.enumerated() {
                XCTAssertEqual(previousIndex == nextIndex, identityConfig(previous).hasSameIdentity(as: identityConfig(next)))
            }
        }
    }

    func testEmployeeConfigParsesRequiredFieldsAndAgentId() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
            "agentId": "0Xa",
        ])
        XCTAssertEqual("https://myorg", config?.instanceUrl)
        XCTAssertEqual("005", config?.userId)
        XCTAssertEqual("tok", config?.accessToken)
        XCTAssertEqual("0Xa", config?.agentId)
    }

    func testEmployeeConfigTreatsEmptyAgentIdAsNil() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
            "agentId": "",
        ])
        XCTAssertNotNil(config)
        XCTAssertNil(config?.agentId)
    }

    func testEmployeeConfigParsesOptionalAgentLabel() {
        let withLabel = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
            "agentLabel": "Support Bot",
        ])
        XCTAssertEqual("Support Bot", withLabel?.agentLabel)

        let withoutLabel = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
        ])
        XCTAssertNil(withoutLabel?.agentLabel)
    }

    func testDirectAgentInfoSeedUsesExplicitAgentAndVoiceSetting() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
            "agentId": "0Xa",
            "agentLabel": "Support Bot",
        ])

        XCTAssertEqual(
            DirectAgentInfoSeed(agentId: "0Xa", label: "Support Bot", isVoiceEnabled: true),
            config?.directAgentInfoSeed(enableVoice: true)
        )
        XCTAssertEqual(
            DirectAgentInfoSeed(agentId: "0Xa", label: "Support Bot", isVoiceEnabled: false),
            config?.directAgentInfoSeed(enableVoice: false)
        )
    }

    func testDirectAgentInfoSeedUsesDefaultLabelForBlankLabel() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
            "agentId": "0Xa",
            "agentLabel": "   ",
        ])

        XCTAssertEqual(
            DirectAgentInfoSeed(agentId: "0Xa", label: "Agentforce", isVoiceEnabled: true),
            config?.directAgentInfoSeed(enableVoice: true)
        )
    }

    func testDirectAgentInfoSeedIsNilForMultiAgentConfiguration() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
        ])

        XCTAssertNil(config?.directAgentInfoSeed(enableVoice: true))
    }

    func testClientConfigurationPlanTracksBothVoiceTransitionsAndReuse() throws {
        let config = try XCTUnwrap(EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
            "agentId": "0Xa",
            "agentLabel": "Support Bot",
        ]))
        let disabled = config.clientConfigurationPlan(
            enableMultiAgent: true,
            enableMultiModalInput: true,
            enablePDFUpload: true,
            enableVoice: false,
            userSilenceTimeoutSeconds: nil,
            autoEndWhileMuted: false,
            defaultClosedCaptionsEnabled: false,
            internalFlags: [:]
        )
        let enabled = config.clientConfigurationPlan(
            enableMultiAgent: true,
            enableMultiModalInput: true,
            enablePDFUpload: true,
            enableVoice: true,
            userSilenceTimeoutSeconds: nil,
            autoEndWhileMuted: false,
            defaultClosedCaptionsEnabled: false,
            internalFlags: [:]
        )

        XCTAssertTrue(enabled.requiresClientRebuild(comparedTo: disabled))
        XCTAssertTrue(disabled.requiresClientRebuild(comparedTo: enabled))
        XCTAssertFalse(enabled.requiresClientRebuild(comparedTo: enabled))
        XCTAssertEqual(
            DirectAgentInfoSeed(agentId: "0Xa", label: "Support Bot", isVoiceEnabled: true),
            enabled.directAgentInfoSeed
        )
        XCTAssertEqual(false, disabled.directAgentInfoSeed?.isVoiceEnabled)
    }

    func testMultiAgentClientConfigurationPlanHasNoDirectAgentSeed() throws {
        let config = try XCTUnwrap(EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "tok",
        ]))
        let plan = config.clientConfigurationPlan(
            enableMultiAgent: true,
            enableMultiModalInput: true,
            enablePDFUpload: true,
            enableVoice: true,
            userSilenceTimeoutSeconds: 30,
            autoEndWhileMuted: true,
            defaultClosedCaptionsEnabled: true,
            internalFlags: ["example": true]
        )

        XCTAssertTrue(plan.enableMultiAgent)
        XCTAssertNil(plan.directAgentInfoSeed)
    }

    func testEmployeeConfigIsNilWhenAccessTokenMissing() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            // accessToken missing
        ])
        XCTAssertNil(config)
    }

    func testEmployeeConfigParsesOAuthSources() {
        var values: [String: Any] = [
            "instanceUrl": "https://myorg", "organizationId": "00D", "userId": "005",
            "authentication": ["type": "oauth", "source": "direct", "accessToken": "oauth"],
        ]
        XCTAssertEqual(.directOAuth(accessToken: "oauth"), EmployeeAgentModeConfig.from(dictionary: values)?.authentication)
        values["authentication"] = ["type": "oauth", "source": "salesforceMobileSdk"]
        XCTAssertEqual(.mobileSDKOAuth, EmployeeAgentModeConfig.from(dictionary: values)?.authentication)
    }

    func testEmployeeConfigRejectsRemovedOrgJWT() {
        for source in ["direct", "salesforceMobileSdk"] {
            XCTAssertNil(EmployeeAgentModeConfig.from(dictionary: [
                "instanceUrl": "https://myorg", "organizationId": "00D", "userId": "005",
                "authentication": ["type": "orgJwt", "source": source, "token": "unsupported-token"],
            ]))
        }
    }

    func testEmployeeConfigRejectsAmbiguousAuthentication() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            "accessToken": "oauth",
            "authentication": ["type": "oauth", "source": "direct", "accessToken": "oauth"],
        ])
        XCTAssertNil(config)
    }

    // MARK: - AgentConfigError

    func testAgentConfigErrorDescriptions() {
        XCTAssertEqual(
            "Missing required configuration field: userId",
            AgentConfigError.missingRequiredField("userId").errorDescription
        )
        XCTAssertEqual(
            "Employee Agent requires an access token.",
            AgentConfigError.tokenRequired.errorDescription
        )
    }
}
