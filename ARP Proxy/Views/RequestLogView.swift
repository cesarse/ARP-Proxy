import SwiftUI

/// The scrolling request log, newest first.
struct RequestLogView: View {
    let entries: [LogEntry]

    var body: some View {
        if entries.isEmpty {
            Text("No requests yet.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(entries.reversed()) { entry in
                        LogRow(entry: entry)
                    }
                }
            }
        }
    }
}
