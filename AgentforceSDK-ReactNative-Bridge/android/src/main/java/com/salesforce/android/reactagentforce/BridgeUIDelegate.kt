/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.salesforce.android.agentforcesdkimpl.AgentConversation
import com.salesforce.android.agentforcesdkimpl.AgentforceConversation
import com.salesforce.android.agentforcesdkimpl.AgentforceUIDelegate
import com.salesforce.android.agentforceservice.AgentforceUtterance
import com.salesforce.android.agentforceservice.conversationservice.data.AgentforceMessage
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeout
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class BridgeUIDelegate(private val reactContext: ReactContext) : AgentforceUIDelegate {

    @Volatile
    var forwardingEnabled: Boolean = false

    private val pendingModifications = ConcurrentHashMap<String, CompletableDeferred<String>>()

    private val isoFormatter: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

    private fun conversationIdString(conversation: AgentConversation): String {
        return if (conversation is AgentforceConversation) {
            conversation.id
        } else {
            conversation.hashCode().toString()
        }
    }

    override suspend fun modifyUtteranceBeforeSending(agentforceUtterance: AgentforceUtterance): AgentforceUtterance {
        if (!forwardingEnabled) return agentforceUtterance

        val requestId = UUID.randomUUID().toString()
        val deferred = CompletableDeferred<String>()
        pendingModifications[requestId] = deferred

        val params = Arguments.createMap().apply {
            putString("requestId", requestId)
            putString("utterance", agentforceUtterance.utterance)
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onModifyUtteranceRequest", params)

        return try {
            val modified = withTimeout(5000) { deferred.await() }
            AgentforceUtterance(utterance = modified, agentforceAttachment = agentforceUtterance.agentforceAttachment)
        } catch (_: Exception) {
            agentforceUtterance
        } finally {
            pendingModifications.remove(requestId)
        }
    }

    fun completeModification(requestId: String, modifiedUtterance: String) {
        pendingModifications[requestId]?.complete(modifiedUtterance)
    }

    override fun didSendUtterance(agentforceUtterance: AgentforceUtterance) {
        if (!forwardingEnabled) return

        val params = Arguments.createMap().apply {
            putString("utterance", agentforceUtterance.utterance)
            putBoolean("hasAttachment", agentforceUtterance.agentforceAttachment != null)
            putString("timestamp", isoFormatter.format(Date()))
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onUtteranceSent", params)
    }

    override fun userDidSwitchAgents(newConversation: AgentConversation) {
        if (!forwardingEnabled) return

        val params = Arguments.createMap().apply {
            putString("conversationId", conversationIdString(newConversation))
            putString("timestamp", isoFormatter.format(Date()))
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onAgentSwitch", params)
    }

    override fun didReceiveResponse(agentforceMessage: AgentforceMessage, conversation: AgentConversation) {
        if (!forwardingEnabled) return

        val params = Arguments.createMap().apply {
            putString("responseId", agentforceMessage.id)
            val text = agentforceMessage.message ?: agentforceMessage.text
            if (text != null) {
                putString("message", text)
            } else {
                putNull("message")
            }
            putString("type", agentforceMessage.type ?: "agent")
            putString("conversationId", conversationIdString(conversation))
            putString("timestamp", isoFormatter.format(Date(agentforceMessage.timeStamp)))
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onAgentResponse", params)
    }
}
