import Foundation

struct TursoDatabase: Identifiable, Hashable {
    let id: String        // db name
    let name: String
    let storageBytes: Int64?
    let storageLimit: Int64    // free tier: 5 GB total across all DBs
    let rowsRead: Int64?
    let rowsReadLimit: Int64   // free tier: 1B reads/month total

    /// Storage % toward the per-DB share if we evenly split (rough heuristic).
    /// Returns nil if no usage data available.
    var storagePercent: Double? {
        guard let s = storageBytes else { return nil }
        return Double(s) / Double(storageLimit) * 100
    }
}
