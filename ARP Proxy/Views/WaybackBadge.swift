import SwiftUI

/// Shown in the main window while Wayback mode is on, so an old-looking web
/// is never a mystery.
struct WaybackBadge: View {
    let date: Date

    var body: some View {
        Label {
            Text("Wayback: \(date, format: .dateTime.day().month(.abbreviated).year())")
        } icon: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .foregroundStyle(.secondary)
        .help("Every page is served from the Internet Archive. Change the date in Settings.")
    }
}

#Preview {
    WaybackBadge(date: ProxySettings.defaultWaybackDate)
        .padding()
}
