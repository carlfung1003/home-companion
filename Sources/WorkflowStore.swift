import Foundation

@MainActor
final class WorkflowStore: ObservableObject {
    @Published var runs: [WorkflowRun] = []
    @Published var error: String?
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            runs = try await fetch()
            error = nil
        } catch {
            self.error = String(describing: error)
            runs = []
        }
    }

    /// Uses GitHub's search API via gh CLI to find recent failed runs across
    /// all of user's repos. `gh search` does not support workflow runs, so we
    /// hit the REST search endpoint via `gh api`.
    private func fetch() async throws -> [WorkflowRun] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gh")
        // Last 24 hours of failed runs across all user repos
        let cal = Calendar.current
        let since = cal.date(byAdding: .day, value: -2, to: Date())!
        let iso = ISO8601DateFormatter()
        let q = "user:@me created:>\(iso.string(from: since)) is:failure"
        process.arguments = [
            "api", "-X", "GET",
            "search/issues",
            "-f", "q=\(q)"
        ]
        // ^ search/issues works for PRs/issues but not runs. Use a different approach:
        // call GET /repos/{owner}/{repo}/actions/runs?status=failure for known repos.
        // Hardcoded list of Carl's active repos.
        let repos = [
            "carlfung1003/ai-journey",
            "carlfung1003/pantry-app",
            "carlfung1003/big2-card-game",
            "carlfung1003/fortune-teller",
            "carlfung1003/ssh-portfolio",
            "carlfung1003/trip-planner",
            "carlfung1003/agnusblast",
            "carlfung1003/home-companion"
        ]
        let all = await withTaskGroup(of: [WorkflowRun].self) { group -> [WorkflowRun] in
            for repo in repos {
                group.addTask { [self] in
                    (try? await self.fetchRepo(repo: repo)) ?? []
                }
            }
            var collected: [WorkflowRun] = []
            for await runs in group {
                collected.append(contentsOf: runs)
            }
            return collected
        }
        // Latest failure per repo only — don't spam if a repo has 5 failures
        var seen: Set<String> = []
        return all
            .sorted { $0.updated > $1.updated }
            .filter { run in
                if seen.contains(run.repo) { return false }
                seen.insert(run.repo)
                return true
            }
    }

    private func fetchRepo(repo: String) async throws -> [WorkflowRun] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gh")
        process.arguments = [
            "api",
            "repos/\(repo)/actions/runs?status=failure&per_page=3"
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        struct Resp: Decodable {
            let workflow_runs: [Run]
            struct Run: Decodable {
                let id: Int64
                let name: String
                let head_branch: String?
                let html_url: String
                let updated_at: String
            }
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let iso = ISO8601DateFormatter()
        return decoded.workflow_runs.compactMap { run in
            guard let url = URL(string: run.html_url) else { return nil }
            return WorkflowRun(
                id: "\(repo)#\(run.id)",
                repo: repo.split(separator: "/").last.map(String.init) ?? repo,
                workflow: run.name,
                branch: run.head_branch ?? "?",
                url: url,
                updated: iso.date(from: run.updated_at) ?? Date()
            )
        }
    }
}
