import SwiftUI

/// One monospaced line of the request log.
struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.date, format: .dateTime.hour().minute().second())
                .foregroundStyle(.secondary)
            Text(verbatim: entry.method)
                .fontWeight(.semibold)
                .frame(width: 52, alignment: .leading)
            Text(verbatim: entry.status.map(String.init) ?? "—")
                .foregroundStyle(statusColor)
                .frame(width: 32, alignment: .trailing)
            Text(verbatim: entry.url)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let note = entry.note {
                Text(verbatim: note)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.system(.callout, design: .monospaced))
        .textSelection(.enabled)
    }

    private var statusColor: Color {
        switch entry.status ?? 0 {
        case 200..<300: .green
        case 300..<400: .orange
        case 400...: .red
        default: .secondary
        }
    }
}
