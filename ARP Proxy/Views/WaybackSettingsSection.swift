import SwiftUI

struct WaybackSettingsSection: View {
    @Bindable var server: ProxyServer

    /// The archive's crawls begin in 1996.
    private static let earliestDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 1996, month: 1, day: 1, hour: 12))!
    }()

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Browse the past with the Wayback Machine",
                       isOn: $server.settings.waybackEnabled)
                Text("Pages come from the Internet Archive's copy closest to the date below; the guest browser still sees the original addresses.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                DatePicker("Date", selection: $server.settings.waybackDate,
                           in: Self.earliestDate...Date.now, displayedComponents: .date)
                Text("Pages the guest browser has cached may still show the previous date.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .disabled(!server.settings.waybackEnabled)
        } header: {
            Text(verbatim: "Wayback Machine")
        }
    }
}
