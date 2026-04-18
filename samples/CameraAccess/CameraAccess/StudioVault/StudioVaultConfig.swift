import Foundation

/// Configuration for the StudioVault HostBroker MCP connection.
/// Reads from existing SettingsManager keys (hostBrokerURL, hostBrokerToken).
struct StudioVaultConfig {
  let host: String
  let port: Int
  let connectionTimeout: TimeInterval
  let useBonjour: Bool

  static let defaultPort = 9470
  static let defaultTimeout: TimeInterval = 10

  /// Build config from current SettingsManager values
  static var current: StudioVaultConfig {
    let settings = SettingsManager.shared
    let url = settings.hostBrokerURL

    let cleanURL = url
      .replacingOccurrences(of: "https://", with: "")
      .replacingOccurrences(of: "http://", with: "")
      .replacingOccurrences(of: "ws://", with: "")
      .replacingOccurrences(of: "wss://", with: "")

    let components = cleanURL.split(separator: ":")
    let host = components.first.map(String.init) ?? ""
    let port = components.count > 1 ? (Int(components[1]) ?? defaultPort) : defaultPort

    let useBonjour = host.isEmpty
      || host.contains("YOUR_MAC")
      || url.contains("PORT_TBD")

    return StudioVaultConfig(
      host: host,
      port: port,
      connectionTimeout: defaultTimeout,
      useBonjour: useBonjour
    )
  }

  /// Whether sufficient configuration exists to attempt connection
  static var isConfigured: Bool {
    let settings = SettingsManager.shared
    let token = settings.hostBrokerToken
    let hasValidToken = !token.isEmpty && token != "YOUR_SCOPED_TOKEN"
    // Bonjour can discover without explicit host
    return hasValidToken
  }

  /// Cached server capabilities from last successful MCP initialize
  /// (stored in-memory only; re-fetched on reconnect)
  @MainActor
  static var cachedCapabilities: [String: Any]?
}
