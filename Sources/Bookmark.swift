import Foundation

struct Bookmark: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let url: URL
    let tag: String?     // optional short label shown on the left, e.g. "OpenAI"
}
