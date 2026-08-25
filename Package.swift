// swift-tools-version: 6.0
import PackageDescription

// The app itself is built from "ARP Proxy.xcodeproj"; this package exists so
// the body-transformation pipeline can be compiled and benchmarked outside the
// app bundle. It reuses the very same sources — there are no copies to drift.
//
// Only the pure-Foundation transformation layer is pulled in. The networking
// layer (sockets, URLSession, the SwiftUI app) is excluded: it needs a running
// proxy, and the benchmark feeds bodies in directly. Adding a file to `Proxy/`
// raises an "unhandled files" warning until it is classified below — that is
// deliberate, so new sources get a decision rather than silently vanishing.
let package = Package(
    name: "ARPProxyBenchmarks",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "ARPProxyHTML",
            dependencies: ["SwiftSoup"],
            path: "ARP Proxy",
            exclude: [
                "App", "Views", "Resources", "ARPProxy.entitlements",
                "Proxy/BrowserSocket.swift",
                "Proxy/ErrorPage.swift",
                "Proxy/HTTPHeader.swift",
                "Proxy/HTTPReasonPhrase.swift",
                "Proxy/HTTPRequest.swift",
                "Proxy/HTTPRequestReader.swift",
                "Proxy/HTTPSUpgrader.swift",
                "Proxy/LogEntry.swift",
                "Proxy/NetworkInfo.swift",
                "Proxy/NetworkInterfaceAddress.swift",
                "Proxy/PassThroughRedirects.swift",
                "Proxy/ProxyConnection.swift",
                "Proxy/ProxyError.swift",
                "Proxy/ProxyServer.swift",
                "Proxy/ProxyServerState.swift",
                "Proxy/ResponseHeadBuilder.swift",
                "Proxy/UpstreamFetcher.swift",
                "Proxy/UpstreamRequestBuilder.swift",
                "Proxy/UpstreamResponse.swift",
                "Proxy/UpstreamURLResolver.swift",
            ],
            sources: [
                "HTML", "Images",
                "Proxy/ProxySettings.swift",
                "Proxy/SchemeRewriter.swift",
                "Proxy/TransformedBody.swift",
                "Proxy/BodyTransformer.swift",
            ],
            // The app's types are `internal`, which is right for the app — it
            // has no library consumers. Rather than sprinkle `public` through
            // production code purely to let the benchmark see it, the module is
            // compiled with testing enabled and the harness uses `@testable`.
            swiftSettings: [.unsafeFlags(["-enable-testing"])]
        ),
        .executableTarget(
            name: "arp-bench",
            dependencies: ["ARPProxyHTML", "SwiftSoup"],
            path: "Benchmarks/Sources/arp-bench"
        ),
    ]
)
