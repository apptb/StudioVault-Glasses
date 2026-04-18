package com.meta.wearable.dat.externalsampleapps.cameraaccess.azure

import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import com.meta.wearable.dat.externalsampleapps.cameraaccess.openclaw.GeminiToolCall
import com.meta.wearable.dat.externalsampleapps.cameraaccess.openclaw.GeminiToolCallCancellation
import com.meta.wearable.dat.externalsampleapps.cameraaccess.openclaw.ToolDeclarations
import java.io.ByteArrayOutputStream
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.json.JSONArray
import org.json.JSONObject

sealed class AzureConnectionState {
    data object Disconnected : AzureConnectionState()
    data object Connecting : AzureConnectionState()
    data object SettingUp : AzureConnectionState()
    data object Ready : AzureConnectionState()
    data class Error(val message: String) : AzureConnectionState()
}

class AzureRealtimeService {
    companion object {
        private const val TAG = "AzureRealtimeService"
    }

    private val _connectionState = MutableStateFlow<AzureConnectionState>(AzureConnectionState.Disconnected)
    val connectionState: StateFlow<AzureConnectionState> = _connectionState.asStateFlow()

    private val _isModelSpeaking = MutableStateFlow(false)
    val isModelSpeaking: StateFlow<Boolean> = _isModelSpeaking.asStateFlow()

    var onAudioReceived: ((ByteArray) -> Unit)? = null
    var onTurnComplete: (() -> Unit)? = null
    var onInterrupted: (() -> Unit)? = null
    var onDisconnected: ((String?) -> Unit)? = null
    var onInputTranscription: ((String) -> Unit)? = null
    var onOutputTranscription: ((String) -> Unit)? = null
    var onToolCall: ((GeminiToolCall) -> Unit)? = null
    var onToolCallCancellation: ((GeminiToolCallCancellation) -> Unit)? = null

    // Latency tracking
    private var lastUserSpeechEnd: Long = 0
    private var responseLatencyLogged = false

    private var webSocket: WebSocket? = null
    private val sendExecutor = Executors.newSingleThreadExecutor()
    private var connectCallback: ((Boolean) -> Unit)? = null
    private var timeoutTimer: Timer? = null

    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(10, TimeUnit.SECONDS)
        .build()

