#!/bin/bash
#
# Re-captures the benchmark corpus. Fixtures are FROZEN SNAPSHOTS committed to
# the repo: CNN changes hourly, so benchmarking against the live web cannot
# tell a regression from a news cycle. Run this only when you deliberately want
# to refresh the corpus, and expect the golden files to move with it.
#
# The User-Agent matters. ARP Proxy forwards the guest browser's UA verbatim
# (UpstreamRequestBuilder does not drop it), so the vintage string below is
# what production actually sends — capturing with a modern UA would benchmark
# a document the proxy never sees.
#
set -uo pipefail
cd "$(dirname "$0")"

UA="Mozilla/4.0 (compatible; MSIE 5.0; Mac_PowerPC)"
OUT="Fixtures"
mkdir -p "$OUT"

# name|url|post-body (empty for GET)|why this page is in the corpus
CORPUS=(
"cnn-homepage|https://www.cnn.com/||Dense card grid, ~5 MB, the layout stress case and the closest to the size cap"
"wikipedia-article|https://en.wikipedia.org/wiki/Macintosh||Text and real tables; should come through near-perfect. The do-no-harm case"
"hacker-news|https://news.ycombinator.com/||Already table-based 1997 HTML. Canary: output should barely differ from input"
"duckduckgo-html|https://html.duckduckgo.com/html/|q=vintage+macintosh|Script-free search results; protocol-relative //duckduckgo.com/l/ redirect links. POST, because that endpoint rate-limits GET and its own forms use method=post"
"bbc-news|https://www.bbc.com/news||Second news archetype, for cross-checking CNN-specific heuristics"
"github-repo|https://github.com/scinfu/SwiftSoup||Deeply nested divs and code blocks; a developer-facing layout"
)

echo "["  > "$OUT/manifest.json"
first=1
for row in "${CORPUS[@]}"; do
    IFS='|' read -r name url postdata note <<< "$row"
    printf '%-20s ' "$name"
    if [ -n "$postdata" ]; then
        ctype=$(curl -sS -L --max-time 60 -A "$UA" -d "$postdata" "$url" \
                -o "$OUT/$name.html" -w '%{content_type}' 2>/dev/null)
    else
        ctype=$(curl -sS -L --max-time 60 -A "$UA" "$url" \
                -o "$OUT/$name.html" -w '%{content_type}' 2>/dev/null)
    fi
    status=$?
    size=$(wc -c < "$OUT/$name.html" | tr -d ' ')
    if [ $status -ne 0 ] || [ "$size" -lt 500 ]; then
        echo "FAILED (curl=$status, ${size} bytes) - leaving previous fixture in place"
        continue
    fi
    echo "ok  ${size} bytes  ${ctype}"
    [ $first -eq 0 ] && echo "," >> "$OUT/manifest.json"
    first=0
    printf '  {"name": "%s", "url": "%s", "contentType": "%s", "capturedAt": "%s", "note": "%s"}' \
        "$name" "$url" "$ctype" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$note" >> "$OUT/manifest.json"
done
printf '\n]\n' >> "$OUT/manifest.json"
echo
echo "Wrote $OUT/manifest.json"
