import Foundation

enum AgentBackend: String, CaseIterable {
  case e2b = "E2B"
  case openClaw = "OpenClaw"
  case studioVaultMCP = "StudioVaultMCP"   // Phase 2 (StudioVault-Glasses fork): HostBroker-routed vault ops
}

/// Voice provider selector for the StudioVault-Glasses fork.
/// Added to support Azure Realtime alongside the original Gemini Live provider.
enum VoiceProvider: String, CaseIterable {
  case geminiLive = "Gemini Live"
  case azureRealtime = "Azure Realtime"
}

final class SettingsManager {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard

  private enum Key: String {
    case geminiAPIKey
    case geminiSystemPrompt
    case azureOpenAIAPIKey
    case azureRealtimeBase
    case azureRealtimeDeployment
    case azureRealtimeSystemPrompt
    case hostBrokerURL
    case hostBrokerToken
    case voiceProvider
    case agentBackend
    case agentBaseURL
    case agentToken
    case openClawHost
    case openClawPort
    case openClawHookToken
    case openClawGatewayToken
    case webrtcSignalingURL
    case speakerOutputEnabled
    case videoStreamingEnabled
    case proactiveNotificationsEnabled
    case userId
    case agentSessionKey
    case agentSessionCreatedAt
    case fontTheme
  }

  private init() {
    migrateSystemPromptIfNeeded()
  }

  /// One-time migration: replace the old "you have NO ability" system prompt
  /// with the new positive-framing default so Gemini uses tools confidently.
  private func migrateSystemPromptIfNeeded() {
    guard let stored = defaults.string(forKey: Key.geminiSystemPrompt.rawValue),
          stored.contains("You have NO memory, NO storage, and NO ability") else { return }
    defaults.removeObject(forKey: Key.geminiSystemPrompt.rawValue)
    NSLog("[Settings] Migrated system prompt to new default")
  }

  // MARK: - Gemini

  var geminiAPIKey: String {
    get { defaults.string(forKey: Key.geminiAPIKey.rawValue) ?? Secrets.geminiAPIKey }
    set { defaults.set(newValue, forKey: Key.geminiAPIKey.rawValue) }
  }

  var geminiSystemPrompt: String {
    get { defaults.string(forKey: Key.geminiSystemPrompt.rawValue) ?? GeminiConfig.defaultSystemInstruction }
    set { defaults.set(newValue, forKey: Key.geminiSystemPrompt.rawValue) }
  }

  // MARK: - Azure OpenAI Realtime (StudioVault-Glasses fork)

  var azureOpenAIAPIKey: String {
    get { defaults.string(forKey: Key.azureOpenAIAPIKey.rawValue) ?? Secrets.azureOpenAIAPIKey }
    set { defaults.set(newValue, forKey: Key.azureOpenAIAPIKey.rawValue) }
  }

  var azureRealtimeBase: String {
    get { defaults.string(forKey: Key.azureRealtimeBase.rawValue) ?? Secrets.azureRealtimeBase }
    set { defaults.set(newValue, forKey: Key.azureRealtimeBase.rawValue) }
  }

  var azureRealtimeDeployment: String {
    get { defaults.string(forKey: Key.azureRealtimeDeployment.rawValue) ?? Secrets.azureRealtimeDeployment }
    set { defaults.set(newValue, forKey: Key.azureRealtimeDeployment.rawValue) }
  }

  var azureRealtimeSystemPrompt: String {
    get { defaults.string(forKey: Key.azureRealtimeSystemPrompt.rawValue) ?? AzureRealtimeConfig.defaultSystemInstruction }
    set { defaults.set(newValue, forKey: Key.azureRealtimeSystemPrompt.rawValue) }
  }

  // MARK: - Voice provider selector (StudioVault-Glasses fork)

  var voiceProvider: VoiceProvider {
    get {
      guard let raw = defaults.string(forKey: Key.voiceProvider.rawValue),
            let provider = VoiceProvider(rawValue: raw) else { return .geminiLive }
      return provider
    }
    set { defaults.set(newValue.rawValue, forKey: Key.voiceProvider.rawValue) }
  }

  // MARK: - HostBroker (StudioVault-Glasses fork, Phase 2)

  var hostBrokerURL: String {
    get { defaults.string(forKey: Key.hostBrokerURL.rawValue) ?? Secrets.hostBrokerURL }
    set { defaults.set(newValue, forKey: Key.hostBrokerURL.rawValue) }
  }

  var hostBrokerToken: String {
    get { defaults.string(forKey: Key.hostBrokerToken.rawValue) ?? Secrets.hostBrokerToken }
    set { defaults.set(newValue, forKey: Key.hostBrokerToken.rawValue) }
  }

  // MARK: - Agent

