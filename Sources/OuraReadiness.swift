import Foundation

struct OuraReadiness: Hashable {
    let score: Int
    let day: String       // "2026-04-27"
    let temperatureDeviation: Double?

    var color: ScoreColor {
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        return .red
    }

    enum ScoreColor { case green, yellow, red }

    var label: String {
        switch color {
        case .green: return "Recovered"
        case .yellow: return "OK"
        case .red:    return "Rest day"
        }
    }
}
