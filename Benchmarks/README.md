# Benchmarks

A scoreboard for the HTML simplification pipeline. It runs frozen captures of
real pages through the **real production entry point** — `BodyTransformer`, so
both simplification and the `https://`→`http://` rewrite are exercised — and
reports what came out.

```bash
swift run arp-bench
```

```
swift run arp-bench --only cnn-homepage --dialect 32
```

Flags: `--only <fixture>`, `--dialect 32|401`, `--tables on|off`, `--update`.

Every fixture runs in four combinations — both dialects × both layout modes —
so a full run is 24 measurements. The table-building pass is the only one that
*adds* structure and the only one that can misread a page, so it earns
permanent coverage rather than an occasional manual check.

The harness exits non-zero when an invariant breaks or output drifts, so it
works as a CI gate.

## How it is wired

`Package.swift` at the repo root compiles the pipeline **straight from the
app's own sources** — `HTML/`, `Images/`, and the `Proxy/` files that have
no networking dependencies. There is no copy of the pipeline here to fall out
of date. The app is still built from `ARP Proxy.xcodeproj`; the package exists
only so the transformation layer can run outside an app bundle (it also hosts
the unit tests in `Tests/ARPProxyTests`).

The app's types are `internal`, which is correct for an app with no library
consumers. Rather than spread `public` through production code purely to let a
benchmark see it, the module is built with `-enable-testing` and the harness
uses `@testable import`.

Adding a file to `Proxy/` will raise an "unhandled files" warning until it is
listed in `Package.swift` as either a source or an exclusion. That is
deliberate — new files get a decision instead of silently vanishing.

### Keep SwiftSoup in step with the app

The two dependency graphs resolve separately, and they *will* drift: on first
setup the package picked SwiftSoup 2.13.7 while the app shipped 2.13.6.
SwiftSoup's tree construction is itself under test here — it is what injects
`<tbody>` — so benchmarking a different parser than the app ships would be
measuring the wrong thing.

The root `Package.resolved` is therefore pinned to the same revision the Xcode
project resolved. After changing the app's SwiftSoup version, re-sync it:

```bash
python3 -c "
import json
x = json.load(open('ARP Proxy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'))
r = json.load(open('Package.resolved')); r['pins'] = x['pins']
open('Package.resolved','w').write(json.dumps(r, indent=2) + '\n')"
```

## Why the fixtures are frozen

`Fixtures/` holds committed snapshots, not live fetches. CNN's homepage changes
hourly; a benchmark that re-fetched could not tell a regression from a news
cycle.

They are captured with a **vintage User-Agent**, because `UpstreamRequestBuilder`
forwards the guest browser's UA verbatim — capturing with a modern UA would
benchmark a document the proxy never actually sees.

Refresh with `./capture-fixtures.sh`, and expect the goldens to move with it.

| fixture | why it is in the corpus |
|---|---|
| `cnn-homepage` | Dense card grid, ~5 MB. The layout stress case, and the closest to `maxInputBytes` |
| `wikipedia-article` | Text and real tables. The do-no-harm case — this should come through near-perfect |
| `hacker-news` | Already table-based 1997 HTML. A canary: output should barely differ from input |
| `duckduckgo-html` | Script-free search results, protocol-relative `//duckduckgo.com/l/` redirect links |
| `bbc-news` | A second news archetype, to catch heuristics that only fit CNN |
| `github-repo` | Deeply nested divs, code blocks, and Web Components |

`duckduckgo-html` is captured over POST: that endpoint rate-limits GET, and its
own forms use `method="post"` anyway.

## Metrics vs. invariants

**Metrics** are reported and expected to move: byte ratio, elapsed time,
element count, images (with a parenthesised count of any that a vintage browser
could not draw — no `src`, or a `data:` URI), links.

**Invariants** are promises the README makes to the browser. Any breakage fails
the run:

- the body was actually simplified (no silent bail-out on size or decode)
- zero non-ASCII bytes in the output
- zero surviving `https://`
- no tag that a pass was supposed to remove (`script`, `iframe`, `button`, …) —
  the forbidden list in `DTDVocabulary` names the responsible pass for each
- no tag outside the target DTD's vocabulary
- byte-identical output across two identical runs

## Goldens and the output diff

`Output/` is **committed**. When a digest drifts, `git diff Benchmarks/Output`
shows you exactly which markup changed rather than just reporting that
something did. `Golden/golden.json` stores the digests so the report can show
an `ok`/`DRIFT` column without shelling out to git.

Workflow: make a change → `swift run arp-bench` → read the drift → inspect
`git diff Benchmarks/Output` → accept with `--update`.

