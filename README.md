# Another Retro Proxy

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
  Content-Type headers don't slip WebP through. Oversized JPEG, PNG and
  still-GIF images are downscaled to the configured maximum as well
  (opaque → JPEG, transparent → GIF); images already within the limit
  pass through byte-identical, and animated GIFs are never touched.
- **HTML is simplified with SwiftSoup**: scripts, stylesheets, `<meta>`,
  inline SVG, `<template>` and other modern machinery are removed;
  `<noscript>` fallbacks are unwrapped; HTML5 semantic containers become
  `<div>`s; lazy-loaded images get a real `src`; iframes become links;
  `<button>` becomes `<input type=submit>`; hidden elements are dropped
  before `style`/`class`/`on*`/`data-*`/`aria-*` attributes are stripped.
  `width`/`height` attributes on `<img>` are removed too — modern sites size
  images with CSS and the attributes often describe a different crop than
  the served file, which would stretch the image in a CSS-less browser.
  The result is serialized as pure ASCII with decimal character entities
  and served as `iso-8859-1`, safe for pre-Unicode browsers (typographic
  quotes and dashes are transliterated to ASCII). Pages typically shrink
  by about half.
- `CONNECT` (real HTTPS tunneling) is intentionally rejected with a friendly
  error page telling you to use `http://` — old SSL stacks couldn't complete a
  modern TLS handshake anyway.
- **Wayback mode** (opt-in) answers every request from the
  [Internet Archive](https://web.archive.org/) instead of the live web, as
  captured nearest a chosen date. The guest browser never knows: it asks for
  `http://www.cnn.com/` and gets CNN as of that day, with the original
  addresses in every link, so each click comes back through the proxy.
  Captures are fetched in the archive's raw `id_` form (no toolbar, no link
  rewriting). The archive's "nearest capture" redirects are followed inside
  the proxy; redirects the site itself made back then are passed to the
  browser as the site's own addresses, so relative links keep resolving.
  Archive-only response headers are stripped, and the guest's cookies,
  credentials and cache validators are not sent to the archive. Pages that
  were never archived get a plain error page naming the URL and the date;
  form submissions (`POST`) can't be replayed and are refused. Requests to
  `archive.org` itself still go to the live site. The request log shows the
  actual capture date of each response, which can drift from the chosen
  date when the archive has no closer copy.

## Project layout

One type per file, grouped by responsibility:

- `App/` — the SwiftUI entry point.
- `Views/` — one component per file: main window, status line, addresses
  panel, request log and its rows, settings window and its sections.
- `Proxy/` — the connection orchestrator plus one collaborator per job:
  browser socket, request reader, upstream URL resolver, HTTPS upgrader,
  upstream fetcher, body transformer, response-head builder, error page,
  settings, network-interface discovery.
- `Images/` — the transcoding strategies (one per format) composing two
  shared behaviors (modern conversion, legacy downscaling), small
  single-purpose helpers (still decoder, metadata reader, transparency
  detector, GIF builder, JPEG encoder), and the facade with the
  format→strategy registry.
- `HTML/` — the simplification pipeline: dialect strategies (3.2 / 4.01)
  contribute a DOCTYPE and version passes; the engine runs an ordered
  `HTML/Passes/` pipeline (one small pass type per transformation),
  then serializes to vintage-safe ASCII.
- `Resources/` — asset catalog and the localization string catalog.
- `Benchmarks/` — frozen captures of real pages and the harness that scores
  the simplification pipeline against them ([details](Benchmarks/README.md)).
