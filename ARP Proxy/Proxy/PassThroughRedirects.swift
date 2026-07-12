import Foundation

/// Redirects are passed through to the browser (with the Location header
/// rewritten to http://) instead of being followed by URLSession.
nonisolated final class PassThroughRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
