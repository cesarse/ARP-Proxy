import Foundation

/// One row in the request log shown in the main window.
nonisolated struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let date = Date()
    var method: String
    var url: String
    var status: Int?
    var bytes: Int?
    var note: String?
}
