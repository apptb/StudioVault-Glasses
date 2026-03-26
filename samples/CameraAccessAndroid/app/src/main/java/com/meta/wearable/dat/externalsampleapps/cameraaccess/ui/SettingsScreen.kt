package com.meta.wearable.dat.externalsampleapps.cameraaccess.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.AgentBackend
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

private enum class ConnectionTestStatus {
    IDLE, CHECKING, CONNECTED, UNREACHABLE
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    onRecentTasks: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    var geminiAPIKey by remember { mutableStateOf(SettingsManager.geminiAPIKey) }
    var systemPrompt by remember { mutableStateOf(SettingsManager.geminiSystemPrompt) }
    var selectedBackend by remember { mutableStateOf(SettingsManager.agentBackend) }
    var agentBaseURL by remember { mutableStateOf(SettingsManager.agentBaseURL) }
    var agentToken by remember { mutableStateOf(SettingsManager.agentToken) }
    var openClawHost by remember { mutableStateOf(SettingsManager.openClawHost) }
    var openClawPort by remember { mutableStateOf(SettingsManager.openClawPort.toString()) }
    var openClawHookToken by remember { mutableStateOf(SettingsManager.openClawHookToken) }
    var openClawGatewayToken by remember { mutableStateOf(SettingsManager.openClawGatewayToken) }
    var webrtcSignalingURL by remember { mutableStateOf(SettingsManager.webrtcSignalingURL) }
    var showResetDialog by remember { mutableStateOf(false) }
    var connectionTestStatus by remember { mutableStateOf(ConnectionTestStatus.IDLE) }
    var connectionTestError by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    fun save() {
        SettingsManager.geminiAPIKey = geminiAPIKey.trim()
        SettingsManager.geminiSystemPrompt = systemPrompt.trim()
        SettingsManager.agentBackend = selectedBackend
        SettingsManager.agentBaseURL = agentBaseURL.trim()
        SettingsManager.agentToken = agentToken.trim()
        SettingsManager.openClawHost = openClawHost.trim()
        openClawPort.trim().toIntOrNull()?.let { SettingsManager.openClawPort = it }
        SettingsManager.openClawHookToken = openClawHookToken.trim()
        SettingsManager.openClawGatewayToken = openClawGatewayToken.trim()
        SettingsManager.webrtcSignalingURL = webrtcSignalingURL.trim()
    }

    fun reload() {
        geminiAPIKey = SettingsManager.geminiAPIKey
        systemPrompt = SettingsManager.geminiSystemPrompt
        selectedBackend = SettingsManager.agentBackend
        agentBaseURL = SettingsManager.agentBaseURL
        agentToken = SettingsManager.agentToken
        openClawHost = SettingsManager.openClawHost
        openClawPort = SettingsManager.openClawPort.toString()
        openClawHookToken = SettingsManager.openClawHookToken
        openClawGatewayToken = SettingsManager.openClawGatewayToken
        webrtcSignalingURL = SettingsManager.webrtcSignalingURL
    }

    fun testConnection() {
        val host = openClawHost.trim()
        val port = openClawPort.trim()
        val token = openClawGatewayToken.trim()

        if (host.isEmpty() || token.isEmpty()) {
            connectionTestStatus = ConnectionTestStatus.UNREACHABLE
            connectionTestError = "Missing host or token"
            return
        }

        val base = "$host:${port.ifEmpty { "18789" }}"
        val url = "$base/v1/chat/completions"

        connectionTestStatus = ConnectionTestStatus.CHECKING

        scope.launch {
            try {
                val result = withContext(Dispatchers.IO) {
                    val pingClient = OkHttpClient.Builder()
                        .readTimeout(5, TimeUnit.SECONDS)
                        .connectTimeout(5, TimeUnit.SECONDS)
                        .build()

                    val request = Request.Builder()
                        .url(url)
                        .get()
                        .addHeader("Authorization", "Bearer $token")
                        .build()

                    val response = pingClient.newCall(request).execute()
                    val code = response.code
                    response.close()
                    code
                }
                if (result in 200..499) {
                    connectionTestStatus = ConnectionTestStatus.CONNECTED
                } else {
                    connectionTestStatus = ConnectionTestStatus.UNREACHABLE
                    connectionTestError = "Unexpected response"
                }
            } catch (e: Exception) {
                connectionTestStatus = ConnectionTestStatus.UNREACHABLE
                connectionTestError = "Unreachable"
            }
        }
    }

