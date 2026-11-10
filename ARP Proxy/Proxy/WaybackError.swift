import Foundation

/// Why the Wayback Machine could not supply a page, each with the page the
/// vintage browser is shown instead.
nonisolated enum WaybackError: Error, Equatable {
    /// The archive has no capture of the URL — or is not allowed to show one.
    case notArchived
    /// The archive is throttling this client.
    case rateLimited
    /// The archive itself failed, with this status.
    case unavailable(status: Int)
    /// Capture after capture redirected without settling on a page.
    case tooManyRedirects

    var logNote: String {
        switch self {
        case .notArchived: "wayback: not archived"
        case .rateLimited: "wayback: rate limited"
        case .unavailable(let status): "wayback: archive answered \(status)"
        case .tooManyRedirects: "wayback: too many redirects"
        }
    }

    /// The page for the guest. Plain English and ASCII, like every error
    /// page: it is read by a browser with no notion of the host's language.
    func errorPage(for original: URL, near date: Date) -> ErrorPage {
        switch self {
        case .notArchived:
            ErrorPage(status: 404, title: "Not in the Wayback Machine",
                      message: "The Internet Archive has no copy of \(original.absoluteString) "
                          + "from around \(Self.spelledOut(date)).")
        case .rateLimited:
            ErrorPage(status: 503, title: "Wayback Machine Busy",
                      message: "The Internet Archive is limiting how fast pages can be fetched. "
                          + "Wait a minute, then reload.")
        case .unavailable(let status):
            ErrorPage(status: 502, title: "Wayback Machine Unavailable",
                      message: "web.archive.org answered with status \(status). Try again later.")
        case .tooManyRedirects:
            ErrorPage(status: 502, title: "Too Many Redirects",
                      message: "The Wayback Machine kept redirecting \(original.absoluteString) "
                          + "without reaching a page.")
        }
    }

    /// "December 8, 2001" — fixed English, whatever the host's locale.
    private static func spelledOut(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
