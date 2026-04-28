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

    private var memoryURL: URL {
        let path = ("~/.openclaw/workspace/memory" as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

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
            .sorted { $0.modified < $1.modified }  // oldest first — most urgent at top
    }

    private func fetchHeartbeat() throws -> TigerHeartbeat {
        let fm = FileManager.default
        guard fm.fileExists(atPath: memoryURL.path) else {
            return TigerHeartbeat(lastEntry: nil, lastEntryName: nil)
        }
        let urls = try fm.contentsOfDirectory(at: memoryURL,
                                              includingPropertiesForKeys: [.contentModificationDateKey],
                                              options: [.skipsHiddenFiles])
        let candidates = urls.filter { $0.pathExtension == "md" }
        var latest: (URL, Date)?
        for url in candidates {
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let mtime = attrs?.contentModificationDate else { continue }
            if let current = latest {
                if mtime > current.1 { latest = (url, mtime) }
            } else {
                latest = (url, mtime)
            }
        }
        if let latest {
            return TigerHeartbeat(
                lastEntry: latest.1,
                lastEntryName: latest.0.deletingPathExtension().lastPathComponent
            )
        }
        return TigerHeartbeat(lastEntry: nil, lastEntryName: nil)
    }
}
