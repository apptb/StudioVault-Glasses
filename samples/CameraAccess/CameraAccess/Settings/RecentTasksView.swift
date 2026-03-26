import SwiftUI

struct RecentTasksView: View {
  @State private var sessions: [TaskSession] = []
  @State private var isLoading = true
  @State private var errorMessage: String?

  struct TaskSession: Identifiable {
    let id: String
    let timestamp: Date
    let prompt: String
    let result: String
    let messageCount: Int
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView("Loading...")
      } else if let error = errorMessage {
        VStack(spacing: 12) {
          Text("Could not load history")
            .font(.headline)
          Text(error)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
      } else if sessions.isEmpty {
        Text("No recent tasks")
          .foregroundStyle(.secondary)
          .padding()
      } else {
        List(sessions) { session in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(session.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Text("\(session.messageCount) msgs")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Text(session.prompt)
              .font(.subheadline.weight(.medium))
              .lineLimit(2)
            if !session.result.isEmpty {
              Text(session.result)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
    .navigationTitle("Recent Tasks")
    .task { await loadSessions() }
  }

  private func loadSessions() async {
    guard AgentConfig.isConfigured else {
      errorMessage = "Agent not configured"
      isLoading = false
      return
    }

    let userId = SettingsManager.shared.userId
    let baseURL = AgentConfig.baseURL
    guard let url = URL(string: "\(baseURL)/api/agent/sessions?userId=\(userId)&limit=20") else {
      errorMessage = "Invalid URL"
      isLoading = false
      return
    }

    var request = URLRequest(url: url)
    request.setValue(AgentConfig.token, forHTTPHeaderField: "x-api-token")

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        errorMessage = "Server error"
        isLoading = false
        return
      }

      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["sessions"] as? [[String: Any]] else {
        errorMessage = "Invalid response"
        isLoading = false
        return
      }

      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

      sessions = items.compactMap { item in
        guard let key = item["sessionKey"] as? String,
              let prompt = item["prompt"] as? String,
              !prompt.isEmpty else { return nil }
        let ts = item["timestamp"] as? String ?? ""
        let date = formatter.date(from: ts) ?? Date()
        return TaskSession(
          id: key,
          timestamp: date,
          prompt: prompt,
          result: item["result"] as? String ?? "",
          messageCount: item["messageCount"] as? Int ?? 0
        )
      }

      isLoading = false
    } catch {
      errorMessage = error.localizedDescription
      isLoading = false
    }
  }
}
