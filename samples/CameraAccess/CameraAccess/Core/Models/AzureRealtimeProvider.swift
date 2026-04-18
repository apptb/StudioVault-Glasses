import Foundation
import UIKit

/// Adapter that wraps `AzureRealtimeService` to conform to `VoiceModelProvider`.
///
/// Intentionally structured identically to `GeminiLiveProvider` so the backend switcher
/// in `CallManager` / `VoiceAgent` treats Gemini and Azure Realtime symmetrically.
/// The adapter translates callback-based service API into an AsyncStream<VoiceModelEvent>.
///
/// Known differences vs Gemini (see AzureRealtimeService.swift file-level docs for protocol map):
///   - Azure video handling is NOT native to the Realtime WebSocket — see sendVideoFrame() stub
///   - supportsVideo is set to `false` for now; flip to `true` after implementing the
///     conversation.item.create image_url path in the service
@MainActor
class AzureRealtimeProvider: VoiceModelProvider {

  let id = "azure-realtime"
  let name = "Azure OpenAI Realtime"

  /// Video frames sent via conversation.item.create with input_image content parts.
  /// The Realtime API reasons over images alongside the audio context.
  let supportsVideo = true

  var connectionState: VoiceModelConnectionState {
    VoiceModelConnectionState(from: service.connectionState)
  }

  var isModelSpeaking: Bool {
    service.isModelSpeaking
  }

  let events: AsyncStream<VoiceModelEvent>
  private let continuation: AsyncStream<VoiceModelEvent>.Continuation
  private let service = AzureRealtimeService()

  init() {
    let (stream, continuation) = AsyncStream.makeStream(of: VoiceModelEvent.self)
    self.events = stream
    self.continuation = continuation
  }

  func connect(config: VoiceSessionConfig) async -> Bool {
    wireCallbacks()
    let success = await service.connect(config: config)
    if success {
      continuation.yield(.sessionStarted)
    }
    return success
  }

  func disconnect() {
    service.disconnect()
    continuation.yield(.sessionEnded(reason: nil))
    continuation.finish()
  }

  func sendAudio(data: Data) {
    service.sendAudio(data: data)
  }

  func sendVideoFrame(image: UIImage) {
    service.sendVideoFrame(image: image)  // Currently stubbed — see service docs
  }

  func sendToolResponse(_ response: [String: Any]) {
    service.sendToolResponse(response)
  }

  func sendTextMessage(_ text: String) {
    service.sendTextMessage(text)
  }

  // MARK: - Private

  private func wireCallbacks() {
    var wasSpeaking = false

    service.onAudioReceived = { [weak self] data in
      guard let self else { return }
      let speaking = self.service.isModelSpeaking
      if speaking != wasSpeaking {
        wasSpeaking = speaking
        self.continuation.yield(.modelSpeakingChanged(speaking))
      }
      self.continuation.yield(.audioResponse(data))
    }

    service.onInputTranscription = { [weak self] text in
      self?.continuation.yield(.inputTranscription(text))
    }

    service.onOutputTranscription = { [weak self] text in
      self?.continuation.yield(.outputTranscription(text))
    }

    service.onToolCall = { [weak self] toolCall in
      guard let self else { return }
      for call in toolCall.functionCalls {
        self.continuation.yield(.toolCall(id: call.id, name: call.name, args: call.args))
      }
    }

    service.onToolCallCancellation = { [weak self] cancellation in
      self?.continuation.yield(.toolCallCancellation(ids: cancellation.ids))
    }

    service.onTurnComplete = { [weak self] in
      wasSpeaking = false
      self?.continuation.yield(.modelSpeakingChanged(false))
      self?.continuation.yield(.turnComplete)
    }

    service.onInterrupted = { [weak self] in
      wasSpeaking = false
      self?.continuation.yield(.modelSpeakingChanged(false))
      self?.continuation.yield(.interrupted)
    }

    service.onDisconnected = { [weak self] reason in
      self?.continuation.yield(.sessionEnded(reason: reason))
    }
  }
}
