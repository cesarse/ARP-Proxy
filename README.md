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
- **WebP, AVIF and HEIC images are transcoded** with ImageIO to formats
  vintage browsers understand: JPEG for opaque images, GIF for images with
  real transparency, and animated GIF (frame delays and looping preserved)
  for animations. Still images are downscaled to at most 2048 px to spare
  vintage-era RAM. Detection uses magic bytes first, so mislabeled
  Content-Type headers don't slip WebP through.
- **HTML is simplified with SwiftSoup**: scripts, stylesheets, `<meta>`,
  inline SVG, `<template>` and other modern machinery are removed;
  `<noscript>` fallbacks are unwrapped; HTML5 semantic containers become
  `<div>`s; lazy-loaded images get a real `src`; iframes become links;
  `<button>` becomes `<input type=submit>`; hidden elements are dropped
  before `style`/`class`/`on*`/`data-*`/`aria-*` attributes are stripped.
  The result is serialized as pure ASCII with decimal character entities
  and served as `iso-8859-1`, safe for pre-Unicode browsers (typographic
  quotes and dashes are transliterated to ASCII). Pages typically shrink
  by about half.
- `CONNECT` (real HTTPS tunneling) is intentionally rejected with a friendly
  error page telling you to use `http://` — old SSL stacks couldn't complete a
  modern TLS handshake anyway.

## Building

Open `ARP Proxy.xcodeproj` in Xcode 26 and press Run. The project uses
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
     ARP Proxy window.
3. Browse with `http://` URLs. The proxy handles the HTTPS part.

If macOS asks about allowing incoming connections (firewall), accept.

## Localization

The UI is localized with a String Catalog
([`Localizable.xcstrings`](ARP%20Proxy/Localizable.xcstrings)) in English,
Spanish, French and German. Adding a language is a matter of adding a column
in Xcode's String Catalog editor.

## Ideas for the next step

- Rasterize SVG images referenced by `<img src="….svg">` to GIF/JPEG —
  inline `<svg>` is removed, but image files still reach the browser as SVG.
- Convert pages further toward HTML 3.2 (tables instead of CSS layout,
  `<font>` tags).
- Optionally transcode PNG too, for browsers that predate PNG support
  (Netscape 2/3, IE 3).

## Limitations

- One request per connection (HTTP/1.0 style) — simple and reliable, slightly
  slower than keep-alive.
- Multiple `Set-Cookie` headers may arrive merged into one (a Foundation
  URLSession limitation); most old browsers cope, some cookies may be lost.
- Sites that hard-require JavaScript will load but not function — that's the
  rendering-simplification battle, not the transport one.
