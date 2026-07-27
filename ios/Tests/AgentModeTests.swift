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
                accessToken: "tok"
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

    // MARK: - EmployeeAgentModeConfig.from(dictionary:)

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

    func testEmployeeConfigIsNilWhenAccessTokenMissing() {
        let config = EmployeeAgentModeConfig.from(dictionary: [
            "instanceUrl": "https://myorg",
            "organizationId": "00D",
            "userId": "005",
            // accessToken missing
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