    fun connect(callback: (Boolean) -> Unit) {
        val url = AzureRealtimeConfig.websocketURL()
        if (url == null) {
            _connectionState.value = AzureConnectionState.Error("Azure OpenAI not configured")
            callback(false)
            return
        }

        _connectionState.value = AzureConnectionState.Connecting
        connectCallback = callback

        val headers = AzureRealtimeConfig.authHeaders()
        val request = Request.Builder()
            .url(url)
            .apply {
                headers.forEach { (key, value) -> addHeader(key, value) }
            }
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket opened")
                _connectionState.value = AzureConnectionState.SettingUp
                sendSessionUpdate()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(text)
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                handleMessage(bytes.utf8())
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                val msg = t.message ?: "Unknown error"
                Log.e(TAG, "WebSocket failure: $msg")
                _connectionState.value = AzureConnectionState.Error(msg)
                _isModelSpeaking.value = false
                resolveConnect(false)
                onDisconnected?.invoke(msg)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closing: $code $reason")
                _connectionState.value = AzureConnectionState.Disconnected
                _isModelSpeaking.value = false
                resolveConnect(false)
                onDisconnected?.invoke("Connection closed (code $code: $reason)")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed: $code $reason")
                _connectionState.value = AzureConnectionState.Disconnected
                _isModelSpeaking.value = false
            }
        })

        // Timeout after 15 seconds
        timeoutTimer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    if (_connectionState.value == AzureConnectionState.Connecting
                        || _connectionState.value == AzureConnectionState.SettingUp
                    ) {
                        Log.e(TAG, "Connection timed out")
                        _connectionState.value = AzureConnectionState.Error("Connection timed out")
                        resolveConnect(false)
                    }
                }
            }, 15000)
        }
    }

    fun disconnect() {
        timeoutTimer?.cancel()
        timeoutTimer = null
        webSocket?.close(1000, null)
        webSocket = null
        onToolCall = null
        onToolCallCancellation = null
        _connectionState.value = AzureConnectionState.Disconnected
        _isModelSpeaking.value = false
        resolveConnect(false)
    }

    fun sendAudio(data: ByteArray) {
        if (_connectionState.value != AzureConnectionState.Ready) return
        sendExecutor.execute {
            val base64 = Base64.encodeToString(data, Base64.NO_WRAP)
            val json = JSONObject().apply {
                put("type", "input_audio_buffer.append")
                put("audio", base64)
            }
            webSocket?.send(json.toString())
        }
    }

    fun sendVideoFrame(bitmap: Bitmap) {
        if (_connectionState.value != AzureConnectionState.Ready) return
        sendExecutor.execute {
            val baos = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, AzureRealtimeConfig.VIDEO_JPEG_QUALITY, baos)
            val base64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
            // Azure Realtime: append image as conversation item
            val json = JSONObject().apply {
                put("type", "conversation.item.create")
                put("item", JSONObject().apply {
                    put("type", "message")
                    put("role", "user")
                    put("content", JSONArray().put(JSONObject().apply {
                        put("type", "input_image")
                        put("image_url", JSONObject().apply {
                            put("url", "data:image/jpeg;base64,$base64")
                        })
                    }))
                })
            }
            webSocket?.send(json.toString())
        }
    }

    fun sendToolResponse(callId: String, output: String) {
        sendExecutor.execute {
            val json = JSONObject().apply {
                put("type", "conversation.item.create")
                put("item", JSONObject().apply {
                    put("type", "function_call_output")
                    put("call_id", callId)
                    put("output", output)
                })
            }
            webSocket?.send(json.toString())

            // After submitting tool output, request the model to continue
            val respond = JSONObject().apply {
                put("type", "response.create")
            }
            webSocket?.send(respond.toString())
        }
    }

    fun commitAudioBuffer() {
        sendExecutor.execute {
            val json = JSONObject().apply {
                put("type", "input_audio_buffer.commit")
            }
            webSocket?.send(json.toString())
        }
    }

    // Private

    private fun resolveConnect(success: Boolean) {
        val cb = connectCallback
        connectCallback = null
        timeoutTimer?.cancel()
        timeoutTimer = null
        cb?.invoke(success)
    }

    private fun sendSessionUpdate() {
        val tools = ToolDeclarations.azureDeclarationsJSON()
        val session = JSONObject().apply {
            put("type", "session.update")
            put("session", JSONObject().apply {
                put("modalities", JSONArray().apply {
                    put("text")
                    put("audio")
                })
                put("instructions", AzureRealtimeConfig.systemInstruction)
                put("voice", "alloy")
                put("input_audio_format", AzureRealtimeConfig.AUDIO_FORMAT)
                put("output_audio_format", AzureRealtimeConfig.AUDIO_FORMAT)
                put("input_audio_transcription", JSONObject().apply {
                    put("model", "whisper-1")
                })
                put("turn_detection", JSONObject().apply {
                    put("type", "server_vad")
                    put("threshold", 0.5)
                    put("prefix_padding_ms", 300)
                    put("silence_duration_ms", 500)
                    put("create_response", true)
                })
                if (tools.length() > 0) {
                    put("tools", tools)
                }
            })
        }
        webSocket?.send(session.toString())
    }

    private fun handleMessage(text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type", "")

            when (type) {
                "session.created", "session.updated" -> {
                    Log.d(TAG, "Session ready: $type")
                    _connectionState.value = AzureConnectionState.Ready
                    resolveConnect(true)
                }

                "response.audio.delta" -> {
                    val delta = json.optString("delta", "")
                    if (delta.isNotEmpty()) {
                        _isModelSpeaking.value = true
                        val audioBytes = Base64.decode(delta, Base64.NO_WRAP)
                        onAudioReceived?.invoke(audioBytes)

                        // Latency tracking
                        if (!responseLatencyLogged && lastUserSpeechEnd > 0) {
                            val latencyMs = System.currentTimeMillis() - lastUserSpeechEnd
                            Log.d(TAG, "Response latency: ${latencyMs}ms")
                            responseLatencyLogged = true
                        }
                    }
                }

                "response.audio.done" -> {
                    // Audio stream complete for this response part
                }

                "response.done" -> {
                    _isModelSpeaking.value = false
                    onTurnComplete?.invoke()
                }

                "response.output_item.added" -> {
                    // New output item started
                }

                "input_audio_buffer.speech_started" -> {
                    // User started speaking — interrupt if model is speaking
                    if (_isModelSpeaking.value) {
                        _isModelSpeaking.value = false
                        onInterrupted?.invoke()
                    }
                }

                "input_audio_buffer.speech_stopped" -> {
                    lastUserSpeechEnd = System.currentTimeMillis()
                    responseLatencyLogged = false
                }

                "input_audio_buffer.committed" -> {
                    // Audio buffer committed
                }

                "conversation.item.input_audio_transcription.completed" -> {
                    val transcript = json.optString("transcript", "")
                    if (transcript.isNotEmpty()) {
                        onInputTranscription?.invoke(transcript)
                    }
                }

                "response.audio_transcript.delta" -> {
                    val delta = json.optString("delta", "")
                    if (delta.isNotEmpty()) {
                        onOutputTranscription?.invoke(delta)
                    }
                }

                "response.function_call_arguments.done" -> {
                    handleFunctionCall(json)
                }

                "error" -> {
                    val error = json.optJSONObject("error")
                    val message = error?.optString("message", "Unknown error") ?: "Unknown error"
                    Log.e(TAG, "Server error: $message")
                    _connectionState.value = AzureConnectionState.Error(message)
                }

                else -> {
                    // Log unhandled message types for debugging
                    if (type.isNotEmpty()) {
                        Log.v(TAG, "Unhandled message type: $type")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message: ${e.message}")
        }
    }

    private fun handleFunctionCall(json: JSONObject) {
        val callId = json.optString("call_id", "")
        val name = json.optString("name", "")
        val argumentsStr = json.optString("arguments", "{}")

        if (name.isEmpty()) return

        Log.d(TAG, "Function call: $name (call_id=$callId)")

        try {
            val arguments = JSONObject(argumentsStr)

            // Map Azure function_call into GeminiToolCall for unified handling
            val toolCall = GeminiToolCall(
                functionCalls = listOf(
                    com.meta.wearable.dat.externalsampleapps.cameraaccess.openclaw.GeminiFunctionCall(
                        id = callId,
                        name = name,
                        args = arguments
                    )
                )
            )
            onToolCall?.invoke(toolCall)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing function call arguments: ${e.message}")
            // Send error response back to model
            sendToolResponse(callId, """{"error": "Failed to parse arguments: ${e.message}"}""")
        }
    }
}