- `Tests/` — unit tests for the proxy's request/response helpers and
  settings ([how to run](#tests)).

## Building

Open `ARP Proxy.xcodeproj` in Xcode 26 and press Run. The project uses
ad-hoc signing ("Sign to Run Locally"), so no developer team is required.
The app is sandboxed with incoming + outgoing network entitlements.

## Settings

ARP Proxy → Settings… (⌘,) opens a settings window where you can choose:

- the **port** (changing it restarts the proxy),
- whether to **convert modern images**, the **JPEG quality** (30–100 %)
  and the **maximum image size** (640–4096 px),
- whether to **simplify HTML** and which dialect to target — **HTML 3.2**
  (also unwraps HTML 4 inline tags like `<q>`, `<abbr>`, `<ins>`, `<del>`,
  `<span>`) or **HTML 4.01 Transitional**; the matching DOCTYPE is emitted,
- whether to **remove image size attributes** (on by default — fixes
  stretched images on CSS-sized sites, at the cost of some reflow while a
  page loads),
- whether to **reproduce page layout with tables** (off by default). Modern
  pages keep their layout in CSS, which the simplifier strips, so a page
  arrives as one long column. This rebuilds the card grids as tables, the way
  a site would have been built in 1997. The original structure has to be
  inferred from repetition in the markup, so it is the one setting that can
  read a page wrongly — hence opt-in,
- whether to **browse the past with the Wayback Machine**, and the **date**
  to browse (1996 to today). While it is on, the main window shows the date
  next to the proxy status.

Settings are persisted and apply to the next request — no restart needed
(except the port). The UI uses Liquid Glass, so the app requires macOS 26.

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
([`Localizable.xcstrings`](ARP%20Proxy/Resources/Localizable.xcstrings)) in
English, Spanish, French, German, Italian and Brazilian Portuguese. Adding a
language is a matter of adding a column in Xcode's String Catalog editor.

## Benchmarks

`swift run arp-bench` runs six frozen captures of real pages — CNN, Wikipedia,
Hacker News, DuckDuckGo, BBC, GitHub — through the real `BodyTransformer` and
reports how each dialect did, in both metrics (byte ratio, elapsed time,
element and image counts) and hard invariants (pure ASCII, no surviving
`https://`, nothing outside the target DTD, deterministic output). It exits
non-zero on a broken invariant or drifted output, so it doubles as a CI gate.

The `Package.swift` at the repo root exists for this and for the unit tests:
it compiles the pipeline from the app's own sources, so there is no second
copy to drift. The app itself is still built from the Xcode project. See
[`Benchmarks/README.md`](Benchmarks/README.md).

## Tests

```bash
swift test
```

Unit tests (Swift Testing) in `Tests/ARPProxyTests/` cover the code that
shapes traffic without touching the network: resolving the request target,
the HTTPS upgrade candidates, which request and response headers are
forwarded, dropped or rewritten, the `https://`→`http://` body rewrite, the
error page, settings persistence and clamping, and Wayback mode's address
mapping and its reading of the archive's redirects and errors. Like the benchmark, they
compile the app's own sources through the root `Package.swift`; sockets,
URLSession and the UI are left out.

## Ideas for the next step

- Rasterize SVG images referenced by `<img src="….svg">` to GIF/JPEG —
  inline `<svg>` is removed, but image files still reach the browser as SVG.
- Convert pages further toward HTML 3.2: `<font>` tags and `bgcolor`, plus a
  small hand-written CSS 1 stylesheet for the 4.01 dialect. (Table layout is
  done — see the *Reproduce page layout with tables* setting.)
- Optionally transcode PNG too, for browsers that predate PNG support
  (Netscape 2/3, IE 3).

## Limitations

- One request per connection (HTTP/1.0 style) — simple and reliable, slightly
  slower than keep-alive.
- Multiple `Set-Cookie` headers may arrive merged into one (a Foundation
  URLSession limitation); most old browsers cope, some cookies may be lost.
- Sites that hard-require JavaScript will load but not function — that's the
  rendering-simplification battle, not the transport one.
- In Wayback mode, each page and image comes from its own nearest capture,
  so parts of a page can be days or years apart. The guest browser's cache
  doesn't know about the date: after changing it, clear the cache to stop
  seeing pages from the previous one. The Internet Archive also rate-limits
  heavy clients; an image-heavy page can occasionally trip it.
