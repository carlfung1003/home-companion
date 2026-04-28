import Foundation

struct CalendarEvent: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool

    var timeLabel: String {
        if isAllDay { return "all-day" }
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "a"
        f.pmSymbol = "p"
        return f.string(from: start).lowercased()
    }
}
