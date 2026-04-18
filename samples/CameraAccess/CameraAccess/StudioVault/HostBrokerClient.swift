import Foundation
import Network

// MARK: - Supporting Types

enum HostBrokerConnectionState: Equatable {
  case disconnected
  case discovering
  case connecting
  case connected
  case error(String)
}

enum HostBrokerError: LocalizedError {
  case notConnected
  case discoveryFailed(String)
  case connectionTimeout
  case invalidURL
  case webSocketError(String)
  case jsonRPCError(Int, String)
  case invalidResponse
  case initializeFailed(String)

  var errorDescription: String? {
    switch self {
    case .notConnected: return "Not connected to HostBroker"
    case .discoveryFailed(let msg): return "Discovery failed: \(msg)"
    case .connectionTimeout: return "Connection timed out"
    case .invalidURL: return "Invalid HostBroker URL"
    case .webSocketError(let msg): return "WebSocket error: \(msg)"
    case .jsonRPCError(let code, let msg): return "MCP error \(code): \(msg)"
    case .invalidResponse: return "Invalid response from HostBroker"
    case .initializeFailed(let msg): return "MCP initialize failed: \(msg)"
    }
  }
}

struct MCPTool: Equatable {
  let name: String
  let description: String
  let inputSchema: [String: Any]?

  static func == (lhs: MCPTool, rhs: MCPTool) -> Bool {
    lhs.name == rhs.name && lhs.description == rhs.description
  }
}

struct MCPResource: Equatable {
  let uri: String
  let name: String
  let description: String?
  let mimeType: String?
}

// MARK: - HostBrokerClient

@MainActor
class HostBrokerClient: ObservableObject {
  @Published var connectionState: HostBrokerConnectionState = .disconnected
  @Published var availableTools: [MCPTool] = []

  private var webSocketTask: URLSessionWebSocketTask?
  private var urlSession: URLSession?
  private var nextRequestId: Int = 1
  private var pendingRequests: [Int: CheckedContinuation<[String: Any], Error>] = [:]
  private var heartbeatTask: Task<Void, Never>?
  private var receiveTask: Task<Void, Never>?
  private var shouldReconnect = false
  private var reconnectDelay: TimeInterval = 2
  private let maxReconnectDelay: TimeInterval = 30

  // Bonjour discovery
  private var browser: NWBrowser?
  private var discoveredHost: String?
  private var discoveredPort: UInt16?

  // MCP session state
  private var serverCapabilities: [String: Any]?
  private var isInitialized = false

  var isConnected: Bool {
    connectionState == .connected && isInitialized
  }

  // MARK: - Public API

  /// Connect to the HostBroker, using Bonjour discovery or manual config
  func connect() async throws {
    let config = StudioVaultConfig.current
    shouldReconnect = true
    reconnectDelay = 2

    if config.useBonjour {
      connectionState = .discovering
      NSLog("[HostBroker] Starting Bonjour discovery for _studiovault._tcp")
      let (host, port) = try await discoverHost()
      discoveredHost = host
      discoveredPort = port
      try await establishConnection(host: host, port: Int(port))
    } else {
      guard !config.host.isEmpty else {
        throw HostBrokerError.invalidURL
      }
      try await establishConnection(host: config.host, port: config.port)
    }
  }

  func disconnect() {
    shouldReconnect = false
    isInitialized = false
    heartbeatTask?.cancel()
    heartbeatTask = nil
    receiveTask?.cancel()
    receiveTask = nil
    browser?.cancel()
    browser = nil
    webSocketTask?.cancel(with: .normalClosure, reason: nil)
    webSocketTask = nil
    urlSession?.invalidateAndCancel()
    urlSession = nil
    cancelAllPending(error: HostBrokerError.notConnected)
    connectionState = .disconnected
    NSLog("[HostBroker] Disconnected")
  }

