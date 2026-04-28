import Foundation

struct PullRequest: Identifiable, Hashable {
    let id: String     // owner/repo#number
    let title: String
    let url: URL
    let repo: String
    let number: Int
}
