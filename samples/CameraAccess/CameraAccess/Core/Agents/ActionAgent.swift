import Foundation

/// ActionAgent executes tasks asynchronously via the agent backend.
/// It receives AgentTasks (delegated from the VoiceAgent via the coordinator),
/// executes them in the background, and reports results back.
@MainActor
class ActionAgent {
  private let bridge: AgentBridge
  private var inFlightTasks: [String: Task<Void, Never>] = [:]

  var onResult: ((AgentResult) -> Void)?

  init(bridge: AgentBridge) {
    self.bridge = bridge
  }

  /// Fire-and-forget task execution. Results delivered via onResult callback.
  func executeTask(_ task: AgentTask) {
    let taskId = task.id
    let taskName = task.name

    NSLog("[ActionAgent] Executing task: %@ (id: %@)", task.description, taskId)

    let work = Task { @MainActor in
      let result = await self.bridge.delegateTask(task: task.description, toolName: taskName)

      guard !Task.isCancelled else {
        NSLog("[ActionAgent] Task %@ was cancelled", taskId)
        return
      }

      NSLog("[ActionAgent] Result for %@ (id: %@): %@", taskName, taskId, String(describing: result))

      let agentResult = AgentResult.from(taskId: taskId, toolName: taskName, result: result)
      self.onResult?(agentResult)

      self.inFlightTasks.removeValue(forKey: taskId)
    }

    inFlightTasks[taskId] = work
  }

  func cancelTask(id: String) {
    if let task = inFlightTasks[id] {
      NSLog("[ActionAgent] Cancelling task: %@", id)
      task.cancel()
      inFlightTasks.removeValue(forKey: id)
    }
    bridge.lastToolCallStatus = .cancelled(id)
  }

  func cancelAll() {
    for (id, task) in inFlightTasks {
      NSLog("[ActionAgent] Cancelling task: %@", id)
      task.cancel()
    }
    inFlightTasks.removeAll()
  }
}
