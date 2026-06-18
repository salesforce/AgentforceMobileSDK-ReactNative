package com.salesforce.android.reactagentforce.providers

import com.salesforce.android.agentforceservice.AgentforceAuthCredentials
import com.salesforce.android.reactagentforce.models.EmployeeAgentModeConfig
import com.salesforce.android.reactagentforce.models.ServiceAgentModeConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * In a JVM unit test the Mobile SDK is never initialized, so
 * SalesforceSDKManager.getInstance() throws "must call init() first". The
 * provider catches that and routes to its cached-token fallback — which is
 * exactly the employee-mode branch these tests exercise (no mocking needed).
 */
class UnifiedCredentialProviderTest {

    private val serviceConfig = ServiceAgentModeConfig("https://service", "00DService", "Agent")
    private val employeeConfig =
        EmployeeAgentModeConfig("https://myorg", "00DEmp", "005User", accessToken = "secret-token")

    @Test
    fun `unconfigured provider reports no mode`() {
        val provider = UnifiedCredentialProvider()
        assertFalse(provider.isConfigured)
        assertFalse(provider.isServiceAgent)
        assertFalse(provider.isEmployeeAgent)
        assertEquals("Unconfigured", provider.currentConfiguration)
    }

    @Test
    fun `service mode yields empty-token OAuth credentials`() {
        val provider = UnifiedCredentialProvider()
        provider.configure(serviceConfig)

        assertTrue(provider.isServiceAgent)
        assertFalse(provider.isEmployeeAgent)
        assertTrue(provider.isConfigured)
        assertEquals("Service Agent - Org: 00DService", provider.currentConfiguration)

        val creds = provider.getAuthCredentials() as AgentforceAuthCredentials.OAuth
        assertEquals("", creds.authToken)
        assertEquals("00DService", creds.orgId)
        assertEquals("", creds.userId)
    }

    @Test
    fun `employee mode falls back to cached token when no Mobile SDK user`() {
        val provider = UnifiedCredentialProvider()
        provider.configure(employeeConfig)

        assertTrue(provider.isEmployeeAgent)
        assertEquals("Employee Agent - Org: 00DEmp, User: 005User", provider.currentConfiguration)

        val creds = provider.getAuthCredentials() as AgentforceAuthCredentials.OAuth
        assertEquals("secret-token", creds.authToken)
        assertEquals("00DEmp", creds.orgId)
        assertEquals("005User", creds.userId)
    }

    @Test
    fun `updateToken replaces the cached employee token`() {
        val provider = UnifiedCredentialProvider()
        provider.configure(employeeConfig)
        provider.updateToken("refreshed-token")

        val creds = provider.getAuthCredentials() as AgentforceAuthCredentials.OAuth
        assertEquals("refreshed-token", creds.authToken)
    }

    @Test
    fun `updateToken is a no-op in service mode`() {
        val provider = UnifiedCredentialProvider()
        provider.configure(serviceConfig)
        provider.updateToken("ignored")

        val creds = provider.getAuthCredentials() as AgentforceAuthCredentials.OAuth
        assertEquals("", creds.authToken)
    }

    @Test
    fun `reset clears configuration`() {
        val provider = UnifiedCredentialProvider()
        provider.configure(serviceConfig)
        provider.reset()

        assertFalse(provider.isConfigured)
        assertEquals("Unconfigured", provider.currentConfiguration)
    }
}
