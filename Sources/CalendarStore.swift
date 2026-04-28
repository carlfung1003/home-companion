import Foundation

@MainActor
final class CalendarStore: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var error: String?
    @Published var loading = false

    private let calendarName = "carlfung1003@gmail.com"

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            events = try await runGcalcli()
            error = nil
        } catch {
            self.error = String(describing: error)
            events = []
        }
    }

    private func runGcalcli() async throws -> [CalendarEvent] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gcalcli")
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        process.arguments = [
            "--calendar", calendarName,
            "agenda", "--tsv",
            f.string(from: now), f.string(from: end)
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return parse(tsv: text)
    }

    private func parse(tsv: String) -> [CalendarEvent] {
        let lines = tsv.split(separator: "\n").dropFirst()  // drop header
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        let dateTime = DateFormatter()
        dateTime.dateFormat = "yyyy-MM-dd HH:mm"
        return lines.compactMap { line in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 5 else { return nil }
            let (sd, st, ed, et, title) = (cols[0], cols[1], cols[2], cols[3], cols[4])
            let isAllDay = st.isEmpty
            guard
                let start = isAllDay ? dateOnly.date(from: sd) : dateTime.date(from: "\(sd) \(st)"),
                let end = isAllDay ? dateOnly.date(from: ed) : dateTime.date(from: "\(ed) \(et)")
            else { return nil }
            return CalendarEvent(title: title, start: start, end: end, isAllDay: isAllDay)
        }
    }
}
