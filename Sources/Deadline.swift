import Foundation

struct Deadline: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let label: String
    let url: URL?

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                        to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    var badgeColorHint: BadgeColor {
        let d = daysRemaining
        if d < 0 { return .gray }
        if d <= 7 { return .red }
        if d <= 30 { return .orange }
        return .blue
    }

    enum BadgeColor { case red, orange, blue, gray }
}