  /// MCP initialize handshake (called automatically during connect)
  func initialize() async throws {
    let params: [String: Any] = [
      "protocolVersion": "2024-11-05",
      "capabilities": [
        "roots": ["listChanged": true]
      ],
      "clientInfo": [
        "name": "StudioVault-Glasses",
        "version": "1.0.0"
      ]
    ]

    let result = try await sendRequest(method: "initialize", params: params)

    guard let capabilities = result["capabilities"] as? [String: Any] else {
      throw HostBrokerError.initializeFailed("No capabilities in response")
    }

    serverCapabilities = capabilities
    StudioVaultConfig.cachedCapabilities = capabilities
    isInitialized = true

    // Send initialized notification (no response expected)
    sendNotification(method: "notifications/initialized", params: [:])

    NSLog("[HostBroker] MCP initialized. Capabilities: %@",
          String(describing: capabilities.keys.sorted()))
  }

  /// List available MCP tools
  func listTools() async throws -> [MCPTool] {
    guard isConnected else { throw HostBrokerError.notConnected }

    let result = try await sendRequest(method: "tools/list", params: [:])

    guard let toolsArray = result["tools"] as? [[String: Any]] else {
      return []
    }

    let tools = toolsArray.compactMap { dict -> MCPTool? in
      guard let name = dict["name"] as? String,
            let description = dict["description"] as? String else { return nil }
      return MCPTool(
        name: name,
        description: description,
        inputSchema: dict["inputSchema"] as? [String: Any]
      )
    }

    availableTools = tools
    NSLog("[HostBroker] Listed %d tools", tools.count)
    return tools
  }

  /// Call an MCP tool by name with arguments
  func callTool(name: String, arguments: [String: Any]) async throws -> Any {
    guard isConnected else { throw HostBrokerError.notConnected }

    let params: [String: Any] = [
      "name": name,
      "arguments": arguments
    ]

    NSLog("[HostBroker] Calling tool: %@ args: %@", name, String(describing: arguments).prefix(200))

    let result = try await sendRequest(method: "tools/call", params: params)

    // MCP tools/call returns { content: [{ type, text }], isError? }
    if let isError = result["isError"] as? Bool, isError {
      let errorTexts = (result["content"] as? [[String: Any]])?
        .compactMap { $0["text"] as? String }
        .joined(separator: "\n") ?? "Unknown MCP tool error"
      throw HostBrokerError.jsonRPCError(-1, errorTexts)
    }

    if let content = result["content"] as? [[String: Any]] {
      let texts = content.compactMap { item -> String? in
        guard item["type"] as? String == "text" else { return nil }
        return item["text"] as? String
      }
      if texts.count == 1 { return texts[0] }
      if !texts.isEmpty { return texts.joined(separator: "\n") }
      return content
    }

    return result
  }

  /// List available MCP resources
  func listResources() async throws -> [MCPResource] {
    guard isConnected else { throw HostBrokerError.notConnected }

    let result = try await sendRequest(method: "resources/list", params: [:])

    guard let resourcesArray = result["resources"] as? [[String: Any]] else {
      return []
    }

    return resourcesArray.compactMap { dict -> MCPResource? in
      guard let uri = dict["uri"] as? String,
            let name = dict["name"] as? String else { return nil }
      return MCPResource(
        uri: uri,
        name: name,
        description: dict["description"] as? String,
        mimeType: dict["mimeType"] as? String
      )
    }
  }

  // MARK: - Bonjour Discovery

