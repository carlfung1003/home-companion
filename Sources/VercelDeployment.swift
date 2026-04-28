import Foundation

struct VercelDeployment: Identifiable, Hashable {
    let id: String        // uid
    let project: String
    let state: String     // ERROR | BUILDING | QUEUED | CANCELED
    let url: URL?         // inspector URL
    let createdAt: Date

    var isFailing: Bool { state == "ERROR" || state == "CANCELED" }
}
