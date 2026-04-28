import Foundation

struct JiraTicket: Identifiable, Hashable {
    let id: String       // key, e.g. KAN-42
    let summary: String
    let status: String
    let updated: Date

    var browseURL: URL? {
        URL(string: "https://carlfung.atlassian.net/browse/\(id)")
    }
}
