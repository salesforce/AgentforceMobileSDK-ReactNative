/*
 * Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 *
 * Speech transcriber implementing AgentforceVoiceManaging.
 * Captures microphone audio to .m4a and emits callbacks to React Native.
 */
package com.salesforce.android.reactagentforce

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.salesforce.android.agentforcesdkimpl.voice.AgentforceVoiceManaging
import java.io.File
import java.util.UUID

class BridgeSpeechTranscriber(
    private val reactContext: ReactApplicationContext
) : AgentforceVoiceManaging {

    companion object {
        private const val TAG = "BridgeSpeechTranscriber"
    }

    var module: AgentforceModule? = null

    private var mediaRecorder: MediaRecorder? = null
    private var isRecording: Boolean = false

    private var currentRequestId: String? = null
    private var currentAudioFile: File? = null

    // Stored callbacks from AgentforceVoiceManaging
    private var updateResultsCallback: ((String?) -> Unit)? = null
    private var endSpeechCallback: (() -> Unit)? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    // region AgentforceVoiceManaging Implementation

    override fun isVoiceSupported(context: Context): Boolean {
        Log.d(TAG, "isVoiceSupported called -> returning true")
        return true
    }

    override fun checkVoiceApproval(
        enabledCallback: () -> Unit,
        context: Context,
        warningTitle: String,
        warningMessage: String
    ) {
        Log.d(TAG, "checkVoiceApproval called")
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (hasPermission) {
            mainHandler.post {
                enabledCallback()
            }
        } else {
            Log.w(TAG, "RECORD_AUDIO permission not granted; rejecting voice approval")
        }
    }

    override fun checkOnDeviceModelAvailable(onResult: (Boolean) -> Unit) {
        Log.d(TAG, "checkOnDeviceModelAvailable called -> returning true")
        mainHandler.post {
            onResult(true)
        }
    }

    override fun requestVoiceInput(
        updateResults: (String?) -> Unit,
        endSpeech: () -> Unit
    ) {
        Log.d(TAG, "🎙️ requestVoiceInput called")
        this.updateResultsCallback = updateResults
        this.endSpeechCallback = endSpeech

        mainHandler.post {
            try {
                startRecording()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start recording in requestVoiceInput: ${e.message}", e)
                endSpeech()
            }
        }
    }

    override fun stopVoiceInput() {
        Log.d(TAG, "⏹️ stopVoiceInput called")
        mainHandler.post {
            stopRecording()
        }
    }

    // endregion

    // region Audio Recording

    @Synchronized
    private fun startRecording() {
        if (isRecording) {
            stopRecording()
        }

        val requestId = UUID.randomUUID().toString()
        currentRequestId = requestId
        val file = File(reactContext.cacheDir, "agentforce_speech_${requestId}.m4a")
        currentAudioFile = file

        if (file.exists()) {
            file.delete()
        }

        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(reactContext)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        mediaRecorder = recorder

        try {
            recorder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16000)
                setAudioChannels(1)
                setAudioEncodingBitRate(64000)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }

            isRecording = true
            Log.d(TAG, "🎙️ Audio recording started: ${file.absolutePath}, requestId: $requestId")

            module?.emitSpeechRecordingStarted()
        } catch (e: Exception) {
            Log.e(TAG, "Error starting MediaRecorder: ${e.message}", e)
            try {
                recorder.release()
            } catch (_: Exception) {}
            mediaRecorder = null
            isRecording = false
            currentRequestId = null
            currentAudioFile = null
            throw e
        }
    }

    @Synchronized
    private fun stopRecording() {
        if (!isRecording && mediaRecorder == null) {
            Log.d(TAG, "stopRecording called but not recording")
            return
        }

        var stopSucceeded = false
        try {
            mediaRecorder?.apply {
                stop()
                stopSucceeded = true
                release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error during mediaRecorder.stop(): ${e.message}", e)
            try {
                mediaRecorder?.release()
            } catch (_: Exception) {}
        } finally {
            mediaRecorder = null
            isRecording = false
        }

        if (!stopSucceeded) {
            Log.w(TAG, "stopRecording failed; aborting upload")
            cleanupAudioFile()
            currentRequestId = null
            return
        }

        val file = currentAudioFile
        if (file != null && file.exists() && file.length() > 0) {
            val audioUri = Uri.fromFile(file).toString()
            val requestId = currentRequestId ?: ""
            Log.d(TAG, "📤 Emitting onSpeechAudioRecorded with URI: $audioUri, requestId: $requestId (size: ${file.length()} bytes)")
            val params = Arguments.createMap().apply {
                putString("audioUri", audioUri)
                putString("filePath", file.absolutePath)
                putString("requestId", requestId)
            }
            module?.emitSpeechAudioRecorded(params)
        } else {
            Log.w(TAG, "Recorded audio file does not exist or is empty")
            cleanupAudioFile()
            currentRequestId = null
        }
    }

    // endregion

    // region Transcript Setting

    fun setTranscript(text: String, requestId: String? = null, promise: Promise? = null) {
        val reqId = requestId ?: currentRequestId ?: "unknown"
        Log.d(TAG, "📝 setTranscript called: requestId=$reqId, length=${text.length}")

        if (updateResultsCallback == null && endSpeechCallback == null) {
            val errorMsg = "No active voice callbacks available for delivery"
            Log.w(TAG, "⚠️ $errorMsg")
            promise?.reject("NO_CALLBACKS", errorMsg)
            return
        }

        if (requestId != null && currentRequestId != null && requestId != currentRequestId) {
            val errorMsg = "Stale request ID '$requestId' (expected '$currentRequestId')"
            Log.w(TAG, "⚠️ $errorMsg")
            promise?.reject("STALE_REQUEST", errorMsg)
            return
        }

        mainHandler.post {
            try {
                updateResultsCallback?.invoke(text)
                Log.d(TAG, "updateResultsCallback invoked with '$text'")
                endSpeechCallback?.invoke()
                Log.d(TAG, "endSpeechCallback invoked")
                cleanupAudioFile()
                currentRequestId = null
                promise?.resolve(null)
            } catch (e: Exception) {
                Log.e(TAG, "Error delivering transcript callbacks: ${e.message}", e)
                cleanupAudioFile()
                currentRequestId = null
                promise?.reject("DELIVERY_ERROR", e.message, e)
            }
        }
    }

    private fun cleanupAudioFile() {
        try {
            currentAudioFile?.let {
                if (it.exists()) it.delete()
            }
        } catch (_: Exception) {}
        currentAudioFile = null
    }

    // endregion
}
