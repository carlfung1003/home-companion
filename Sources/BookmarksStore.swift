import Foundation

@MainActor
final class BookmarksStore: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    @Published var error: String?

    private var filePath: String {
        ("~/.config/home-companion/bookmarks.txt" as NSString).expandingTildeInPath
    }

    func refresh() async {
        do {
            try seedIfMissing()
            bookmarks = try parse()
            error = nil
        } catch {
            self.error = String(describing: error)
            bookmarks = []
        }
    }

    private func seedIfMissing() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: filePath) { return }
        let dir = (filePath as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let seed = """
        # Format: Tag | Label | URL
        # Lines starting with # are ignored. The Tag column is shown in monospace
        # on the left of each row, like a badge.
        OpenAI | Tiger usage  | https://platform.openai.com/usage
        Claude | Chatbot usage | https://console.anthropic.com/settings/usage
        """
        try seed.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func parse() throws -> [Bookmark] {
        let text = try String(contentsOfFile: filePath, encoding: .utf8)
        return text.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { return nil }
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3, let url = URL(string: parts[2]) else { return nil }
            return Bookmark(label: parts[1], url: url, tag: parts[0].isEmpty ? nil : parts[0])
        }
    }
}
