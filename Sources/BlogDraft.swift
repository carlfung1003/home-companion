import Foundation

struct BlogDraft: Identifiable, Hashable {
    let id: URL        // file URL
    let name: String   // display name
    let modified: Date

    var ageDays: Int {
        Calendar.current.dateComponents([.day], from: modified, to: Date()).day ?? 0
    }
}
