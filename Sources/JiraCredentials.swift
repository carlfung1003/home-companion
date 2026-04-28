import Foundation

struct JiraCredentials {
    let email: String
    let token: String
    let host: String

    var basicAuth: String {
        let raw = "\(email):\(token)"
        return Data(raw.utf8).base64EncodedString()
    }

    static func load() throws -> JiraCredentials {
        let path = ("~/.config/home-companion/jira.env" as NSString).expandingTildeInPath
        let text = try String(contentsOfFile: path, encoding: .utf8)
        var dict: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let eq = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
                let val = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                dict[key] = val
            }
        }
        guard let email = dict["JIRA_EMAIL"],
              let token = dict["JIRA_TOKEN"],
              let host = dict["JIRA_HOST"] else {
            throw NSError(domain: "JiraCredentials", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "missing JIRA_EMAIL/TOKEN/HOST in \(path)"])
        }
        return JiraCredentials(email: email, token: token, host: host)
    }
}
