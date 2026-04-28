import Foundation

@MainActor
final class TigerStore: ObservableObject {
    @Published var requests: [TigerRequest] = []
    @Published var heartbeat: TigerHeartbeat = TigerHeartbeat(lastEntry: nil, lastEntryName: nil)
    @Published var error: String?

    private var requestsURL: URL {
        let path = ("~/.openclaw/workspace/requests" as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    // Cache the SSH-derived heartbeat for 5 min so popover opens stay snappy.
    private var heartbeatCache: (value: TigerHeartbeat, fetchedAt: Date)?
    private let heartbeatCacheLifetime: TimeInterval = 300

    private let vpsHost = "root@95.217.17.65"
    private let vpsKeyPath = NSString(string: "~/.oci/oci_vps_key").expandingTildeInPath
    private let vpsMemoryPath = "/root/.openclaw/workspace/memory"

    func refresh() async {
        do {
            requests = try fetchRequests()
            heartbeat = try fetchHeartbeat()
            error = nil
        } catch {
            self.error = String(describing: error)
            requests = []
            heartbeat = TigerHeartbeat(lastEntry: nil, lastEntryName: nil)
        }
    }

    private func fetchRequests() throws -> [TigerRequest] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: requestsURL.path) else { return [] }
        let urls = try fm.contentsOfDirectory(at: requestsURL,
                                              includingPropertiesForKeys: [.contentModificationDateKey],
                                              options: [.skipsHiddenFiles])
        return urls
            .filter { $0.pathExtension == "md" && $0.lastPathComponent != "README.md" }
            .compactMap { url -> TigerRequest? in
                let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                guard let mtime = attrs?.contentModificationDate else { return nil }
                return TigerRequest(
                    id: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    modified: mtime
                )
            }
            .sorted { $0.modified < $1.modified }
    }

    private func fetchHeartbeat() throws -> TigerHeartbeat {
        if let cache = heartbeatCache,
           Date().timeIntervalSince(cache.fetchedAt) < heartbeatCacheLifetime {
            return cache.value
        }
        let result = try sshHeartbeat()
        heartbeatCache = (result, Date())
        return result
    }

    private func sshHeartbeat() throws -> TigerHeartbeat {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        // Newest *.md mtime + filename. xargs format: "<unix-mtime>\t<path>".
        let remoteCmd = "ls -t \(vpsMemoryPath)/*.md 2>/dev/null | head -1 | xargs -I {} stat -c '%Y\\t{}' {}"
        process.arguments = [
            "-o", "ConnectTimeout=5",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-i", vpsKeyPath,
            vpsHost,
            remoteCmd
        ]
        process.environment = [
            "HOME": NSString(string: "~").expandingTildeInPath,
            "PATH": "/usr/bin:/bin"
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let msg = err.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "TigerStore", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "SSH failed" : "SSH: \(msg)"])
        }

        let text = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TigerHeartbeat(lastEntry: nil, lastEntryName: nil)
        }
        let parts = trimmed.split(separator: "\t", maxSplits: 1)
        guard parts.count == 2, let unix = TimeInterval(parts[0]) else {
            return TigerHeartbeat(lastEntry: nil, lastEntryName: nil)
        }
        let path = String(parts[1])
        let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: "")
        return TigerHeartbeat(lastEntry: Date(timeIntervalSince1970: unix), lastEntryName: name)
    }
}
