import Foundation

@MainActor
final class DeadlineStore: ObservableObject {
    @Published var deadlines: [Deadline] = []
    @Published var error: String?
    @Published var loading = false

    private var filePath: String {
        ("~/.config/home-companion/deadlines.txt" as NSString).expandingTildeInPath
    }

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            try seedIfMissing()
            deadlines = try parse()
            error = nil
        } catch {
            self.error = String(describing: error)
            deadlines = []
        }
    }

    private func seedIfMissing() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: filePath) { return }
        let dir = (filePath as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let seed = """
        # Format: YYYY-MM-DD | Label | optional URL
        # Lines starting with # are ignored.
        2026-04-30 | inKind $50 credit expires
        2026-06-01 | Marriott Bonvoy $1600 spend deadline
        2026-11-01 | CA property tax due (1st installment)
        2026-12-10 | CA property tax delinquent (1st installment)
        2027-02-01 | CA property tax due (2nd installment)
        """
        try seed.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func parse() throws -> [Deadline] {
        let text = try String(contentsOfFile: filePath, encoding: .utf8)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return text.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { return nil }
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2, let date = f.date(from: parts[0]) else { return nil }
            let url = parts.count >= 3 ? URL(string: parts[2]) : nil
            return Deadline(date: date, label: parts[1], url: url)
        }
        .sorted { $0.date < $1.date }
    }
}
