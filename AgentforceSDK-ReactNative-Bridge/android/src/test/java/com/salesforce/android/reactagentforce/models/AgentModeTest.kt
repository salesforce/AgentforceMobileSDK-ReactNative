package com.salesforce.android.reactagentforce.models

import com.facebook.react.bridge.ReadableMap
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AgentModeTest {

    /** Builds a mock ReadableMap backed by a string map; getString/hasKey honor it. */
    private fun mapOf(strings: Map<String, String?>): ReadableMap {
        val map = mockk<ReadableMap>(relaxed = true)
        every { map.hasKey(any()) } answers { strings.containsKey(firstArg()) }
        every { map.getString(any()) } answers { strings[firstArg<String>()] }
        return map
    }

    // --- typeString ---

    @Test
    fun `typeString reflects the variant`() {
        val service = AgentMode.Service(
            ServiceAgentModeConfig("https://x", "00D", "Agent")
        )
        val employee = AgentMode.Employee(
            EmployeeAgentModeConfig("https://x", "00D", "005", accessToken = "tok")
        )
        assertEquals("service", service.typeString)
        assertEquals("employee", employee.typeString)
    }

    // --- ServiceAgentModeConfig.fromReadableMap ---

    @Test
    fun `service config parses all required fields`() {
        val map = mapOf(
            mapOf(
                "serviceApiURL" to "https://service",
                "organizationId" to "00D",
                "esDeveloperName" to "MyAgent",
            )
        )
        val config = ServiceAgentModeConfig.fromReadableMap(map)
        assertEquals("https://service", config?.serviceApiURL)
        assertEquals("00D", config?.organizationId)
        assertEquals("MyAgent", config?.esDeveloperName)
        assertNull(config?.serviceUISettings)
    }

    @Test
    fun `service config is null when a required field is missing`() {
        val map = mapOf(
            mapOf(
                "serviceApiURL" to "https://service",
                "organizationId" to "00D",
                // esDeveloperName missing
            )
        )
        assertNull(ServiceAgentModeConfig.fromReadableMap(map))
    }

    @Test
    fun `service config parses serviceUISettings when present`() {
        val settings = mockk<ReadableMap>(relaxed = true)
        val iterator = mockk<com.facebook.react.bridge.ReadableMapKeySetIterator>()
        every { iterator.hasNextKey() } returnsMany listOf(true, true, false)
        every { iterator.nextKey() } returnsMany listOf("downloadTranscript", "endConversation")
        every { settings.keySetIterator() } returns iterator
        every { settings.getBoolean("downloadTranscript") } returns false
        every { settings.getBoolean("endConversation") } returns true

        val map = mockk<ReadableMap>(relaxed = true)
        every { map.getString("serviceApiURL") } returns "https://service"
        every { map.getString("organizationId") } returns "00D"
        every { map.getString("esDeveloperName") } returns "MyAgent"
        every { map.hasKey("serviceUISettings") } returns true
        every { map.getMap("serviceUISettings") } returns settings

        val config = ServiceAgentModeConfig.fromReadableMap(map)
        assertEquals(mapOf("downloadTranscript" to false, "endConversation" to true), config?.serviceUISettings)
    }

    // --- EmployeeAgentModeConfig.fromReadableMap ---

    @Test
    fun `employee config parses required fields and optional agentId`() {
        val map = mapOf(
            mapOf(
                "instanceUrl" to "https://myorg",
                "organizationId" to "00D",
                "userId" to "005",
                "accessToken" to "tok",
                "agentId" to "0Xa",
            )
        )
        val config = EmployeeAgentModeConfig.fromReadableMap(map)
        assertEquals("https://myorg", config?.instanceUrl)
        assertEquals("005", config?.userId)
        assertEquals("tok", config?.accessToken)
        assertEquals("0Xa", config?.agentId)
    }

    @Test
    fun `employee config treats blank agentId as null`() {
        val map = mapOf(
            mapOf(
                "instanceUrl" to "https://myorg",
                "organizationId" to "00D",
                "userId" to "005",
                "accessToken" to "tok",
                "agentId" to "   ",
            )
        )
        assertNull(EmployeeAgentModeConfig.fromReadableMap(map)?.agentId)
    }

    @Test
    fun `employee config reads agentLabel only when the key is present`() {
        val withLabel = mapOf(
            mapOf(
                "instanceUrl" to "https://myorg",
                "organizationId" to "00D",
                "userId" to "005",
                "accessToken" to "tok",
                "agentLabel" to "Support Bot",
            )
        )
        assertEquals("Support Bot", EmployeeAgentModeConfig.fromReadableMap(withLabel)?.agentLabel)

        val withoutLabel = mapOf(
            mapOf(
                "instanceUrl" to "https://myorg",
                "organizationId" to "00D",
                "userId" to "005",
                "accessToken" to "tok",
            )
        )
        assertNull(EmployeeAgentModeConfig.fromReadableMap(withoutLabel)?.agentLabel)
    }

    @Test
    fun `explicit agentId disables multi-agent discovery`() {
        val config = EmployeeAgentModeConfig(
            instanceUrl = "https://myorg",
            organizationId = "00D",
            userId = "005",
            agentId = "0Xa",
            accessToken = "tok"
        )

        assertEquals(false, config.effectiveEnableMultiAgent(requested = true))
        assertEquals(false, config.effectiveEnableMultiAgent(requested = false))
    }

    @Test
    fun `missing agentId preserves requested multi-agent discovery`() {
        val config = EmployeeAgentModeConfig(
            instanceUrl = "https://myorg",
            organizationId = "00D",
            userId = "005",
            accessToken = "tok"
        )

        assertEquals(true, config.effectiveEnableMultiAgent(requested = true))
        assertEquals(false, config.effectiveEnableMultiAgent(requested = false))
    }

    @Test
    fun `client configuration plan tracks both voice transitions and reuse`() {
        val config = EmployeeAgentModeConfig(
            instanceUrl = "https://myorg",
            organizationId = "00D",
            userId = "005",
            agentId = "0Xa",
            agentLabel = " Support Bot ",
            accessToken = "tok"
        )
        val voiceOptions = VoiceOptionsSnapshot(null, false, false)
        val disabled = config.clientConfigurationPlan(
            requestedEnableMultiAgent = true,
            enableMultiModalInput = true,
            enablePDFUpload = true,
            enableVoice = false,
            voiceOptions = voiceOptions,
            internalFlags = emptyMap()
        )
        val enabled = config.clientConfigurationPlan(
            requestedEnableMultiAgent = true,
            enableMultiModalInput = true,
            enablePDFUpload = true,
            enableVoice = true,
            voiceOptions = voiceOptions,
            internalFlags = emptyMap()
        )

        assertEquals(true, enabled.requiresClientRebuild(disabled))
        assertEquals(true, disabled.requiresClientRebuild(enabled))
        assertEquals(false, enabled.requiresClientRebuild(enabled))
        assertEquals(false, enabled.enableMultiAgent)
        assertEquals("0Xa", enabled.directAgentId)
        assertEquals("Support Bot", enabled.directAgentLabel)
    }

    @Test
    fun `multi-agent client configuration plan preserves discovery`() {
        val config = EmployeeAgentModeConfig(
            instanceUrl = "https://myorg",
            organizationId = "00D",
            userId = "005",
            accessToken = "tok"
        )
        val plan = config.clientConfigurationPlan(
            requestedEnableMultiAgent = true,
            enableMultiModalInput = true,
            enablePDFUpload = true,
            enableVoice = true,
            voiceOptions = VoiceOptionsSnapshot(30.0, true, true),
            internalFlags = mapOf("example" to true)
        )

        assertEquals(true, plan.enableMultiAgent)
        assertNull(plan.directAgentId)
    }

    @Test
    fun `employee config is null when accessToken is missing`() {
        val map = mapOf(
            mapOf(
                "instanceUrl" to "https://myorg",
                "organizationId" to "00D",
                "userId" to "005",
                // accessToken missing
            )
        )
        assertNull(EmployeeAgentModeConfig.fromReadableMap(map))
    }

    @Test
    fun `employee config parses direct OAuth without legacy token`() {
        val auth = mapOf(mapOf("type" to "oauth", "source" to "direct", "accessToken" to "oauth"))
        val map = mapOf(mapOf("instanceUrl" to "https://myorg", "organizationId" to "00D", "userId" to "005"))
        every { map.hasKey("authentication") } returns true
        every { map.getMap("authentication") } returns auth

        val config = EmployeeAgentModeConfig.fromReadableMap(map)
        assertEquals(EmployeeAuthentication.DirectOAuth("oauth"), config?.authentication)
    }

    @Test
    fun `employee config parses Mobile SDK OAuth without accessToken`() {
        val auth = mapOf(mapOf("type" to "oauth", "source" to "salesforceMobileSdk"))
        val map = mapOf(mapOf("instanceUrl" to "https://myorg", "organizationId" to "00D", "userId" to "005"))
        every { map.hasKey("authentication") } returns true
        every { map.getMap("authentication") } returns auth

        assertEquals(EmployeeAuthentication.MobileSDKOAuth, EmployeeAgentModeConfig.fromReadableMap(map)?.authentication)
    }

    @Test
    fun `Mobile SDK credentials use RestClient network for agent discovery`() {
        assertEquals(true, EmployeeAuthentication.Legacy("oauth").usesMobileSDKNetwork)
        assertEquals(true, EmployeeAuthentication.MobileSDKOAuth.usesMobileSDKNetwork)
        assertEquals(false, EmployeeAuthentication.DirectOAuth("oauth").usesMobileSDKNetwork)
    }

    @Test
    fun `employee config rejects removed OrgJWT sources`() {
        for (source in listOf("direct", "salesforceMobileSdk")) {
            val auth = mapOf(mapOf("type" to "orgJwt", "source" to source, "token" to "unsupported-token"))
            val values = mapOf(mapOf("instanceUrl" to "https://myorg", "organizationId" to "00D", "userId" to "005"))
            every { values.hasKey("authentication") } returns true
            every { values.getMap("authentication") } returns auth
            assertNull(EmployeeAgentModeConfig.fromReadableMap(values))
        }
    }

    @Test
    fun `employee config rejects legacy and explicit credentials together`() {
        val auth = mapOf(mapOf("type" to "oauth", "source" to "direct", "accessToken" to "oauth"))
        val map = mapOf(mapOf("instanceUrl" to "https://myorg", "organizationId" to "00D", "userId" to "005", "accessToken" to "oauth"))
        every { map.hasKey("authentication") } returns true
        every { map.getMap("authentication") } returns auth

        assertNull(EmployeeAgentModeConfig.fromReadableMap(map))
    }

    @Test
    fun `employee mode exposes its config`() {
        val config = EmployeeAgentModeConfig("https://x", "00D", "005", accessToken = "tok")
        val mode = AgentMode.Employee(config)
        assertEquals("005", mode.config.userId)
    }
}
