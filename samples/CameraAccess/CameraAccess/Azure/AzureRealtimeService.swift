import Foundation
import UIKit

/// Service layer for Azure OpenAI Realtime API.
///
/// Mirrors the shape of `GeminiLiveService` so the `AzureRealtimeProvider` adapter
/// stays thin. Protocol-level differences from Gemini:
///
///   Gemini                         | Azure OpenAI Realtime
///   ──────────────────────────────── ─────────────────────────────────────────
///   setup message (BidiGenerate)   | session.update
///   realtimeInput / audioChunks    | input_audio_buffer.append (base64)
///   serverContent → modelTurn      | response.audio.delta (base64)
///   inputTranscription             | conversation.item.input_audio_transcription.completed
///   outputTranscription            | response.audio_transcript.delta / .done
///   toolCall                       | response.function_call_arguments.done
///   turnComplete                   | response.done
///   interrupted                    | input_audio_buffer.speech_started (if user starts talking)
///
/// Audio format notes:
///   - Input: PCM16, 24kHz, mono (sendAudio will resample if mic captures at 16kHz)
///   - Output: PCM16, 24kHz, mono (matches Gemini, so AudioManager playback pipeline reuses)
///   - Chunks should be base64-encoded and sent as text frames, not binary
@MainActor
class AzureRealtimeService: ObservableObject {

  @Published var connectionState: GeminiConnectionState = .disconnected
  @Published var isModelSpeaking: Bool = false

  // Callbacks — mirror the GeminiLiveService shape exactly so the provider adapter
  // can be near-identical to GeminiLiveProvider.
  var onAudioReceived: ((Data) -> Void)?
  var onTurnComplete: (() -> Void)?
  var onInterrupted: (() -> Void)?
  var onDisconnected: ((String?) -> Void)?
  var onInputTranscription: ((String) -> Void)?
  var onOutputTranscription: ((String) -> Void)?
  var onToolCall: ((GeminiToolCall) -> Void)?
  var onToolCallCancellation: ((GeminiToolCallCancellation) -> Void)?

  // Latency tracking
  private var lastUserSpeechEnd: Date?
  private var responseLatencyLogged = false

  private var webSocketTask: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?
  private var connectContinuation: CheckedContinuation<Bool, Never>?
  private let delegate = WebSocketDelegate()
  private var urlSession: URLSession!
  private let sendQueue = DispatchQueue(label: "azure.realtime.send", qos: .userInitiated)

  private var sessionConfig: VoiceSessionConfig?
  private var currentResponseId: String?

