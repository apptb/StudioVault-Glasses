import Foundation
import SwiftUI

/// AgentCoordinator orchestrates the dual-agent architecture:
/// - VoiceAgent handles real-time voice conversation (synchronous)
/// - ActionAgent executes tasks in the background (asynchronous)
///
/// When the voice model requests a tool call, the coordinator routes it
/// to the ActionAgent. When the ActionAgent completes, the result is
/// sent back through the VoiceAgent to the voice model.
@MainActor
class AgentCoordinator: ObservableObject {
  let voiceAgent: VoiceAgent
  let actionAgent: ActionAgent
  private let openClawBridge: OpenClawBridge

  @Published var toolCallStatus: ToolCallStatus = .idle
  @Published var openClawConnectionState: OpenClawConnectionState = .notConfigured

  private var stateObservation: Task<Void, Never>?

  init(
    voiceModelProvider: VoiceModelProvider,
    audioManager: AudioManager,
    openClawBridge: OpenClawBridge
  ) {
    self.openClawBridge = openClawBridge
    self.voiceAgent = VoiceAgent(provider: voiceModelProvider, audioManager: audioManager)
    self.actionAgent = ActionAgent(bridge: openClawBridge)
    wireAgents()
  }

  func startSession(config: VoiceSessionConfig, streamingMode: StreamingMode) async -> Bool {
    // Check OpenClaw connectivity
    await openClawBridge.checkConnection()
    openClawBridge.resetSession()

    // Start state observation
    startStateObservation()

    // Start voice agent (connects to model, starts audio)
    let success = await voiceAgent.start(config: config, streamingMode: streamingMode)
    return success
  }

  func stopSession() {
    actionAgent.cancelAll()
    voiceAgent.stop()
    stateObservation?.cancel()
    stateObservation = nil
    toolCallStatus = .idle
  }

  func sendVideoFrame(_ image: UIImage) {
    voiceAgent.sendVideoFrameIfThrottled(image: image)
  }

  // MARK: - Private

  private func wireAgents() {
    // Voice Agent -> Action Agent: route tool calls
    voiceAgent.onToolCall = { [weak self] id, name, args in
      guard let self else { return }
      let taskDesc = args["task"] as? String ?? String(describing: args)
      let task = AgentTask(id: id, name: name, description: taskDesc)
      self.actionAgent.executeTask(task)
    }

    voiceAgent.onToolCallCancellation = { [weak self] ids in
      guard let self else { return }
      for id in ids {
        self.actionAgent.cancelTask(id: id)
      }
    }

    // Action Agent -> Voice Agent: deliver results back to voice model
    actionAgent.onResult = { [weak self] result in
      self?.voiceAgent.sendToolResponse(result.responsePayload)
    }
  }

  private func startStateObservation() {
    stateObservation = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        guard !Task.isCancelled, let self else { break }
        self.toolCallStatus = self.openClawBridge.lastToolCallStatus
        self.openClawConnectionState = self.openClawBridge.connectionState
      }
    }
  }
}