`Output/` is also the place to grab a page to open in a real vintage browser
under UTM. Nothing here substitutes for looking at it in Netscape.

## What it caught

The harness was red on its first run. All four findings were real — verified
against literal output bytes rather than a re-parse — and all four turned out
to be the same defect: the pipeline removed a hardcoded list of known-bad tags
and assumed the rest were fine, so it had no notion of what its target DTD
actually contains.

1. **`<tbody>` injected by our own parser.** Hacker News' source contained zero
   `<tbody>`; our HTML 3.2 output contained four. SwiftSoup does HTML5 tree
   construction, so the pipeline *created* a tag 3.2 has no notion of.
2. **HTML5 text tags surviving** — `<bdi>`×17, `<wbr>`×2 on Wikipedia, both
   dialects.
3. **`<label>` in 3.2 output** (8 Wikipedia, 1 BBC): legal in 4.01, postdates
   3.2.
4. **Web Components passing through** — `<react-partial>`,
   `<include-fragment>`, `<tool-tip>`, `<cookie-consent-link>` and friends on
   GitHub. Any hyphenated tag a site invents would do this.

`HTMLVocabulary` and `UnwrapUnknownElementsPass` fixed all four at once, and
the sweep is self-maintaining: the next invented tag is already handled.

It also caught a bug in *itself*. `Measurer` originally counted tags by
re-parsing the output with SwiftSoup — which re-inserts `<tbody>` — so the
check would have gone permanently red against a correct pipeline. It now
counts opening tags in the serialized bytes. When a benchmark and the code
under test share a parser, the benchmark stops being independent; that is also
why `DTDVocabulary` here keeps its own transcription of the element sets rather
than importing `HTMLVocabulary` from the app. Two independent transcriptions
catch each other's typos.

## What the corpus decided about table layout

`GridDetector`'s thresholds are not guesses; each one is a measurement from
these six pages.

- **Every member carries an image.** On CNN the content cards score 1.0 on
  this and run ~26 nodes each, while the navigation menus — which repeat just
  as often, 20 and 15 at a time — score 0.0 and run 1–2 nodes.
- **Cells run 5–80 nodes.** CNN's eight `div.zone` blocks repeat *and* contain
  images, but at ~150 nodes each they are full-width page sections; standing
  them side by side would be nonsense.
- **Nothing under `<nav>`, `<header>` or `<footer>`.** This is why the pass
  runs before `RenameSemanticTagsPass` — afterwards they are all `<div>` and
  the signal is gone.
- **A page needs at least two grids.** DuckDuckGo's ten search results pass
  every other test: same class, right size, an image each. But they are a
  list, and they read far better as one. A page that genuinely lays itself out
  as a grid does so repeatedly — CNN 11, BBC 5, Wikipedia 2, DuckDuckGo 1.

Measured effect, HTML 3.2:

| fixture | plain | with tables | tables built |
|---|---|---|---|
| cnn-homepage | 141,488 | 142,608 | 9 |
| bbc-news | 40,410 | 41,873 | 4 |
| wikipedia-article | 485,861 | 486,570 | 3 |
| hacker-news | 20,418 | 20,418 | 0 |
| duckduckgo-html | 23,220 | 23,220 | 0 |
| github-repo | 45,685 | 45,685 | 0 |

The three zeroes are the point: already-clean pages come through
byte-identical. Link and image counts are unchanged on every fixture, so the
pass moves content without dropping any.

### Why the cells constrain their images

The first working version produced tables **1,464 px wide on a 640 px screen** —
three columns of 488 px — which would have put two thirds of the page behind a
horizontal scrollbar. A table cell is only as narrow as its widest image, and
`ResolveLazyImagesPass` has already stripped width/height by then, so the
browser was laying out BBC's 480 px photos at full size.

`TableLayoutBuilder` now sets `width` on every unsized image in a cell — width
alone, so the browser keeps the aspect ratio, and a plain pixel count because
HTML 3.2 has no percentage lengths for `<img>`. Forced onto a 640 px canvas the
same table now renders at exactly 640 px, three columns of 213 px, no overflow.

This is the failure mode worth remembering: the markup was valid, the invariants
all passed, and the layout was still unusable. Validity is not legibility, and
the harness cannot see the difference — look at the output in a real browser.

## Going deeper

The vocabulary check uses element sets transcribed from the specs. For true
SGML validation against the real DTDs, `onsgmls` (`brew install open-sp`) is
the engine the old W3C validator used:

```bash
onsgmls -s -wxml Benchmarks/Output/hacker-news.html32.html
```
