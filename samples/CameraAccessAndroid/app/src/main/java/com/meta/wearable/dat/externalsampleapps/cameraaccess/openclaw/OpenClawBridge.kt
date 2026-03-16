package com.meta.wearable.dat.externalsampleapps.cameraaccess.openclaw

import android.util.Log
import com.meta.wearable.dat.externalsampleapps.cameraaccess.gemini.GeminiConfig
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.AgentBackend
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

class OpenClawBridge {
    companion object {
        private const val TAG = "AgentBridge"
    }

    private val _lastToolCallStatus = MutableStateFlow<ToolCallStatus>(ToolCallStatus.Idle)
    val lastToolCallStatus: StateFlow<ToolCallStatus> = _lastToolCallStatus.asStateFlow()

    private val _connectionState = MutableStateFlow<OpenClawConnectionState>(OpenClawConnectionState.NotConfigured)
    val connectionState: StateFlow<OpenClawConnectionState> = _connectionState.asStateFlow()

    fun setToolCallStatus(status: ToolCallStatus) {
        _lastToolCallStatus.value = status
    }

    private val client = OkHttpClient.Builder()
        .readTimeout(120, TimeUnit.SECONDS)
        .connectTimeout(10, TimeUnit.SECONDS)
        .build()

    private val pingClient = OkHttpClient.Builder()
        .readTimeout(5, TimeUnit.SECONDS)
        .connectTimeout(5, TimeUnit.SECONDS)
        .build()

    private var sessionKey: String = newSessionKey()
    private val conversationHistory = mutableListOf<JSONObject>()

    /** Track last-used backend to detect switches */
    private var lastUsedBackend: AgentBackend? = null

    /** Which backend this bridge is using (reads dynamically from settings) */
    val backend: AgentBackend
        get() = SettingsManager.agentBackend

    /** Max conversation history turns varies by backend */
    private val maxHistoryTurns: Int
        get() = if (backend == AgentBackend.OPENCLAW) 10 else 3

    // -- Connection Check --

    suspend fun checkConnection() = withContext(Dispatchers.IO) {
        when (backend) {
            AgentBackend.E2B -> checkE2BConnection()
            AgentBackend.OPENCLAW -> checkOpenClawConnection()
        }
    }

    private fun checkE2BConnection() {
        if (!GeminiConfig.isE2BConfigured) {
            _connectionState.value = OpenClawConnectionState.NotConfigured
            return
        }
        _connectionState.value = OpenClawConnectionState.Checking

        val url = "${GeminiConfig.agentBaseURL}/api/agent/health"
        try {
            val request = Request.Builder()
                .url(url)
                .get()
                .addHeader("x-api-token", GeminiConfig.agentToken)
                .build()

            val response = pingClient.newCall(request).execute()
            val code = response.code
            response.close()

            if (code in 200..499) {
                _connectionState.value = OpenClawConnectionState.Connected
                Log.d(TAG, "[E2B] Gateway reachable (HTTP $code)")
            } else {
                _connectionState.value = OpenClawConnectionState.Unreachable("Unexpected response")
            }
        } catch (e: Exception) {
            _connectionState.value = OpenClawConnectionState.Unreachable(e.message ?: "Unknown error")
            Log.d(TAG, "[E2B] Gateway unreachable: ${e.message}")
        }
    }

    private fun checkOpenClawConnection() {
        val host = SettingsManager.openClawHost
        val token = SettingsManager.openClawGatewayToken
        if (host.isEmpty() || token.isEmpty()) {
            _connectionState.value = OpenClawConnectionState.NotConfigured
            return
        }
        _connectionState.value = OpenClawConnectionState.Checking

        val url = "$host:${SettingsManager.openClawPort}/v1/chat/completions"
        try {
            val request = Request.Builder()
                .url(url)
                .get()
                .addHeader("Authorization", "Bearer $token")
                .build()

            val response = pingClient.newCall(request).execute()
            val code = response.code
            response.close()

            if (code in 200..499) {
                _connectionState.value = OpenClawConnectionState.Connected
                Log.d(TAG, "[OpenClaw] Gateway reachable (HTTP $code)")
            } else {
                _connectionState.value = OpenClawConnectionState.Unreachable("Unexpected response")
            }
        } catch (e: Exception) {
            _connectionState.value = OpenClawConnectionState.Unreachable(e.message ?: "Unknown error")
            Log.d(TAG, "[OpenClaw] Gateway unreachable: ${e.message}")
        }
    }

    fun resetSession() {
        sessionKey = newSessionKey()
        conversationHistory.clear()
        Log.d(TAG, "New session: $sessionKey")
    }

    // -- Task Delegation --

