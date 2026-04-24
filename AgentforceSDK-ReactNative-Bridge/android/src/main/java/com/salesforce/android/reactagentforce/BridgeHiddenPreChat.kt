/*
 * Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge for hidden prechat field delegate
 */
package com.salesforce.android.reactagentforce

import com.salesforce.android.agentforceservice.coresdk.AgentforceHiddenPreChatField
import com.salesforce.android.agentforceservice.coresdk.AgentforceHiddenPreChatFieldDelegate

class BridgeHiddenPreChat : AgentforceHiddenPreChatFieldDelegate {

    @Volatile
    private var fields: Map<String, String> = emptyMap()

    fun setFields(fields: Map<String, String>) {
        this.fields = fields
    }

    fun getFields(): Map<String, String> = fields

    override suspend fun agentforce(
        hiddenPreChatField: List<AgentforceHiddenPreChatField>
    ): Map<String, String>? {
        val stored = fields
        if (stored.isEmpty()) return null

        val result = mutableMapOf<String, String>()
        for (field in hiddenPreChatField) {
            stored[field.name]?.let { result[field.name] = it }
        }
        return result.ifEmpty { null }
    }
}
