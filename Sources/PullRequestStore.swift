import Foundation

@MainActor
final class PullRequestStore: ObservableObject {
    @Published var prs: [PullRequest] = []
    @Published var error: String?
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            prs = try await fetch()
            error = nil
        } catch {
            self.error = String(describing: error)
            prs = []
        }
    }

    private func fetch() async throws -> [PullRequest] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gh")
        process.arguments = [
            "search", "prs",
            "--review-requested=@me",
            "--state=open",
            "--json", "title,url,repository,number"
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        struct GhResult: Decodable {
            let title: String
            let url: String
            let number: Int
            let repository: Repo
            struct Repo: Decodable { let nameWithOwner: String }
        }
        let results = try JSONDecoder().decode([GhResult].self, from: data)
        return results.compactMap { r in
            guard let url = URL(string: r.url) else { return nil }
            return PullRequest(
                id: "\(r.repository.nameWithOwner)#\(r.number)",
                title: r.title,
                url: url,
                repo: r.repository.nameWithOwner,
                number: r.number
            )
        }
    }
}
