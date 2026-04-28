import Foundation

@MainActor
final class JiraStore: ObservableObject {
    @Published var tickets: [JiraTicket] = []
    @Published var error: String?
    @Published var loading = false

    private let jql = "assignee = currentUser() AND status in (\"In Progress\", \"In Review\") ORDER BY status, updated DESC"

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            tickets = try await fetch()
            error = nil
        } catch {
            self.error = String(describing: error)
            tickets = []
        }
    }

    private func fetch() async throws -> [JiraTicket] {
        let creds = try JiraCredentials.load()
        let url = URL(string: "https://\(creds.host)/rest/api/3/search/jql")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Basic \(creds.basicAuth)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable {
            let jql: String
            let fields: [String]
            let maxResults: Int
        }
        req.httpBody = try JSONEncoder().encode(Body(
            jql: jql,
            fields: ["summary", "status", "updated"],
            maxResults: 20
        ))
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "JiraStore", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        struct SearchResp: Decodable {
            let issues: [Issue]
            struct Issue: Decodable {
                let key: String
                let fields: Fields
            }
            struct Fields: Decodable {
                let summary: String
                let status: Status
                let updated: String
            }
            struct Status: Decodable { let name: String }
        }
        let decoded = try JSONDecoder().decode(SearchResp.self, from: data)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return decoded.issues.map { issue in
            JiraTicket(
                id: issue.key,
                summary: issue.fields.summary,
                status: issue.fields.status.name,
                updated: iso.date(from: issue.fields.updated) ?? Date()
            )
        }
    }
}