  private func discoverHost() async throws -> (String, UInt16) {
    try await withCheckedThrowingContinuation { continuation in
      let descriptor = NWBrowser.Descriptor.bonjour(type: "_studiovault._tcp", domain: nil)
      let browser = NWBrowser(for: descriptor, using: .tcp)
      self.browser = browser

      var didResume = false

      browser.stateUpdateHandler = { state in
        switch state {
        case .failed(let error):
          guard !didResume else { return }
          didResume = true
          continuation.resume(throwing: HostBrokerError.discoveryFailed(error.localizedDescription))
        default:
          break
        }
      }

      browser.browseResultsChangedHandler = { [weak self] results, _ in
        guard !didResume, let result = results.first else { return }
        didResume = true
        browser.cancel()

        Task { @MainActor [weak self] in
          self?.browser = nil
          do {
            let resolved = try await self?.resolveEndpoint(result.endpoint)
            guard let resolved else {
              continuation.resume(throwing: HostBrokerError.discoveryFailed("Client deallocated"))
              return
            }
            NSLog("[HostBroker] Discovered host: %@:%d", resolved.0, resolved.1)
            continuation.resume(returning: resolved)
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }

      browser.start(queue: .main)

      // Discovery timeout
      let timeout = StudioVaultConfig.current.connectionTimeout
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
        guard !didResume else { return }
        didResume = true
        browser.cancel()
        self?.browser = nil
        continuation.resume(throwing: HostBrokerError.connectionTimeout)
      }
    }
  }

  nonisolated private func resolveEndpoint(_ endpoint: NWEndpoint) async throws -> (String, UInt16) {
    try await withCheckedThrowingContinuation { continuation in
      let connection = NWConnection(to: endpoint, using: .tcp)
      var didResume = false

      connection.stateUpdateHandler = { state in
        guard !didResume else { return }
        switch state {
        case .ready:
          if let path = connection.currentPath,
             let remote = path.remoteEndpoint,
             case let .hostPort(host, port) = remote {
            didResume = true
            connection.cancel()
            continuation.resume(returning: ("\(host)", port.rawValue))
          }
        case .failed(let error):
          didResume = true
          connection.cancel()
          continuation.resume(throwing: HostBrokerError.discoveryFailed(error.localizedDescription))
        case .cancelled:
          if !didResume {
            didResume = true
            continuation.resume(throwing: HostBrokerError.discoveryFailed("Connection cancelled"))
          }
        default:
          break
        }
      }

      connection.start(queue: .main)

      DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        guard !didResume else { return }
        didResume = true
        connection.cancel()
        continuation.resume(throwing: HostBrokerError.connectionTimeout)
      }
    }
  }

  // MARK: - WebSocket Connection

  private func establishConnection(host: String, port: Int) async throws {
    let cleanHost = host
      .replacingOccurrences(of: "http://", with: "")
      .replacingOccurrences(of: "https://", with: "")
      .replacingOccurrences(of: "ws://", with: "")
      .replacingOccurrences(of: "wss://", with: "")

    guard let url = URL(string: "ws://\(cleanHost):\(port)/mcp") else {
      throw HostBrokerError.invalidURL
    }

    connectionState = .connecting

    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = StudioVaultConfig.current.connectionTimeout
    urlSession = URLSession(configuration: config)

    var request = URLRequest(url: url)
    let token = SettingsManager.shared.hostBrokerToken
    if !token.isEmpty && token != "YOUR_SCOPED_TOKEN" {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    webSocketTask = urlSession?.webSocketTask(with: request)
    webSocketTask?.resume()

    NSLog("[HostBroker] Connecting to %@", url.absoluteString)

    startReceiving()

    // MCP initialize handshake
    try await initialize()

    connectionState = .connected
    reconnectDelay = 2

    startHeartbeat()

    NSLog("[HostBroker] Connected and initialized at %@", url.absoluteString)
  }

  // MARK: - JSON-RPC 2.0

  private func sendRequest(method: String, params: [String: Any]) async throws -> [String: Any] {
    guard let ws = webSocketTask else {
      throw HostBrokerError.notConnected
    }

    let id = nextRequestId
    nextRequestId += 1

    let message: [String: Any] = [
      "jsonrpc": "2.0",
      "id": id,
      "method": method,
      "params": params
    ]

    let data = try JSONSerialization.data(withJSONObject: message)
    guard let string = String(data: data, encoding: .utf8) else {
      throw HostBrokerError.invalidResponse
    }

    return try await withCheckedThrowingContinuation { continuation in
      pendingRequests[id] = continuation

      ws.send(.string(string)) { [weak self] error in
        if let error {
          Task { @MainActor [weak self] in
            if let cont = self?.pendingRequests.removeValue(forKey: id) {
              cont.resume(throwing: HostBrokerError.webSocketError(error.localizedDescription))
            }
          }
        }
      }

      // Request timeout
      let timeout = StudioVaultConfig.current.connectionTimeout
      Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        if let cont = self?.pendingRequests.removeValue(forKey: id) {
          cont.resume(throwing: HostBrokerError.connectionTimeout)
        }
      }
    }
  }

