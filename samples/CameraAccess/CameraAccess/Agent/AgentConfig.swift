import Foundation

enum AgentConfig {
  static var baseURL: String { SettingsManager.shared.agentBaseURL }
  static var token: String { SettingsManager.shared.agentToken }

  static var isConfigured: Bool {
    return !baseURL.isEmpty
      && baseURL != "https://YOUR_DEPLOYMENT.vercel.app"
      && !token.isEmpty
      && token != "YOUR_AGENT_TOKEN"
  }
}