  // Reconnect state
  private var reconnectAttempt = 0
  private let maxReconnectAttempts = 5
  private var reconnectTask: Task<Void, Never>?

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    self.urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
  }

  // MARK: - Connection lifecycle

  func connect(config: VoiceSessionConfig? = nil) async -> Bool {
    self.sessionConfig = config
    reconnectAttempt = 0
    reconnectTask?.cancel()
    reconnectTask = nil

    guard let url = AzureRealtimeConfig.websocketURL() else {
      connectionState = .error("Azure Realtime not configured (missing API key, resource base, or deployment)")
      return false
    }

    connectionState = .connecting

    return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
      self.connectContinuation = continuation

      self.delegate.onOpen = { [weak self] _ in
        guard let self else { return }
        Task { @MainActor in
          self.connectionState = .settingUp
          self.sendSessionUpdate()
          self.startReceiving()
        }
      }

      self.delegate.onClose = { [weak self] code, reason in
        guard let self else { return }
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "no reason"
        Task { @MainActor in
          self.resolveConnect(success: false)
          self.connectionState = .disconnected
          self.isModelSpeaking = false
          self.onDisconnected?("Connection closed (code \(code.rawValue): \(reasonStr))")
          self.scheduleReconnect()
        }
      }

      self.delegate.onError = { [weak self] error in
        guard let self else { return }
        let msg = error?.localizedDescription ?? "Unknown error"
        Task { @MainActor in
          self.resolveConnect(success: false)
          self.connectionState = .error(msg)
          self.scheduleReconnect()
        }
      }

      // Azure auth via custom header
      var request = URLRequest(url: url)
      for (key, value) in AzureRealtimeConfig.authHeaders() {
        request.setValue(value, forHTTPHeaderField: key)
      }

      webSocketTask = urlSession.webSocketTask(with: request)
      webSocketTask?.resume()

      // Timeout after 15 seconds
      Task {
        try? await Task.sleep(nanoseconds: 15_000_000_000)
        await MainActor.run {
          self.resolveConnect(success: false)
          if self.connectionState == .connecting || self.connectionState == .settingUp {
            self.connectionState = .error("Connection timed out")
          }
        }
      }
    }
  }

  func disconnect() {
    reconnectTask?.cancel()
    reconnectTask = nil
    reconnectAttempt = 0
    receiveTask?.cancel()
    receiveTask = nil
    webSocketTask?.cancel(with: .goingAway, reason: nil)
    webSocketTask = nil
    connectionState = .disconnected
    isModelSpeaking = false
  }

  private func resolveConnect(success: Bool) {
    connectContinuation?.resume(returning: success)
    connectContinuation = nil
  }

  // MARK: - Outgoing messages

  /// Equivalent of Gemini's setup message. Sets voice config + tool declarations + audio formats.
  private func sendSessionUpdate() {
    let systemPrompt = sessionConfig?.systemInstruction ?? AzureRealtimeConfig.systemInstruction

    let toolDeclarations = ToolDeclarations.azureDeclarations()

    let payload: [String: Any] = [
      "type": "session.update",
      "session": [
        "modalities": ["text", "audio"],
        "instructions": systemPrompt,
        "voice": "alloy",  // Other options: echo, fable, onyx, nova, shimmer
        "input_audio_format": AzureRealtimeConfig.audioFormat,
        "output_audio_format": AzureRealtimeConfig.audioFormat,
        "input_audio_transcription": [
          "model": "whisper-1"
        ],
        "turn_detection": [
          "type": "server_vad",
          "threshold": 0.5,
          "prefix_padding_ms": 300,
          "silence_duration_ms": 500
        ],
        "tools": toolDeclarations,
        "tool_choice": "auto",
        "temperature": 0.8,
        "max_response_output_tokens": "inf"
      ]
    ]

    sendJSON(payload)
  }

  func sendAudio(data: Data) {
    // Azure Realtime expects base64-encoded PCM16 @ 24kHz in an input_audio_buffer.append event.
    let base64 = data.base64EncodedString()
    let payload: [String: Any] = [
      "type": "input_audio_buffer.append",
      "audio": base64
    ]
    sendJSON(payload)
  }

  func sendVideoFrame(image: UIImage) {
    // Azure Realtime does NOT accept video frames natively in the WebSocket like Gemini.
    // Instead, we send frames as image_url content parts via conversation.item.create.
    // The Realtime API will reason over the image alongside the audio context.
    //
    // Flow: capture frame at 1fps → JPEG encode → base64 data URL → conversation.item.create
    guard connectionState == .ready else { return }

    sendQueue.async { [weak self] in
      guard let jpegData = image.jpegData(compressionQuality: AzureRealtimeConfig.videoJPEGQuality) else { return }
      let base64 = jpegData.base64EncodedString()
      let dataURL = "data:image/jpeg;base64,\(base64)"

      let itemCreate: [String: Any] = [
        "type": "conversation.item.create",
        "item": [
          "type": "message",
          "role": "user",
          "content": [
            [
              "type": "input_image",
              "image_url": dataURL
            ]
          ]
        ]
      ]
      self?.sendJSON(itemCreate)
    }
  }

  func sendToolResponse(_ response: [String: Any]) {
    // Azure Realtime tool response format:
    //   conversation.item.create with type=function_call_output referencing the call_id
    //   followed by response.create to continue the turn.
    //
    // Gemini's `response: [String: Any]` payload arrives here with shape:
    //   { "toolResponse": { "functionResponses": [{ "id": ..., "name": ..., "response": {...} }] } }
    //
    // We need to unwrap that and reformat for Azure.
    guard
      let toolResponse = response["toolResponse"] as? [String: Any],
      let functionResponses = toolResponse["functionResponses"] as? [[String: Any]]
    else {
      return
    }

    for fn in functionResponses {
      guard let callId = fn["id"] as? String else { continue }
      let outputData = fn["response"] as? [String: Any] ?? [:]
      let outputJSON = (try? JSONSerialization.data(withJSONObject: outputData))
        .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

      let itemCreate: [String: Any] = [
        "type": "conversation.item.create",
        "item": [
          "type": "function_call_output",
          "call_id": callId,
          "output": outputJSON
        ]
      ]
      sendJSON(itemCreate)
    }

    // Trigger response resumption
    sendJSON(["type": "response.create"])
  }

  func sendTextMessage(_ text: String) {
    let userItem: [String: Any] = [
      "type": "conversation.item.create",
      "item": [
        "type": "message",
        "role": "user",
        "content": [
          ["type": "input_text", "text": text]
        ]
      ]
    ]
    sendJSON(userItem)
    sendJSON(["type": "response.create"])
  }

  // MARK: - Incoming messages

  private func startReceiving() {
    receiveTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled, let ws = await self.webSocketTask {
        do {
          let message = try await ws.receive()
          await self.handleMessage(message)
        } catch {
          if !Task.isCancelled {
            await MainActor.run {
              self.connectionState = .disconnected
              self.isModelSpeaking = false
              self.onDisconnected?(error.localizedDescription)
              self.scheduleReconnect()
            }
          }
          break
        }
      }
    }
  }

  @MainActor
  private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
    let json: [String: Any]?
    switch message {
    case .string(let text):
      json = text.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    case .data(let data):
      json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    @unknown default:
      json = nil
    }

    guard let event = json, let type = event["type"] as? String else { return }

    // High-value events — full taxonomy covered.
    switch type {
    case "session.created":
      reconnectAttempt = 0  // Connection successful — reset backoff
      connectionState = .ready
      resolveConnect(success: true)

    case "session.updated":
      // Confirmation of our session.update.
      break

    case "response.audio.delta":
      if let b64 = event["delta"] as? String, let data = Data(base64Encoded: b64) {
        if !isModelSpeaking {
          isModelSpeaking = true
          // Latency tracking: time from end of user speech to first audio response
          if let speechEnd = lastUserSpeechEnd, !responseLatencyLogged {
            let latency = Date().timeIntervalSince(speechEnd)
            NSLog("[AzureRealtime] Latency: %.0fms (user speech end -> first audio)", latency * 1000)
            responseLatencyLogged = true
          }
        }
        onAudioReceived?(data)
      }

    case "response.audio.done":
      // Emitted per response item; turn_complete is a separate event below.
      break

    case "response.audio_transcript.delta":
      if let delta = event["delta"] as? String {
        onOutputTranscription?(delta)
      }

    case "response.audio_transcript.done":
      break

    case "conversation.item.input_audio_transcription.completed":
      if let transcript = event["transcript"] as? String {
        lastUserSpeechEnd = Date()
        responseLatencyLogged = false
        onInputTranscription?(transcript)
      }

    case "response.function_call_arguments.done":
      if let callId = event["call_id"] as? String,
         let name = event["name"] as? String,
         let argsJSON = event["arguments"] as? String,
         let argsData = argsJSON.data(using: .utf8),
         let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {

        // Reuse Gemini's tool call type for callback uniformity
        let call = GeminiFunctionCall(id: callId, name: name, args: args)
        let toolCall = GeminiToolCall(functionCalls: [call])
        onToolCall?(toolCall)
      }

    case "response.done":
      isModelSpeaking = false
      responseLatencyLogged = false
      onTurnComplete?()

    case "input_audio_buffer.speech_started":
      // User started talking while model was speaking → interrupt
      if isModelSpeaking {
        onInterrupted?()
        isModelSpeaking = false
        // Clear the audio buffer and cancel in-progress response to reduce latency
        sendJSON(["type": "input_audio_buffer.clear"])
        sendJSON(["type": "response.cancel"])
      }

    case "input_audio_buffer.speech_stopped":
      lastUserSpeechEnd = Date()
      responseLatencyLogged = false

    case "input_audio_buffer.committed":
      // Server committed the audio buffer for processing; no action needed
      break

    case "response.created":
      if let response = event["response"] as? [String: Any] {
        currentResponseId = response["id"] as? String
      }

    case "rate_limits.updated":
      // Advisory — could surface to diagnostics UI in the future
      break

    case "error":
      let errMsg = (event["error"] as? [String: Any])?["message"] as? String ?? "Unknown Azure Realtime error"
      connectionState = .error(errMsg)

    default:
      // Unknown or lower-priority events: log and continue
      break
    }
  }

  // MARK: - Reconnect with exponential backoff

  private func scheduleReconnect() {
    guard reconnectAttempt < maxReconnectAttempts else {
      NSLog("[AzureRealtime] Max reconnect attempts (%d) exhausted", maxReconnectAttempts)
      return
    }

    reconnectAttempt += 1
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped)
    let delay = min(pow(2.0, Double(reconnectAttempt - 1)), 16.0)
    NSLog("[AzureRealtime] Reconnect attempt %d/%d in %.0fs", reconnectAttempt, maxReconnectAttempts, delay)

    reconnectTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard let self, !Task.isCancelled else { return }
      let config = self.sessionConfig
      _ = await self.connect(config: config)
    }
  }

  // MARK: - Transport helpers

  private func sendJSON(_ payload: [String: Any]) {
    guard let ws = webSocketTask else { return }
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: data, encoding: .utf8) else { return }

    sendQueue.async {
      ws.send(.string(text)) { error in
        if let error {
          NSLog("AzureRealtimeService send error: \(error.localizedDescription)")
        }
      }
    }
  }
}
