import Foundation

@MainActor
final class OuraStore: ObservableObject {
    @Published var readiness: OuraReadiness?
    @Published var error: String?
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            let token = try loadToken()
            readiness = try await fetch(token: token)
            error = nil
        } catch {
            self.error = String(describing: error)
            readiness = nil
        }
    }

    /// Reads OURA_ACCESS_TOKEN from ~/.openclaw/.env (already exists for Tiger).
    private func loadToken() throws -> String {
        let path = ("~/.openclaw/.env" as NSString).expandingTildeInPath
        let text = try String(contentsOfFile: path, encoding: .utf8)
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OURA_ACCESS_TOKEN=") {
                let raw = String(trimmed.dropFirst("OURA_ACCESS_TOKEN=".count))
                // strip surrounding quotes if present
                return raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        throw NSError(domain: "OuraStore", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "OURA_ACCESS_TOKEN missing in \(path)"])
    }

    private func fetch(token: String) async throws -> OuraReadiness? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today)!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var components = URLComponents(string: "https://api.ouraring.com/v2/usercollection/daily_readiness")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: f.string(from: weekAgo)),
            URLQueryItem(name: "end_date", value: f.string(from: today))
        ]
        var req = URLRequest(url: components.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "OuraStore", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        struct Resp: Decodable {
            let data: [Item]
            struct Item: Decodable {
                let day: String
                let score: Int?
                let temperature_deviation: Double?
            }
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        // Most recent day with a non-nil score
        let latest = decoded.data
            .filter { $0.score != nil }
            .sorted { $0.day > $1.day }
            .first
        guard let item = latest, let score = item.score else { return nil }
        return OuraReadiness(score: score, day: item.day, temperatureDeviation: item.temperature_deviation)
    }
}
