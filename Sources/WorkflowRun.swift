import Foundation

struct WorkflowRun: Identifiable, Hashable {
    let id: String        // owner/repo#runId
    let repo: String
    let workflow: String
    let branch: String
    let url: URL
    let updated: Date
}
