/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Bridge UIDelegate that forwards Agentforce SDK UI events to React Native JS via events.
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

/**
 * Implements the Agentforce SDK AgentforceUIDelegate interface and forwards UI events
 * to JavaScript via NativeEventEmitter events.
 *
 * UI event forwarding is disabled by default and enabled when JS registers a UIDelegate.
 */
class BridgeUIDelegate(private val reactContext: ReactContext) : AgentforceUIDelegate {

    /** Controls whether UI events are forwarded to JS. */
    @Volatile
    var forwardingEnabled: Boolean = false

    /** Pending modify-utterance requests awaiting JS responses. */
    private val pendingModifications = ConcurrentHashMap<String, CompletableDeferred<String>>()

    /** ISO 8601 date formatter. */
    private val iso8601Formatter: SimpleDateFormat
        get() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

    /** Returns a conversation ID string from an AgentConversation. */
    private fun getConversationId(conversation: AgentConversation): String {
        return if (conversation is AgentforceConversation) {
            conversation.id
        } else {
            conversation.hashCode().toString()
        }
    }

    override suspend fun modifyUtteranceBeforeSending(
        agentforceUtterance: AgentforceUtterance
    ): AgentforceUtterance {
        if (!forwardingEnabled) return agentforceUtterance

        val requestId = UUID.randomUUID().toString()
        val deferred = CompletableDeferred<String>()
        pendingModifications[requestId] = deferred

        try {
            val params = Arguments.createMap().apply {
                putString("requestId", requestId)
                putString("utterance", agentforceUtterance.utterance)
            }

            reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit("onModifyUtteranceRequest", params)

            val modifiedText = withTimeout(5000) { deferred.await() }

            return AgentforceUtterance(
                utterance = modifiedText,
                agentforceAttachment = agentforceUtterance.agentforceAttachment
            )
        } catch (e: Exception) {
            return agentforceUtterance
        } finally {
            pendingModifications.remove(requestId)
        }
    }

    /**
     * Called by AgentforceModule when JS responds to a modify-utterance request.
     *
     * @return true if the request was found and completed, false otherwise.
     */
    fun completeModification(requestId: String, modifiedUtterance: String): Boolean {
        val deferred = pendingModifications[requestId] ?: return false
        return deferred.complete(modifiedUtterance)
    }

    override fun didSendUtterance(agentforceUtterance: AgentforceUtterance) {
        if (!forwardingEnabled) return

        val params = Arguments.createMap().apply {
            putString("utterance", agentforceUtterance.utterance)
            putBoolean("hasAttachment", agentforceUtterance.agentforceAttachment != null)
            putString("timestamp", iso8601Formatter.format(Date()))
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onUtteranceSent", params)
    }

    override fun userDidSwitchAgents(newConversation: AgentConversation) {
        if (!forwardingEnabled) return

        val params = Arguments.createMap().apply {
            putString("conversationId", getConversationId(newConversation))
            putString("timestamp", iso8601Formatter.format(Date()))
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onAgentSwitch", params)
    }

    override fun didReceiveResponse(
        agentforceMessage: AgentforceMessage,
        conversation: AgentConversation
    ) {
        if (!forwardingEnabled) return

        val params = Arguments.createMap().apply {
            putString("responseId", agentforceMessage.id)
            putString("message", agentforceMessage.message ?: agentforceMessage.text)
            putString("type", agentforceMessage.type ?: "agent")
            putString("conversationId", getConversationId(conversation))
            putString("timestamp", iso8601Formatter.format(Date(agentforceMessage.timeStamp)))
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onAgentResponse", params)
    }
}