  private func sendNotification(method: String, params: [String: Any]) {
    guard let ws = webSocketTask else { return }

    let message: [String: Any] = [
      "jsonrpc": "2.0",
      "method": method,
      "params": params
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: message),
          let string = String(data: data, encoding: .utf8) else { return }

    ws.send(.string(string)) { error in
      if let error {
        NSLog("[HostBroker] Notification send error: %@", error.localizedDescription)
      }
    }
  }

  // MARK: - WebSocket Receive Loop

  private func startReceiving() {
    receiveTask?.cancel()
    receiveTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        guard let self, let ws = self.webSocketTask else { break }

        do {
          let message = try await ws.receive()
          self.handleMessage(message)
        } catch {
          if Task.isCancelled { break }
          NSLog("[HostBroker] Receive error: %@", error.localizedDescription)
          self.handleDisconnect()
          break
        }
      }
    }
  }

  private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
    let text: String
    switch message {
    case .string(let str):
      text = str
    case .data(let data):
      guard let str = String(data: data, encoding: .utf8) else { return }
      text = str
    @unknown default:
      return
    }

    guard let data = text.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      NSLog("[HostBroker] Invalid JSON: %@", String(text.prefix(200)))
      return
    }

    // JSON-RPC response (has "id")
    if let id = json["id"] as? Int {
      handleResponse(id: id, json: json)
      return
    }

    // JSON-RPC notification (no "id", has "method")
    if let method = json["method"] as? String {
      handleServerNotification(
        method: method,
        params: json["params"] as? [String: Any] ?? [:]
      )
    }
  }

  private func handleResponse(id: Int, json: [String: Any]) {
    guard let continuation = pendingRequests.removeValue(forKey: id) else {
      NSLog("[HostBroker] No pending request for id %d", id)
      return
    }

    if let error = json["error"] as? [String: Any] {
      let code = error["code"] as? Int ?? -1
      let message = error["message"] as? String ?? "Unknown error"
      continuation.resume(throwing: HostBrokerError.jsonRPCError(code, message))
      return
    }

    let result = json["result"] as? [String: Any] ?? [:]
    continuation.resume(returning: result)
  }

  private func handleServerNotification(method: String, params: [String: Any]) {
    NSLog("[HostBroker] Server notification: %@ params: %@",
          method, String(describing: params).prefix(200))
    // Future: handle tools/list_changed, resources/list_changed, etc.
  }

  // MARK: - Heartbeat

  private func startHeartbeat() {
    heartbeatTask?.cancel()
    heartbeatTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
        guard !Task.isCancelled, let self, let ws = self.webSocketTask else { break }

        ws.sendPing { error in
          if let error {
            NSLog("[HostBroker] Ping failed: %@", error.localizedDescription)
            Task { @MainActor [weak self] in
              self?.handleDisconnect()
            }
          }
        }
      }
    }
  }

  // MARK: - Reconnect

  private func handleDisconnect() {
    guard connectionState == .connected || connectionState == .connecting else { return }

    isInitialized = false
    connectionState = .error("Disconnected")
    cancelAllPending(error: HostBrokerError.notConnected)
    heartbeatTask?.cancel()
    receiveTask?.cancel()
    webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
    webSocketTask = nil

    NSLog("[HostBroker] Connection lost")

    guard shouldReconnect else { return }
    scheduleReconnect()
  }

  private func scheduleReconnect() {
    NSLog("[HostBroker] Reconnecting in %.0fs", reconnectDelay)
    let delay = reconnectDelay
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard let self, self.shouldReconnect else { return }
      self.reconnectDelay = min(self.reconnectDelay * 2, self.maxReconnectDelay)

      do {
        if let host = self.discoveredHost, let port = self.discoveredPort {
          try await self.establishConnection(host: host, port: Int(port))
        } else {
          try await self.connect()
        }
      } catch {
        NSLog("[HostBroker] Reconnect failed: %@", error.localizedDescription)
        self.connectionState = .error(error.localizedDescription)
        self.scheduleReconnect()
      }
    }
  }

  private func cancelAllPending(error: Error) {
    let pending = pendingRequests
    pendingRequests.removeAll()
    for (_, continuation) in pending {
      continuation.resume(throwing: error)
    }
  }
}
