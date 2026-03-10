import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
  // MARK: - Published State
  @Published var messages: [ChatMessage] = []
  @Published var inputText: String = ""
  @Published var isSending: Bool = false
  @Published var errorMessage: String?

  // Voice mode
  @Published var isVoiceModeActive: Bool = false
  @Published var voiceConnectionState: GeminiConnectionState = .disconnected
  @Published var isModelSpeaking: Bool = false
  @Published var userTranscript: String = ""
  @Published var aiTranscript: String = ""
  @Published var toolCallStatus: ToolCallStatus = .idle

  // MARK: - Dependencies
  private let openClawBridge = OpenClawBridge()
  let geminiSessionVM = GeminiSessionViewModel()

  private var sendTask: Task<Void, Never>?
  private var voiceObservation: Task<Void, Never>?
  private var voiceTranscripts: [(role: ChatMessageRole, text: String)] = []
  private var lastUserTranscript: String = ""
  private var lastAITranscript: String = ""

  var streamingMode: StreamingMode = .glasses

  // MARK: - Text Mode (sends directly to OpenClaw agent)

  func sendMessage() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !isSending else { return }

    inputText = ""
    isSending = true
    errorMessage = nil

    messages.append(ChatMessage(role: .user, text: text))
    messages.append(ChatMessage(role: .assistant, text: "", status: .streaming))

    sendTask = Task {
      // Check OpenClaw connectivity first
      if openClawBridge.connectionState == .notConfigured {
        await openClawBridge.checkConnection()
      }

      let result = await openClawBridge.delegateTask(task: text)

      switch result {
      case .success(let response):
        updateLastAssistantMessage { msg in
          msg.text = response
          msg.status = .complete
        }
      case .failure(let error):
        updateLastAssistantMessage { msg in
          msg.text = "Failed to reach agent: \(error)"
          msg.status = .error(error)
        }
      }

      isSending = false
    }
  }

  // MARK: - Voice Mode (Gemini Live + OpenClaw dual-agent)

  func startVoiceMode() async {
    guard !isVoiceModeActive else { return }
    isVoiceModeActive = true
    voiceTranscripts = []
    lastUserTranscript = ""
    lastAITranscript = ""

    geminiSessionVM.streamingMode = streamingMode

    voiceObservation = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard !Task.isCancelled, let self else { break }
        self.voiceConnectionState = self.geminiSessionVM.connectionState
        self.isModelSpeaking = self.geminiSessionVM.isModelSpeaking
        self.toolCallStatus = self.geminiSessionVM.toolCallStatus

        let newUser = self.geminiSessionVM.userTranscript
        let newAI = self.geminiSessionVM.aiTranscript

        if !newUser.isEmpty && newUser != self.lastUserTranscript {
          self.lastUserTranscript = newUser
        }
        self.userTranscript = newUser

        if !newAI.isEmpty && newAI != self.lastAITranscript {
          self.lastAITranscript = newAI
        }
        self.aiTranscript = newAI

        // Snapshot transcript pair when turn completes (transcripts cleared)
        if newUser.isEmpty && !self.lastUserTranscript.isEmpty {
          if !self.lastUserTranscript.isEmpty {
            self.voiceTranscripts.append((role: .user, text: self.lastUserTranscript))
          }
          if !self.lastAITranscript.isEmpty {
            self.voiceTranscripts.append((role: .assistant, text: self.lastAITranscript))
          }
          self.lastUserTranscript = ""
          self.lastAITranscript = ""
        }
      }
    }

    await geminiSessionVM.startSession()

    if !geminiSessionVM.isGeminiActive {
      isVoiceModeActive = false
      voiceObservation?.cancel()
      voiceObservation = nil
      errorMessage = geminiSessionVM.errorMessage ?? "Failed to start voice mode"
    }
  }

  func stopVoiceMode() {
    if !lastUserTranscript.isEmpty {
      voiceTranscripts.append((role: .user, text: lastUserTranscript))
    }
    if !lastAITranscript.isEmpty {
      voiceTranscripts.append((role: .assistant, text: lastAITranscript))
    }

    geminiSessionVM.stopSession()
    voiceObservation?.cancel()
    voiceObservation = nil

    for transcript in voiceTranscripts {
      if !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        messages.append(ChatMessage(role: transcript.role, text: transcript.text))
      }
    }

    isVoiceModeActive = false
    voiceConnectionState = .disconnected
    isModelSpeaking = false
    userTranscript = ""
    aiTranscript = ""
    toolCallStatus = .idle
    voiceTranscripts = []
  }

  func sendVideoFrame(_ image: UIImage) {
    if isVoiceModeActive {
      geminiSessionVM.sendVideoFrameIfThrottled(image: image)
    }
  }

  // MARK: - Private

  private func updateLastAssistantMessage(_ update: (inout ChatMessage) -> Void) {
    guard let idx = messages.lastIndex(where: { $0.role == .assistant }) else { return }
    update(&messages[idx])
  }
}