    Column(modifier = modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Settings") },
            navigationIcon = {
                IconButton(onClick = {
                    save()
                    onBack()
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                }
            },
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Gemini section
            SectionHeader("Gemini API")
            MonoTextField(
                value = geminiAPIKey,
                onValueChange = { geminiAPIKey = it },
                label = "API Key",
                placeholder = "Enter Gemini API key",
            )

            SectionHeader("System Prompt")
            OutlinedTextField(
                value = systemPrompt,
                onValueChange = { systemPrompt = it },
                label = { Text("System prompt") },
                modifier = Modifier.fillMaxWidth().height(200.dp),
                textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
            )

            // Agent Backend picker
            SectionHeader("Agent Backend")
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                AgentBackend.entries.forEachIndexed { index, backend ->
                    SegmentedButton(
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = AgentBackend.entries.size,
                        ),
                        onClick = { selectedBackend = backend },
                        selected = selectedBackend == backend,
                    ) {
                        Text(backend.label)
                    }
                }
            }

            // Conditional: E2B section
            if (selectedBackend == AgentBackend.E2B) {
                SectionHeader("E2B Agent")
                Text(
                    "Connect to the Matcha agent API (E2B + Claude Agent SDK) for task execution.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                MonoTextField(
                    value = agentBaseURL,
                    onValueChange = { agentBaseURL = it },
                    label = "Base URL",
                    placeholder = "https://your-deployment.vercel.app",
                    keyboardType = KeyboardType.Uri,
                )
                MonoTextField(
                    value = agentToken,
                    onValueChange = { agentToken = it },
                    label = "API Token",
                    placeholder = "Shared secret token",
                )
            }

            // Conditional: OpenClaw section
            if (selectedBackend == AgentBackend.OPENCLAW) {
                SectionHeader("OpenClaw")
                Text(
                    "Connect to an OpenClaw gateway running on your Mac for agentic tool-calling.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                MonoTextField(
                    value = openClawHost,
                    onValueChange = { openClawHost = it },
                    label = "Host",
                    placeholder = "http://your-mac.local",
                    keyboardType = KeyboardType.Uri,
                )
                MonoTextField(
                    value = openClawPort,
                    onValueChange = { openClawPort = it },
                    label = "Port",
                    placeholder = "18789",
                    keyboardType = KeyboardType.Number,
                )
                MonoTextField(
                    value = openClawHookToken,
                    onValueChange = { openClawHookToken = it },
                    label = "Hook Token",
                    placeholder = "Hook token",
                )
                MonoTextField(
                    value = openClawGatewayToken,
                    onValueChange = { openClawGatewayToken = it },
                    label = "Gateway Token",
                    placeholder = "Gateway auth token",
                )

                // Test Connection button
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Button(
                        onClick = { testConnection() },
                        enabled = connectionTestStatus != ConnectionTestStatus.CHECKING
                                && openClawHost.trim().isNotEmpty(),
                    ) {
                        if (connectionTestStatus == ConnectionTestStatus.CHECKING) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.onPrimary,
                            )
                            Spacer(Modifier.width(8.dp))
                        }
                        Text(
                            if (connectionTestStatus == ConnectionTestStatus.CHECKING)
                                "Testing..." else "Test Connection"
                        )
                    }

                    Spacer(Modifier.width(12.dp))

                    when (connectionTestStatus) {
                        ConnectionTestStatus.CONNECTED -> {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFF4CAF50))
                                )
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    "Connected",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color(0xFF4CAF50),
                                )
                            }
                        }
                        ConnectionTestStatus.UNREACHABLE -> {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFFF44336))
                                )
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    connectionTestError,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color(0xFFF44336),
                                    maxLines = 1,
                                )
                            }
                        }
                        else -> {}
                    }
                }
            }

            // WebRTC section
            SectionHeader("WebRTC")
            MonoTextField(
                value = webrtcSignalingURL,
                onValueChange = { webrtcSignalingURL = it },
                label = "Signaling URL",
                placeholder = "wss://your-server.example.com",
                keyboardType = KeyboardType.Uri,
            )

            // History
            if (onRecentTasks != null) {
                SectionHeader("History")
                TextButton(onClick = onRecentTasks) {
                    Text("Recent Tasks")
                }
            }

            // Reset
            TextButton(onClick = { showResetDialog = true }) {
                Text("Reset to Defaults", color = Color.Red)
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text("Reset Settings") },
            text = { Text("This will reset all settings to the values built into the app.") },
            confirmButton = {
                TextButton(onClick = {
                    SettingsManager.resetAll()
                    reload()
                    showResetDialog = false
                }) {
                    Text("Reset", color = Color.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
private fun MonoTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        placeholder = { Text(placeholder) },
        modifier = Modifier.fillMaxWidth(),
        textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
    )
}
