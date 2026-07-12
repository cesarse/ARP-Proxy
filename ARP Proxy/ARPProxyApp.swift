import SwiftUI

@main
struct ARPProxyApp: App {
    @State private var server = ProxyServer()

    var body: some Scene {
        WindowGroup {
            ContentView(server: server)
        }
        .windowResizability(.contentMinSize)
    }
}
