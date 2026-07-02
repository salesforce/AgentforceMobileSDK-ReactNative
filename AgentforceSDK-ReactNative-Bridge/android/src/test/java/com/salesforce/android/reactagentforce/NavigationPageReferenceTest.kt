package com.salesforce.android.reactagentforce

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Verifies the record pageReference synthesized by the bridge matches the shape the iOS SDK's
 * `Record` initializer emits, so JS consumers get a consistent cross-platform payload (W-23294974).
 */
class NavigationPageReferenceTest {

    @Test
    fun `record pageReference matches iOS standard__recordPage shape`() {
        val json = Json.parseToJsonElement(
            recordPageReference("001bG00000F4PyXQAV", "Account")
        ).jsonObject

        assertEquals("standard__recordPage", json["type"]?.jsonPrimitive?.content)

        val attributes = json["attributes"]?.jsonObject!!
        assertEquals("001bG00000F4PyXQAV", attributes["recordId"]?.jsonPrimitive?.content)
        assertEquals("view", attributes["actionName"]?.jsonPrimitive?.content)
        assertEquals("Account", attributes["objectApiName"]?.jsonPrimitive?.content)
    }

    @Test
    fun `objectApiName is omitted when objectType is null`() {
        val attributes = Json.parseToJsonElement(
            recordPageReference("001bG00000F4PyXQAV", null)
        ).jsonObject["attributes"]?.jsonObject!!

        assertFalse("objectApiName should be absent", attributes.containsKey("objectApiName"))
        assertTrue(attributes.containsKey("recordId"))
        assertEquals("view", attributes["actionName"]?.jsonPrimitive?.content)
    }

    @Test
    fun `objectApiName is omitted when objectType is blank`() {
        val attributes = Json.parseToJsonElement(
            recordPageReference("001bG00000F4PyXQAV", "   ")
        ).jsonObject["attributes"]?.jsonObject!!

        assertFalse("objectApiName should be absent for blank type", attributes.containsKey("objectApiName"))
    }
}
