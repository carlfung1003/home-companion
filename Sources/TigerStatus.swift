import Foundation

struct TigerRequest: Identifiable, Hashable {
    let id: URL
    let name: String
    let modified: Date

    var ageDays: Int {
        Calendar.current.dateComponents([.day], from: modified, to: Date()).day ?? 0
    }
}

struct TigerHeartbeat: Hashable {
    let lastEntry: Date?
    let lastEntryName: String?

    var hoursSince: Int? {
        guard let d = lastEntry else { return nil }
        return Calendar.current.dateComponents([.hour], from: d, to: Date()).hour
    }

    enum Status { case fresh, warning, stale, missing }

    var status: Status {
        guard let h = hoursSince else { return .missing }
        if h < 24 { return .fresh }
        if h < 72 { return .warning }
        return .stale
    }
}
