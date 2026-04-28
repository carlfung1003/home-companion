import Foundation

@MainActor
final class TursoStore: ObservableObject {
    @Published var databases: [TursoDatabase] = []
    @Published var error: String?
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            databases = try await fetch()
            error = nil
        } catch {
            self.error = String(describing: error)
            databases = []
        }
    }

    private func fetch() async throws -> [TursoDatabase] {
        let names = try listDatabases()
        var result: [TursoDatabase] = []
        for name in names {
            let usage = try? await fetchUsage(name: name)
            result.append(TursoDatabase(
                id: name,
                name: name,
                storageBytes: usage?.storageBytes,
                storageLimit: 5 * 1024 * 1024 * 1024,  // 5 GB free tier
                rowsRead: usage?.rowsRead,
                rowsReadLimit: 1_000_000_000           // 1B/month free tier
            ))
        }
        return result
    }

    private func listDatabases() throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: NSString(string: "~/.turso/turso").expandingTildeInPath)
        process.arguments = ["db", "list"]
        // GUI apps launched by Launch Services don't inherit shell env; pass HOME
        // explicitly so turso can find ~/.turso/settings.json (auth config).
        let home = NSString(string: "~").expandingTildeInPath
        process.environment = [
            "HOME": home,
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if stderrText.contains("not logged in") {
            throw NSError(domain: "TursoStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Run `turso auth login` first"])
        }
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "TursoStore", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: stderrText.isEmpty ? "turso db list failed" : stderrText])
        }
        let text = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Output format: header row "NAME ... GROUP ... URL", then one row per DB.
        // First column is the DB name.
        let lines = text.split(separator: "\n").dropFirst()  // drop header
        return lines.compactMap { line in
            let first = line.split(separator: " ", omittingEmptySubsequences: true).first
            return first.map(String.init)
        }
    }

    private struct UsageInfo { let storageBytes: Int64; let rowsRead: Int64 }

    private func fetchUsage(name: String) async throws -> UsageInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: NSString(string: "~/.turso/turso").expandingTildeInPath)
        process.arguments = ["db", "show", name]
        let home = NSString(string: "~").expandingTildeInPath
        process.environment = [
            "HOME": home,
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let text = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Parse "Size: X B" / "Size: X KB" / "Size: X MB" lines if present.
        var size: Int64 = 0
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("size:") {
                size = parseSize(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
                break
            }
        }
        return UsageInfo(storageBytes: size, rowsRead: 0)
    }

    private func parseSize(_ s: String) -> Int64 {
        let parts = s.split(separator: " ")
        guard parts.count >= 2, let n = Double(parts[0]) else { return 0 }
        let unit = parts[1].uppercased()
        switch unit {
        case "B":   return Int64(n)
        case "KB":  return Int64(n * 1024)
        case "MB":  return Int64(n * 1024 * 1024)
        case "GB":  return Int64(n * 1024 * 1024 * 1024)
        default:    return Int64(n)
        }
    }
}
