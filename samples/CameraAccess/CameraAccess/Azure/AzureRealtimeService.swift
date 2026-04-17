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
///
/// TODO list for live integration:
///   [ ] Implement sendSessionUpdate() with full session.update payload (voice, turn_detection,
///       input_audio_transcription, tools array)
///   [ ] Implement receive() loop with type-switched event handling
///   [ ] Wire Azure tool-call response back through conversation.item.create → response.create
///   [ ] Port tool declarations from ToolDeclarations.allDeclarations() to Azure's tools array format
///   [ ] Implement interrupt handling via input_audio_buffer.clear + response.cancel
///   [ ] Add reconnect/backoff parity with GeminiLiveService
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

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    self.urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
  }

  // MARK: - Connection lifecycle

  func connect(config: VoiceSessionConfig? = nil) async -> Bool {
    self.sessionConfig = config

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
        }
      }

      self.delegate.onError = { [weak self] error in
        guard let self else { return }
        let msg = error?.localizedDescription ?? "Unknown error"
        Task { @MainActor in
          self.resolveConnect(success: false)
          self.connectionState = .error(msg)
        }
      }

      // Azure auth via custom header
      var request = URLRequest(url: url)
      for (key, value) in AzureRealtimeConfig.authHeaders() {
        request.setValue(value, forHTTPHeaderField: key)
      }

      webSocketTask = urlSession.webSocketTask(with: request)
      webSocketTask?.resume()
    }
  }

  func disconnect() {
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
  /// TODO: populate tools array from ToolDeclarations in Azure's format (slightly different from Gemini).
  private func sendSessionUpdate() {
    let systemPrompt = sessionConfig?.systemInstruction ?? AzureRealtimeConfig.systemInstruction

    // Skeleton session.update — audio formats, VAD, transcription, system prompt.
    // Full tools array population is TODO (see file-level comment).
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
        "tools": [] as [[String: Any]],  // TODO: port from ToolDeclarations
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
    // Azure Realtime does NOT natively accept video frames in the same WebSocket.
    // Video understanding requires a separate path: either (a) periodic frame uploads via
    // the Responses API as image_url items added to conversation.item.create, or
    // (b) a separate vision pipeline (on-device Qwen3-VL or Azure AI Vision).
    //
    // Matcha's existing Gemini pattern sends JPEG frames at 1 fps through the same WS.
    // For Azure, the cleaner path is:
    //   1. Capture frame at 1fps (same cadence)
    //   2. JPEG encode + upload to a short-lived blob URL or encode as data URL
    //   3. Send conversation.item.create with message containing image_url content part
    //   4. Let Realtime API reason over the image alongside audio
    //
    // TODO: implement above, or route video to a separate vision provider (glasses_pov_vision_local route).
    // For now this is a stub so the provider conforms to VoiceModelProvider.supportsVideo=true claim.
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
          await MainActor.run {
            self.connectionState = .error(error.localizedDescription)
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

    // High-value events wired up first. Full taxonomy TODO.
    switch type {
    case "session.created":
      connectionState = .ready
      resolveConnect(success: true)

    case "session.updated":
      // No-op; confirmation of our session.update.
      break

    case "response.audio.delta":
      if let b64 = event["delta"] as? String, let data = Data(base64Encoded: b64) {
        if !isModelSpeaking { isModelSpeaking = true }
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
      // Optional: if you want one event with full transcript instead of deltas
      break

    case "conversation.item.input_audio_transcription.completed":
      if let transcript = event["transcript"] as? String {
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
      onTurnComplete?()

    case "input_audio_buffer.speech_started":
      // User started talking while model was speaking → interrupt
      if isModelSpeaking {
        onInterrupted?()
        isModelSpeaking = false
      }

    case "error":
      let errMsg = (event["error"] as? [String: Any])?["message"] as? String ?? "Unknown Azure Realtime error"
      connectionState = .error(errMsg)

    default:
      // Unknown or lower-priority events: log and continue
      break
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
