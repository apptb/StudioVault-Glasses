import Foundation

/// Agent backend that routes tool calls through the HostBroker MCP connection.
/// Mirrors the pattern of sendViaOpenClaw in AgentBridge.
@MainActor
class StudioVaultMCPBackend {
  static let shared = StudioVaultMCPBackend()

  let client = HostBrokerClient()

  /// Check if the HostBroker connection is alive, connecting if needed.
  /// Returns an AgentConnectionState compatible with AgentBridge.
  func checkConnection() async -> AgentConnectionState {
    guard StudioVaultConfig.isConfigured else {
      return .notConfigured
    }

    if client.isConnected {
      return .connected
    }

    do {
      try await client.connect()
      // Fetch available tools on first connect
      _ = try? await client.listTools()
      return .connected
    } catch {
      NSLog("[StudioVaultMCP] Connection failed: %@", error.localizedDescription)
      return .unreachable(error.localizedDescription)
    }
  }

  /// Execute a task via MCP, compatible with AgentBridge's sendVia* pattern.
  /// The prompt is routed as an "execute" tool call through MCP.
  func sendViaMCP(prompt: String) async throws -> String {
    if !client.isConnected {
      try await client.connect()
      _ = try? await client.listTools()
    }

    // Check if the MCP server has an "execute" tool (general-purpose)
    // If not, try to find the best matching tool
    let toolName = resolveToolName(for: prompt)
    let arguments = resolveArguments(for: prompt, toolName: toolName)

    let result = try await client.callTool(name: toolName, arguments: arguments)

    if let text = result as? String {
      return text
    }

    // Serialize complex results to JSON string for the voice pipeline
    if let dict = result as? [String: Any],
       let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
       let text = String(data: data, encoding: .utf8) {
      return text
    }

    if let array = result as? [[String: Any]],
       let data = try? JSONSerialization.data(withJSONObject: array, options: .prettyPrinted),
       let text = String(data: data, encoding: .utf8) {
      return text
    }

    return String(describing: result)
  }

  /// Direct MCP tool call with explicit name and arguments.
  /// Used when the caller already knows the target MCP tool.
  func callTool(name: String, arguments: [String: Any]) async throws -> String {
    if !client.isConnected {
      try await client.connect()
    }

    let result = try await client.callTool(name: name, arguments: arguments)

    if let text = result as? String {
      return text
    }

    if let dict = result as? [String: Any],
       let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
       let text = String(data: data, encoding: .utf8) {
      return text
    }

    return String(describing: result)
  }

  func disconnect() {
    client.disconnect()
  }

  // MARK: - Tool Name Resolution

  /// Map the incoming prompt to the best MCP tool name.
  /// If the server exposes an "execute" tool, use it (general-purpose agent pattern).
  /// Otherwise, fall back to the first available tool or "execute".
  private func resolveToolName(for prompt: String) -> String {
    let tools = client.availableTools

    // Prefer "execute" tool if available (matches E2B/OpenClaw pattern)
    if tools.contains(where: { $0.name == "execute" }) {
      return "execute"
    }

    // Prefer "run_task" or "agent_execute" variants
    let agentTools = ["run_task", "agent_execute", "process", "run"]
    for name in agentTools {
      if tools.contains(where: { $0.name == name }) {
        return name
      }
    }

    // If only one tool available, use it
    if tools.count == 1 {
      return tools[0].name
    }

    // Default to "execute"
    return "execute"
  }

  /// Build MCP tool arguments from the prompt.
  private func resolveArguments(for prompt: String, toolName: String) -> [String: Any] {
    if let tool = client.availableTools.first(where: { $0.name == toolName }),
       let schema = tool.inputSchema,
       let properties = schema["properties"] as? [String: Any] {
      if properties["task"] != nil {
        return ["task": prompt]
      }
      if properties["prompt"] != nil {
        return ["prompt": prompt]
      }
      if properties["query"] != nil {
        return ["query": prompt]
      }
      if properties["input"] != nil {
        return ["input": prompt]
      }
    }

    // Default: pass as "task" to match the existing agent pattern
    return ["task": prompt]
  }
}
