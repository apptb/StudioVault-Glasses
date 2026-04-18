package com.meta.wearable.dat.externalsampleapps.cameraaccess.azure

import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager

object AzureRealtimeConfig {

    const val API_VERSION = "2025-04-01-preview"

    const val INPUT_AUDIO_SAMPLE_RATE = 24000
    const val OUTPUT_AUDIO_SAMPLE_RATE = 24000
    const val AUDIO_CHANNELS = 1
    const val AUDIO_BITS_PER_SAMPLE = 16
    const val AUDIO_FORMAT = "pcm16"

    const val VIDEO_FRAME_INTERVAL_MS = 1000L
    const val VIDEO_JPEG_QUALITY = 50

    val resourceBase: String
        get() = SettingsManager.azureRealtimeBase

    val deploymentName: String
        get() = SettingsManager.azureRealtimeDeployment

    val apiKey: String
        get() = SettingsManager.azureOpenAIAPIKey

    val systemInstruction: String
        get() = SettingsManager.azureRealtimeSystemPrompt

    val isConfigured: Boolean
        get() = apiKey.isNotEmpty()
                && apiKey != "YOUR_AZURE_OPENAI_API_KEY"
                && resourceBase.isNotEmpty()
                && deploymentName.isNotEmpty()

    fun websocketURL(): String? {
        if (!isConfigured) return null
        return "wss://$resourceBase/openai/realtime" +
                "?deployment=$deploymentName" +
                "&api-version=$API_VERSION"
    }

    fun authHeaders(): Map<String, String> = mapOf(
        "api-key" to apiKey,
        "User-Agent" to "StudioVault-Glasses/0.1 (Android)"
    )

    fun describe(): String = """
        Azure OpenAI Realtime
        Resource: $resourceBase
        Deployment: $deploymentName
        API version: $API_VERSION
        Audio: $AUDIO_FORMAT @ ${INPUT_AUDIO_SAMPLE_RATE}Hz mono
        Configured: $isConfigured
    """.trimIndent()
}
