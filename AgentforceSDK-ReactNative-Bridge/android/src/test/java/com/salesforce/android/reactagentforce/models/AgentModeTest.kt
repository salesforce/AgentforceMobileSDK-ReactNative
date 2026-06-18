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
    fun `employee mode exposes its config`() {
        val config = EmployeeAgentModeConfig("https://x", "00D", "005", accessToken = "tok")
        val mode = AgentMode.Employee(config)
        assertEquals("005", mode.config.userId)
    }
}
