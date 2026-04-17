import Foundation

/// Configuration for the Azure OpenAI Realtime API.
///
/// Mirrors `GeminiConfig` but targets Azure OpenAI's Realtime WebSocket endpoint.
/// The API format is OpenAI's Realtime API (session/response events, function calling)
/// with Azure-specific authentication (api-key header or query string).
///
/// Deployment provenance (StudioVault):
///   vault: _system/logs/CONFIG__2026-04-17__Azure__GPT-Realtime-Deployed__id1776413907.md
///   git:   apptb/StudioVault ab4df92
enum AzureRealtimeConfig {

  // MARK: - Endpoint

  /// Azure OpenAI resource base hostname (dev-vault.openai.azure.com for Konstantin's account).
  /// User-configurable via Settings, falls back to Secrets.swift.
  static var azureResourceBase: String { SettingsManager.shared.azureRealtimeBase }

  /// Deployment name (not the model name) — this is the deployment we created with `az`.
  /// For StudioVault dev: "gpt-realtime-1-5" (effective model version 2025-08-28 until quota opens for 2026-02-23).
  static var deploymentName: String { SettingsManager.shared.azureRealtimeDeployment }

  /// API version string required by Azure's query parameter.
  /// 2025-04-01-preview is the current stable preview for Realtime.
  static let apiVersion = "2025-04-01-preview"

  // MARK: - Audio format

  /// Azure OpenAI Realtime API natively supports PCM16 at 24kHz for both input and output.
  /// (Gemini uses 16kHz input / 24kHz output. We only need resampling on the mic side — output matches.)
  static let inputAudioSampleRate: Double = 24000
  static let outputAudioSampleRate: Double = 24000
  static let audioChannels: UInt32 = 1
  static let audioBitsPerSample: UInt32 = 16

  /// Audio format string Azure expects in session.update messages.
  /// Options per Azure Realtime docs: "pcm16", "g711_ulaw", "g711_alaw"
  static let audioFormat = "pcm16"

  // MARK: - Video (frame cadence — matches Gemini pattern)

  static let videoFrameInterval: TimeInterval = 1.0
  static let videoJPEGQuality: CGFloat = 0.5

  // MARK: - System prompt

  /// Default system instruction for StudioVault-Glasses use case.
  /// Overridden via SettingsManager; falls back to this baseline.
  static var systemInstruction: String { SettingsManager.shared.azureRealtimeSystemPrompt }

  static let defaultSystemInstruction = """
    You are a multimodal assistant running on Meta Ray-Ban glasses plus iPhone, \
    coordinated by Mac Studio as the processing home. You can see through the user's glasses camera, \
    hear their voice, and take real actions via tools.

    ARCHITECTURE CONTEXT:
    - Voice Agent (you) handles sync turns in <2s using memory + semantic-search + vault
    - Action Agent handles multi-turn deep research in background; progress trickles back via tool calls
    - Synthesis Orchestrator produces authoritative outputs (brief / podcast / deck / infographic) when user explicitly requests

    TOOLS:

    1. execute -- Delegates to the Action Agent (vault ops, research, synthesis triggers)
       Accepts a detailed task description with full context.

    2. capture_photo -- Saves the current camera frame as a photo
       Use when user asks to take / capture / snap something.

    3. research_start -- Launch a background research session on a topic
       User can steer mid-flight ("focus on X", "skip Y"); interim findings surface back.

    4. synthesize -- Produce a NotebookLM-parity output from an active research session
       Formats: brief | podcast | deck | infographic | faq | mindmap | interactive

    RULES:
    - ALWAYS speak a brief acknowledgement before calling a slow tool ("On it, pulling up your calendar...")
    - NEVER fabricate a result without calling the tool
    - Keep voice responses concise; save long-form content for synthesize outputs
    - For meeting contexts, respect that Granola is handling transcription — you're providing \
      pre-meeting context capture and live research support, not re-doing what Granola already does
    - Confirm destructive or outbound actions (sending messages, making purchases, deleting) unless clearly urgent
    """

  // MARK: - Credentials

  static var apiKey: String { SettingsManager.shared.azureOpenAIAPIKey }

  static var isConfigured: Bool {
    return !apiKey.isEmpty
      && apiKey != "YOUR_AZURE_OPENAI_API_KEY"
      && !azureResourceBase.isEmpty
      && !deploymentName.isEmpty
  }

  // MARK: - URL construction

  /// Full Realtime WebSocket URL with deployment + api-version query string.
  /// Authentication: api-key goes in a custom header (set on URLRequest),
  /// NOT the URL query, to avoid leaking keys in logs.
  static func websocketURL() -> URL? {
    guard isConfigured else { return nil }

    let urlString = "wss://\(azureResourceBase)/openai/realtime"
      + "?deployment=\(deploymentName)"
      + "&api-version=\(apiVersion)"

    return URL(string: urlString)
  }

  /// Authentication header dictionary for the WebSocket upgrade request.
  /// Must be set on the URLRequest before opening the socket.
  static func authHeaders() -> [String: String] {
    return [
      "api-key": apiKey,
      "User-Agent": "StudioVault-Glasses/0.1 (Matcha fork; iOS)"
    ]
  }

  // MARK: - Model discovery

  /// Useful for settings UI / diagnostic display.
  static func describe() -> String {
    return """
      Azure OpenAI Realtime
      Resource: \(azureResourceBase)
      Deployment: \(deploymentName)
      API version: \(apiVersion)
      Audio: \(audioFormat) @ \(Int(inputAudioSampleRate))Hz mono
      Configured: \(isConfigured)
      """
  }
}
