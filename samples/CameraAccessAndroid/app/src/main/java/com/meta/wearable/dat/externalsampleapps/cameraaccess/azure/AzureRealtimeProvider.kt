package com.meta.wearable.dat.externalsampleapps.cameraaccess.azure

import android.graphics.Bitmap
import android.util.Log

/**
 * Thin adapter that wraps AzureRealtimeService to provide a provider-neutral
 * interface matching the patterns used by GeminiLiveService.
 *
 * This is a scaffold — a full ViewModel integration (like GeminiSessionViewModel)
 * should be built once the Azure service is validated end-to-end.
 */
class AzureRealtimeProvider {
    companion object {
        private const val TAG = "AzureRealtimeProvider"
    }

    val service = AzureRealtimeService()

    val connectionState get() = service.connectionState
    val isModelSpeaking get() = service.isModelSpeaking

    fun connect(callback: (Boolean) -> Unit) {
        if (!AzureRealtimeConfig.isConfigured) {
            Log.w(TAG, "Azure OpenAI not configured — skipping connect")
            callback(false)
            return
        }
        Log.d(TAG, "Connecting to Azure OpenAI Realtime:\n${AzureRealtimeConfig.describe()}")
        service.connect(callback)
    }

    fun disconnect() {
        service.disconnect()
    }

    fun sendAudio(data: ByteArray) {
        service.sendAudio(data)
    }

    fun sendVideoFrame(bitmap: Bitmap) {
        service.sendVideoFrame(bitmap)
    }

    fun sendToolResponse(callId: String, output: String) {
        service.sendToolResponse(callId, output)
    }
}
