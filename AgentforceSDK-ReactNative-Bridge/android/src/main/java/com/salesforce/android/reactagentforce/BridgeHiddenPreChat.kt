/*
 * Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge for hidden prechat field delegate
 *
 * TODO: Implement AgentforceHiddenPreChatFieldDelegate interface.
 * See BridgeHiddenPreChat.swift (iOS) for the reference implementation.
 *
 * Expected behavior:
 * - Store fields set via setFields()
 * - Implement AgentforceHiddenPreChatFieldDelegate.agentforce() to return
 *   only values for fields the SDK requests (filter stored map by requested field names)
 * - Return null when no fields are stored or no requested fields match
 * - Use @Volatile for thread-safe reads (matches BridgeLogger pattern)
 */
package com.salesforce.android.reactagentforce

class BridgeHiddenPreChat {

    @Volatile
    private var fields: Map<String, String> = emptyMap()

    fun setFields(fields: Map<String, String>) {
        this.fields = fields
    }

    fun getFields(): Map<String, String> = fields
}
