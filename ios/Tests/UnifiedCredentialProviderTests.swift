import XCTest

final class UnifiedCredentialProviderTests: XCTestCase {
    private func employee(_ authentication: EmployeeAuthentication = .mobileSDKOAuth) -> EmployeeAgentModeConfig {
        EmployeeAgentModeConfig(
            instanceUrl: "https://example.my.salesforce.com",
            organizationId: "00D",
            userId: "005",
            agentId: nil,
            agentLabel: nil,
            accessToken: "",
            authentication: authentication
        )
    }

    private let session = OAuthCredentialSnapshot(authToken: "current-token", orgId: "00D", userId: "005")

    func testMissingMobileSDKSessionRejectsConfigurationWithoutChangingMode() throws {
        // A missing optional Mobile SDK integration and a logged-out SDK both resolve to nil.
        let provider = UnifiedCredentialProvider(mobileSDKCredentials: { nil })
        try provider.configure(employeeAgent: employee(.directOAuth(accessToken: "host-token")))

        XCTAssertThrowsError(try provider.configure(employeeAgent: employee())) { error in
            guard case AgentConfigError.mobileSDKSessionUnavailable = error else {
                return XCTFail("Expected a recoverable Mobile SDK session error, got \(error)")
            }
        }
        XCTAssertEqual("host-token", try provider.resolvedCredentials().authToken)
    }

    func testIncompleteOrBlankMobileSDKCredentialsRejectConfiguration() {
        for credentials in [
            OAuthCredentialSnapshot(authToken: "", orgId: "00D", userId: "005"),
            OAuthCredentialSnapshot(authToken: "token", orgId: "", userId: "005"),
            OAuthCredentialSnapshot(authToken: "token", orgId: "00D", userId: "   "),
        ] {
            let provider = UnifiedCredentialProvider(mobileSDKCredentials: { credentials })
            XCTAssertThrowsError(try provider.configure(employeeAgent: employee()))
            XCTAssertFalse(provider.isConfigured)
        }
    }

    func testSessionLossThrowsAndSDKCallbackWithholdsStaleToken() throws {
        var currentSession: OAuthCredentialSnapshot? = session
        let provider = UnifiedCredentialProvider(mobileSDKCredentials: { currentSession })
        try provider.configure(employeeAgent: employee())
        XCTAssertEqual(session, try provider.resolvedCredentials())

        currentSession = nil
        XCTAssertThrowsError(try provider.validateCredentials())

        var reportedError: Error?
        provider.onCredentialError = { reportedError = $0 }
        XCTAssertEqual(
            OAuthCredentialSnapshot(authToken: "", orgId: "00D", userId: "005"),
            provider.credentialsForSDK()
        )
        XCTAssertNotNil(reportedError)

        currentSession = OAuthCredentialSnapshot(authToken: "refreshed-token", orgId: "00D", userId: "005")
        XCTAssertEqual("refreshed-token", try provider.resolvedCredentials().authToken)
    }

    func testMobileSDKTokenRefreshReadsCurrentSession() throws {
        var currentSession: OAuthCredentialSnapshot? = session
        let provider = UnifiedCredentialProvider(mobileSDKCredentials: { currentSession })
        try provider.configure(employeeAgent: employee())
        currentSession = OAuthCredentialSnapshot(authToken: "new-token", orgId: "00D", userId: "005")
        XCTAssertEqual("new-token", try provider.resolvedCredentials().authToken)
    }

    func testDirectOAuthDoesNotReadMobileSDKAndSupportsTokenUpdates() throws {
        let provider = UnifiedCredentialProvider(mobileSDKCredentials: {
            XCTFail("Direct OAuth must not read Mobile SDK credentials")
            return nil
        })
        try provider.configure(employeeAgent: employee(.directOAuth(accessToken: "host-token")))
        XCTAssertEqual("host-token", try provider.resolvedCredentials().authToken)
        provider.updateToken("updated-host-token")
        XCTAssertEqual("updated-host-token", try provider.resolvedCredentials().authToken)
    }

    func testReconfiguringHostTokenRefreshesCredentialsWithoutChangingClientIdentity() throws {
        let tokenPairs: [(EmployeeAuthentication, EmployeeAuthentication)] = [
            (.directOAuth(accessToken: "old-token"), .directOAuth(accessToken: "new-token")),
            (.legacy(accessToken: "old-token"), .legacy(accessToken: "new-token")),
        ]
        for (previousAuth, refreshedAuth) in tokenPairs {
            let provider = UnifiedCredentialProvider(mobileSDKCredentials: { nil })
            let previous = employee(previousAuth)
            let refreshed = employee(refreshedAuth)
            try provider.configure(employeeAgent: previous)
            XCTAssertEqual("old-token", try provider.resolvedCredentials().authToken)

            // configure() updates the shared provider even when the module reuses its client.
            XCTAssertTrue(previous.hasSameIdentity(as: refreshed))
            try provider.configure(employeeAgent: refreshed)
            XCTAssertEqual(
                OAuthCredentialSnapshot(authToken: "new-token", orgId: "00D", userId: "005"),
                try provider.resolvedCredentials()
            )
        }
    }

    func testLegacyOAuthFallbackAndServiceGuestCredentialsRemainAvailable() throws {
        let provider = UnifiedCredentialProvider(mobileSDKCredentials: { nil })
        try provider.configure(employeeAgent: employee(.legacy(accessToken: "legacy-token")))
        XCTAssertEqual("legacy-token", try provider.resolvedCredentials().authToken)

        provider.configure(serviceAgent: ServiceAgentModeConfig(
            serviceApiURL: "https://example.salesforce-scrt.com",
            organizationId: "service-org",
            esDeveloperName: "ServiceAgent",
            serviceUISettings: nil
        ))
        XCTAssertEqual(
            OAuthCredentialSnapshot(authToken: "", orgId: "service-org", userId: ""),
            try provider.resolvedCredentials()
        )
    }

    func testLateSDKCredentialReadAfterResetDoesNotTerminateProcess() throws {
        let provider = UnifiedCredentialProvider(mobileSDKCredentials: { nil })
        try provider.configure(employeeAgent: employee(.directOAuth(accessToken: "host-token")))
        provider.reset()
        XCTAssertThrowsError(try provider.validateCredentials())
        XCTAssertEqual(
            OAuthCredentialSnapshot(authToken: "", orgId: "", userId: ""),
            provider.credentialsForSDK()
        )
    }
}
