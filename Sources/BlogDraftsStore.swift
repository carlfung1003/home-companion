import Foundation

@MainActor
final class BlogDraftsStore: ObservableObject {
    @Published var drafts: [BlogDraft] = []
    @Published var error: String?
    @Published var loading = false

    private let staleThresholdDays = 7

    private var inboxURL: URL {
        let path = ("~/.claude/projects/-Users-carlfung/memory/review/blog-drafts" as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            drafts = try fetch()
            error = nil
        } catch {
            self.error = String(describing: error)
            drafts = []
        }
    }

    private func fetch() throws -> [BlogDraft] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: inboxURL.path) else { return [] }
        let urls = try fm.contentsOfDirectory(at: inboxURL,
                                              includingPropertiesForKeys: [.contentModificationDateKey],
                                              options: [.skipsHiddenFiles])
        let candidates = urls.filter { $0.pathExtension == "md" && $0.lastPathComponent != "README.md" }
        let now = Date()
        return candidates.compactMap { url -> BlogDraft? in
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let mtime = attrs?.contentModificationDate else { return nil }
            let ageDays = Calendar.current.dateComponents([.day], from: mtime, to: now).day ?? 0
            guard ageDays >= staleThresholdDays else { return nil }
            return BlogDraft(
                id: url,
                name: url.deletingPathExtension().lastPathComponent,
                modified: mtime
            )
        }
        .sorted { $0.modified < $1.modified }  // oldest first
    }
}