    suspend fun delegateTask(
        task: String,
        toolName: String = "execute"
    ): ToolResult = withContext(Dispatchers.IO) {
        // Detect backend switch and reset connection state
        val currentBackend = backend
        if (lastUsedBackend != null && lastUsedBackend != currentBackend) {
            Log.d(TAG, "Backend switched from ${lastUsedBackend?.label} to ${currentBackend.label}, resetting")
            _connectionState.value = OpenClawConnectionState.NotConfigured
        }
        lastUsedBackend = currentBackend

        _lastToolCallStatus.value = ToolCallStatus.Executing(toolName)

        try {
            val content = when (currentBackend) {
                AgentBackend.E2B -> sendViaE2B(task)
                AgentBackend.OPENCLAW -> sendViaOpenClaw(task)
            }
            Log.d(TAG, "[${currentBackend.label}] Result: ${content.take(200)}")
            _lastToolCallStatus.value = ToolCallStatus.Completed(toolName)
            return@withContext ToolResult.Success(content)
        } catch (e: Exception) {
            Log.e(TAG, "[${currentBackend.label}] Error: ${e.message}")
            _lastToolCallStatus.value = ToolCallStatus.Failed(toolName, e.message ?: "Unknown")
            return@withContext ToolResult.Failure("Agent error: ${e.message}")
        }
    }

    // -- E2B Backend --

    private fun sendViaE2B(task: String): String {
        val baseURL = GeminiConfig.agentBaseURL
        val token = GeminiConfig.agentToken
        val url = "$baseURL/api/agent/chat"

        // Append user message
        conversationHistory.add(JSONObject().apply {
            put("role", "user")
            put("content", task)
        })
        trimHistory()

        Log.d(TAG, "[E2B] Sending ${conversationHistory.size} messages in conversation")

        val messagesArray = JSONArray()
        for (msg in conversationHistory) {
            messagesArray.put(msg)
        }

        val body = JSONObject().apply {
            put("model", "claude-agent")
            put("messages", messagesArray)
            put("stream", false)
        }

        val request = Request.Builder()
            .url(url)
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .addHeader("Content-Type", "application/json")
            .addHeader("x-api-token", token)
            .addHeader("x-agent-session-key", sessionKey)
            .build()

        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: ""
        val statusCode = response.code
        response.close()

        if (statusCode !in 200..299) {
            Log.d(TAG, "[E2B] Chat failed: HTTP $statusCode - ${responseBody.take(200)}")
            throw RuntimeException("HTTP $statusCode")
        }

        val json = JSONObject(responseBody)
        val choices = json.optJSONArray("choices")
        val content = choices?.optJSONObject(0)
            ?.optJSONObject("message")
            ?.optString("content", "")

        val result = if (!content.isNullOrEmpty()) content else responseBody
        conversationHistory.add(JSONObject().apply {
            put("role", "assistant")
            put("content", result)
        })
        Log.d(TAG, "[E2B] Agent result: ${result.take(200)}")
        return result
    }

    // -- OpenClaw Backend --

    private fun sendViaOpenClaw(task: String): String {
        val host = SettingsManager.openClawHost
        val port = SettingsManager.openClawPort
        val gatewayToken = SettingsManager.openClawGatewayToken
        val url = "$host:$port/v1/chat/completions"

        // Append user message
        conversationHistory.add(JSONObject().apply {
            put("role", "user")
            put("content", task)
        })
        trimHistory()

        Log.d(TAG, "[OpenClaw] Sending ${conversationHistory.size} messages in conversation")

        val messagesArray = JSONArray()
        for (msg in conversationHistory) {
            messagesArray.put(msg)
        }

        val body = JSONObject().apply {
            put("model", "openclaw")
            put("messages", messagesArray)
            put("stream", false)
        }

        val request = Request.Builder()
            .url(url)
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .addHeader("Authorization", "Bearer $gatewayToken")
            .addHeader("Content-Type", "application/json")
            .addHeader("x-openclaw-session-key", sessionKey)
            .build()

        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: ""
        val statusCode = response.code
        response.close()

        if (statusCode !in 200..299) {
            Log.d(TAG, "[OpenClaw] Chat failed: HTTP $statusCode - ${responseBody.take(200)}")
            throw RuntimeException("HTTP $statusCode")
        }

        val json = JSONObject(responseBody)
        val choices = json.optJSONArray("choices")
        val content = choices?.optJSONObject(0)
            ?.optJSONObject("message")
            ?.optString("content", "")

        val result = if (!content.isNullOrEmpty()) content else responseBody
        conversationHistory.add(JSONObject().apply {
            put("role", "assistant")
            put("content", result)
        })
        Log.d(TAG, "[OpenClaw] Agent result: ${result.take(200)}")
        return result
    }

    // -- Helpers --

    private fun trimHistory() {
        if (conversationHistory.size > maxHistoryTurns * 2) {
            val trimmed = conversationHistory.takeLast(maxHistoryTurns * 2)
            conversationHistory.clear()
            conversationHistory.addAll(trimmed)
        }
    }

    private fun newSessionKey(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        val ts = formatter.format(Date())
        return "agent:main:glass:$ts"
    }
}
