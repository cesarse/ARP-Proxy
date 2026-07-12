import SwiftUI

@main
struct RetroProxyApp: App {
    @State private var server = ProxyServer()

    var body: some Scene {
        WindowGroup {
            ContentView(server: server)
        }
        .windowResizability(.contentMinSize)
    }
}
