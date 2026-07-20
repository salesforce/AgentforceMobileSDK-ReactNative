package com.salesforce.android.reactagentforce

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the canonical → Android-SDK internal-flag key mapping in [AgentforceModule].
 *
 * The core risk this feature carries is cross-platform key divergence: the JS `InternalFlags`
 * type, the iOS `internalFlagKeyMap`, and this Android map must agree on the canonical names,
 * and each canonical name must translate to the exact string the Android SDK's `setupFlags`
 * expects. These tests pin that contract so a rename on either side fails loudly.
 */
class InternalFlagsMappingTest {

    private val map = AgentforceModule.INTERNAL_FLAG_KEY_MAP

    // --- cross-platform flags: canonical name → Android SDK key ---

    @Test
    fun `cross-platform flags map to their Android SDK keys`() {
        // 1:1 (canonical == SDK key)
        assertEquals("endConversation", map["endConversation"])
        assertEquals("downloadTranscript", map["downloadTranscript"])
        assertEquals("useMobileTypesApi", map["useMobileTypesApi"])
        assertEquals("enableHybridComponents", map["enableHybridComponents"])
        assertEquals("enableClosedCaptions", map["enableClosedCaptions"])

        // renamed (canonical differs from the Android SDK's string key)
        assertEquals("enableTokenStreaming", map["tokenStreaming"])
        assertEquals("enableLightningTypeStreaming", map["lightningTypeStreaming"])
        assertEquals("enableInlineCitation", map["inlineCitations"])
        assertEquals("enableSelectSingleTextTransform", map["selectSingleTextTransform"])
        assertEquals("enableSecureForms", map["secureForms"])
        assertEquals("enableVideoAttachments", map["enableVideoUpload"])
        assertEquals("enableAudioAttachments", map["enableAudioUpload"])
        assertEquals("useRecommendedUtterancesApi", map["recommendedUtterancesApi"])
        assertEquals("useWelcomeUtterancesApi", map["useWelcomeUtterances"])
        assertEquals("enableLightningOutProvider", map["enableLightningOut"])
        assertEquals("enableValidationFailureHandling", map["validationFailureChunk"])
    }

    // --- Android-only flags are present ---

    @Test
    fun `android-only flags are present in the map`() {
        val androidOnly = listOf(
            "enableMocking",
            "enableIterativeCompression",
            "useFollowUpActionsApi",
            "enableCopyAndViewMoreFollowUpAction",
            "enableNavAndQuickFollowUpAction",
            "enableSimpleCitation",
            "enableAgentforceCard",
            "enablePushNotifications",
            "enableClearChat",
            "showVoiceBetaBanner",
            "enableMobileBranding",
        )
        for (flag in androidOnly) {
            assertTrue("expected Android-only flag '$flag' to be mapped", map.containsKey(flag))
        }
    }

    // --- iOS-only flags are absent (silent no-op on Android) ---

    @Test
    fun `ios-only flags are absent from the android map`() {
        val iosOnly = listOf(
            "citations",
            "compressImage",
            "quickActions",
            "showQueueStatus",
            "voiceContinuesOnBackground",
            "enableVoiceCallKit",
        )
        for (flag in iosOnly) {
            assertFalse("iOS-only flag '$flag' must not reach the Android SDK", map.containsKey(flag))
        }
    }

    // --- semantic pairs are kept distinct ---

    @Test
    fun `semantically-related pairs stay distinct across platforms`() {
        // iOS `citations` is not the same canonical flag as Android `enableSimpleCitation`.
        assertFalse(map.containsKey("citations"))
        assertEquals("enableSimpleCitation", map["enableSimpleCitation"])

        // iOS `compressImage` is not the same canonical flag as Android `enableIterativeCompression`.
        assertFalse(map.containsKey("compressImage"))
        assertEquals("enableIterativeCompression", map["enableIterativeCompression"])
    }

    // --- no accidental collisions in the target keys ---

    @Test
    fun `sdk keys are unique so no two canonical flags collide`() {
        val sdkKeys = map.values.toList()
        assertEquals(sdkKeys.size, sdkKeys.toSet().size)
    }
}
