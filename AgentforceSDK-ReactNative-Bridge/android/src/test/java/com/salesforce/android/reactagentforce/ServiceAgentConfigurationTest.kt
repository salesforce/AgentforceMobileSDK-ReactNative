package com.salesforce.android.reactagentforce

import com.salesforce.android.agentforcesdkimpl.configuration.AgentforceConfiguration
import com.salesforce.android.agentforceservice.AgentforceAuthCredentialProvider
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ServiceAgentConfigurationTest {

    @Test
    fun `SCRT service endpoint is not used as Salesforce core domain`() {
        val serviceApiURL = "https://example.sandbox.my.salesforce-scrt.com"

        val configuration = AgentforceConfiguration
            .builder(mockk<AgentforceAuthCredentialProvider>())
            .setServiceAgentApiURL(serviceApiURL)
            .build()

        assertEquals(serviceApiURL, configuration.serviceApiURL)
        assertNull(configuration.salesforceDomain)
    }
}
