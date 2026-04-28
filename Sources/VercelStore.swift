import Foundation

@MainActor
final class VercelStore: ObservableObject {
    @Published var deployments: [VercelDeployment] = []
    @Published var error: String?
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            let token = try loadToken()
            deployments = try await fetch(token: token)
            error = nil
        } catch {
            self.error = String(describing: error)
            deployments = []
        }
    }

    private func loadToken() throws -> String {
        let path = ("~/.config/home-companion/vercel.env" as NSString).expandingTildeInPath
        let text = try String(contentsOfFile: path, encoding: .utf8)
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("VERCEL_TOKEN=") {
                return String(trimmed.dropFirst("VERCEL_TOKEN=".count))
            }
        }
        throw NSError(domain: "VercelStore", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "VERCEL_TOKEN missing in \(path)"])
    }

    private func fetch(token: String) async throws -> [VercelDeployment] {
        var components = URLComponents(string: "https://api.vercel.com/v6/deployments")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "target", value: "production")
        ]
        var req = URLRequest(url: components.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "VercelStore", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        struct Resp: Decodable {
            let deployments: [Dep]
            struct Dep: Decodable {
                let uid: String
                let name: String
                let state: String?
                let inspectorUrl: String?
                let created: TimeInterval
            }
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let interesting: Set<String> = ["ERROR", "BUILDING", "QUEUED"]
        // For each project, take the absolute latest deploy (not just latest
        // interesting one). Then surface only projects whose latest is in
        // a bad/in-flight state. Vercel returns newest-first.
        var latestPerProject: [String: Resp.Dep] = [:]
        for dep in decoded.deployments where latestPerProject[dep.name] == nil {
            latestPerProject[dep.name] = dep
        }
        return latestPerProject.values
            .filter { interesting.contains($0.state ?? "") }
            .sorted { $0.created > $1.created }
            .map { d in
                VercelDeployment(
                    id: d.uid,
                    project: d.name,
                    state: d.state ?? "?",
                    url: d.inspectorUrl.flatMap(URL.init(string:)),
                    createdAt: Date(timeIntervalSince1970: d.created / 1000)
                )
            }
    }
}
