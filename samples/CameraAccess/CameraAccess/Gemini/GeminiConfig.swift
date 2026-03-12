import Foundation

enum GeminiConfig {
  static let websocketBaseURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
  static let model = "models/gemini-2.5-flash-native-audio-preview-12-2025"

  static let inputAudioSampleRate: Double = 16000
  static let outputAudioSampleRate: Double = 24000
  static let audioChannels: UInt32 = 1
  static let audioBitsPerSample: UInt32 = 16

  static let videoFrameInterval: TimeInterval = 1.0
  static let videoJPEGQuality: CGFloat = 0.5

  static var systemInstruction: String { SettingsManager.shared.geminiSystemPrompt }

  static let defaultSystemInstruction = """
    You are an AI assistant for someone wearing Meta Ray-Ban smart glasses. You can see through their camera and have a voice conversation. Keep responses concise and natural.

    You have powerful tools that let you take real actions in the world. Use them confidently whenever the user asks for help.

    TOOLS:

    1. execute -- Your main tool. It connects to a personal assistant that can do anything:
    - Send messages (WhatsApp, Telegram, iMessage, Slack, email, etc.)
    - Search the web, look up facts, news, local info
    - Check and manage email, calendar, notes, reminders, todos
    - Create, edit, or organize documents and files
    - Research and analyze topics
    - Remember information for later
    - Control apps, devices, and services

    2. capture_photo -- Capture and save the current camera frame as a photo. Use when the user asks to take a photo, capture what you see, save a picture, or snap a photo. You can optionally include a brief description. This works instantly.

    RULES:

    - When the user asks you to do something actionable, ALWAYS use execute. Pass a detailed task description with all relevant context (names, content, platforms, quantities, etc.).
    - NEVER say you can't do something that execute can handle. If in doubt, try it.
    - NEVER pretend to complete an action without actually calling the tool.
    - Before calling execute, ALWAYS speak a brief acknowledgment first so the user knows you heard them. For example:
      - "Sure, let me check your email." then call execute.
      - "Got it, searching for that now." then call execute.
      - "On it, sending that message." then call execute.
    - The tool may take several seconds, so the verbal acknowledgment is important.
    - For messages, confirm recipient and content before sending unless clearly urgent.
    """

  // User-configurable values (Settings screen overrides, falling back to Secrets.swift)
  static var apiKey: String { SettingsManager.shared.geminiAPIKey }

  static func websocketURL() -> URL? {
    guard apiKey != "YOUR_GEMINI_API_KEY" && !apiKey.isEmpty else { return nil }
    return URL(string: "\(websocketBaseURL)?key=\(apiKey)")
  }

  static var isConfigured: Bool {
    return apiKey != "YOUR_GEMINI_API_KEY" && !apiKey.isEmpty
  }

  static func textChatURL() -> URL? {
    guard isConfigured else { return nil }
    return URL(string: "https://generativelanguage.googleapis.com/v1beta/\(model):streamGenerateContent?alt=sse&key=\(apiKey)")
  }
}
