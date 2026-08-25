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

Flags: `--only <fixture>`, `--dialect 32|401`, `--update`.

The harness exits non-zero when an invariant breaks or output drifts, so it
works as a CI gate.

## How it is wired

`Package.swift` at the repo root compiles the pipeline **straight from the
app's own sources** — `HTML/`, `Images/`, and the four `Proxy/` files that have
no networking dependencies. There is no copy of the pipeline here to fall out
of date. The app is still built from `ARP Proxy.xcodeproj`; the package exists
only so the transformation layer can run outside an app bundle.

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

## Known failures

The harness was red on its first run, and the findings are real — verified
against literal output bytes, not a re-parse. Vintage browsers ignore unknown
elements, so these are DTD-validity failures rather than blank pages, but the
project emits a matching DOCTYPE and should honour it.

1. **`<tbody>` is injected by our own parser.** Hacker News' source contains
   zero `<tbody>`; our HTML 3.2 output contains four. SwiftSoup's HTML5 tree
   construction inserts them, so the pipeline *creates* an HTML 4.0 tag that
   3.2 has no notion of. Wikipedia passes 28 through from source.
2. **HTML5 text tags survive**: `<bdi>`×17 and `<wbr>`×2 on Wikipedia, in both
   dialects. `RemoveModernTagsPass` doesn't list them.
3. **`<label>` reaches the 3.2 output** (8 on Wikipedia, 1 on BBC). It is legal
   in 4.01 but postdates 3.2, so it belongs in `DowngradeHTML4InlineTagsPass`.
4. **Web Components pass through untouched**: `<react-partial>`,
   `<include-fragment>`, `<tool-tip>`, `<cookie-consent-link>`, `<ghcc-consent>`,
   `<react-app>` on GitHub, in both dialects. Any hyphenated custom element
   will do this.

## Going deeper

The vocabulary check uses element sets transcribed from the specs. For true
SGML validation against the real DTDs, `onsgmls` (`brew install open-sp`) is
the engine the old W3C validator used:

```bash
onsgmls -s -wxml Benchmarks/Output/hacker-news.html32.html
```
