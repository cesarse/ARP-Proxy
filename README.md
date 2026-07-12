# ARP Proxy

A macOS app (Swift 6 / SwiftUI, Xcode 26) that lets vintage operating systems
running in UTM — Mac OS 9, Windows 95, Windows 3.11, … — browse the modern web.

Old browsers only speak plain HTTP and SSL 2/3, so they cannot open today's
TLS-only sites. ARP Proxy runs an HTTP proxy on your Mac: the guest browser
talks plain HTTP to the proxy, and the proxy talks modern HTTPS to the world.

## How it works

- The app listens on a TCP port (default **8080**) and understands classic
  HTTP/1.0 and HTTP/1.1 proxy requests (`GET http://host/path`).
- Every `http://` request is **upgraded to `https://`** upstream (with a
  fallback to plain HTTP for sites that still serve it).
- Responses are **downgraded to HTTP/1.0**: no chunked transfer encoding, no
  compression, explicit `Content-Length`, `Connection: close`.
- `https://` occurrences in HTML, CSS and JavaScript bodies — and in
  `Location` redirect headers — are rewritten to `http://`, so every click
  keeps flowing through the proxy.
- Modern-only headers that confuse or break old clients (HSTS, CSP, alt-svc,
  transfer/content encodings…) are stripped.
- `CONNECT` (real HTTPS tunneling) is intentionally rejected with a friendly
  error page telling you to use `http://` — old SSL stacks couldn't complete a
  modern TLS handshake anyway.

## Building

Open `ARPProxy.xcodeproj` in Xcode 26 and press Run. The project uses
ad-hoc signing ("Sign to Run Locally"), so no developer team is required.
The app is sandboxed with incoming + outgoing network entitlements.

## Using it from a UTM guest

1. Launch ARP Proxy — the proxy starts automatically and the window shows
   the addresses to use.
2. In the guest OS, set the **HTTP proxy** in the browser's preferences
   (e.g. Internet Explorer → Internet Options → Connections → LAN Settings,
   or Netscape → Preferences → Advanced → Proxies → Manual).
   - **Emulated VLAN (default UTM/QEMU networking):** use `10.0.2.2`, port `8080`.
   - **Shared/bridged network:** use one of the Mac addresses listed in the
     RetroProxy window.
3. Browse with `http://` URLs. The proxy handles the HTTPS part.

If macOS asks about allowing incoming connections (firewall), accept.

## Localization

The UI is localized with a String Catalog
([`Localizable.xcstrings`](ARPProxy/Localizable.xcstrings)) in English,
Spanish, French and German. Adding a language is a matter of adding a column
in Xcode's String Catalog editor.

## Ideas for the next step (HTML simplification)

Rendering is untouched for now; some options to explore later, roughly in
order of effort:

- Strip `<script>`, `<style>`, `<link rel="stylesheet">` and modern tags
  server-side (SwiftSoup would make this easy).
- Convert pages to HTML 3.2 (tables instead of CSS layout, `<font>` tags).
- Transcode images: old browsers don't know WebP/AVIF; re-encode to GIF/JPEG
  with ImageIO.
- Force `charset` conversion to Latin-1/Mac Roman for pre-Unicode browsers.

## Limitations

- One request per connection (HTTP/1.0 style) — simple and reliable, slightly
  slower than keep-alive.
- Multiple `Set-Cookie` headers may arrive merged into one (a Foundation
  URLSession limitation); most old browsers cope, some cookies may be lost.
- Sites that hard-require JavaScript will load but not function — that's the
  rendering-simplification battle, not the transport one.