  var agentBackend: AgentBackend {
    get {
      guard let raw = defaults.string(forKey: Key.agentBackend.rawValue),
            let backend = AgentBackend(rawValue: raw) else { return .e2b }
      return backend
    }
    set { defaults.set(newValue.rawValue, forKey: Key.agentBackend.rawValue) }
  }

  // E2B settings
  var agentBaseURL: String {
    get { defaults.string(forKey: Key.agentBaseURL.rawValue) ?? Secrets.agentBaseURL }
    set { defaults.set(newValue, forKey: Key.agentBaseURL.rawValue) }
  }

  var agentToken: String {
    get { defaults.string(forKey: Key.agentToken.rawValue) ?? Secrets.agentToken }
    set { defaults.set(newValue, forKey: Key.agentToken.rawValue) }
  }

  // OpenClaw settings
  var openClawHost: String {
    get { defaults.string(forKey: Key.openClawHost.rawValue) ?? Secrets.openClawHost }
    set { defaults.set(newValue, forKey: Key.openClawHost.rawValue) }
  }

  var openClawPort: Int {
    get {
      let stored = defaults.integer(forKey: Key.openClawPort.rawValue)
      return stored != 0 ? stored : Secrets.openClawPort
    }
    set { defaults.set(newValue, forKey: Key.openClawPort.rawValue) }
  }

  var openClawHookToken: String {
    get { defaults.string(forKey: Key.openClawHookToken.rawValue) ?? Secrets.openClawHookToken }
    set { defaults.set(newValue, forKey: Key.openClawHookToken.rawValue) }
  }

  var openClawGatewayToken: String {
    get { defaults.string(forKey: Key.openClawGatewayToken.rawValue) ?? Secrets.openClawGatewayToken }
    set { defaults.set(newValue, forKey: Key.openClawGatewayToken.rawValue) }
  }

  // MARK: - WebRTC

  var webrtcSignalingURL: String {
    get { defaults.string(forKey: Key.webrtcSignalingURL.rawValue) ?? Secrets.webrtcSignalingURL }
    set { defaults.set(newValue, forKey: Key.webrtcSignalingURL.rawValue) }
  }

  // MARK: - Audio

  var speakerOutputEnabled: Bool {
    get { defaults.bool(forKey: Key.speakerOutputEnabled.rawValue) }
    set { defaults.set(newValue, forKey: Key.speakerOutputEnabled.rawValue) }
  }

  var videoStreamingEnabled: Bool {
    get {
      // Default to true if never set
      if defaults.object(forKey: Key.videoStreamingEnabled.rawValue) == nil { return true }
      return defaults.bool(forKey: Key.videoStreamingEnabled.rawValue)
    }
    set { defaults.set(newValue, forKey: Key.videoStreamingEnabled.rawValue) }
  }

  var proactiveNotificationsEnabled: Bool {
    get { defaults.bool(forKey: Key.proactiveNotificationsEnabled.rawValue) }
    set { defaults.set(newValue, forKey: Key.proactiveNotificationsEnabled.rawValue) }
  }

  // MARK: - User Identity (permanent, survives reset)

  var userId: String {
    if let id = defaults.string(forKey: Key.userId.rawValue) { return id }
    let id = UUID().uuidString
    defaults.set(id, forKey: Key.userId.rawValue)
    return id
  }

  // MARK: - Font Theme

  var fontTheme: String {
    get { defaults.string(forKey: Key.fontTheme.rawValue) ?? FontTheme.tiempos.rawValue }
    set { defaults.set(newValue, forKey: Key.fontTheme.rawValue) }
  }

  // MARK: - Session Persistence

  var agentSessionKey: String? {
    get { defaults.string(forKey: Key.agentSessionKey.rawValue) }
    set { defaults.set(newValue, forKey: Key.agentSessionKey.rawValue) }
  }

  var agentSessionCreatedAt: TimeInterval {
    get { defaults.double(forKey: Key.agentSessionCreatedAt.rawValue) }
    set { defaults.set(newValue, forKey: Key.agentSessionCreatedAt.rawValue) }
  }

  // MARK: - Reset

  func resetAll() {
    for key in [Key.geminiAPIKey, .geminiSystemPrompt, .agentBackend,
                .agentBaseURL, .agentToken,
                .openClawHost, .openClawPort, .openClawHookToken, .openClawGatewayToken,
                .azureOpenAIAPIKey, .azureRealtimeBase, .azureRealtimeDeployment, .azureRealtimeSystemPrompt,
                .hostBrokerURL, .hostBrokerToken, .voiceProvider,
                .webrtcSignalingURL, .speakerOutputEnabled, .videoStreamingEnabled, .proactiveNotificationsEnabled,
                .agentSessionKey, .agentSessionCreatedAt] {
      defaults.removeObject(forKey: key.rawValue)
    }
  }
}
