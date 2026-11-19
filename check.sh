#!/usr/bin/env bash
# Run before every push to this repo: starts nginx with this config and asks it for the page under each
# host name. `nginx -t` checks syntax only; on 18 Nov 2026 a syntactically valid config sent the bare
# domain to the www redirect and the site looped for half an hour.
#   ./check.sh            needs docker; exits 1 on any wrong answer
set -euo pipefail
cd "$(dirname "$0")"
# The page is one inline script. If it does not parse, none of it runs and no question can be asked, in any
# browser. On 19 Nov 2026 a sentence with double quotes inside a double-quoted string was committed, and nothing
# here would have seen it: every check below asks nginx for bytes, none reads them as a program. Needs node.
python3 - > /tmp/page-script.$$.js <<'PY'
import re, sys
found = re.findall(r"<script>(.*?)</script>", open("index.html", encoding="utf-8").read(), flags=re.S)
if not found:
    sys.exit("no inline script found in index.html")
print("\n;\n".join(found))
PY
if node --check /tmp/page-script.$$.js; then echo "ok    the page's script parses"; else echo "WRONG the page's script does not parse"; rm -f /tmp/page-script.$$.js; exit 1; fi
rm -f /tmp/page-script.$$.js
NAME=thelib-check-$$; PORT=${PORT:-8798}
docker build -q -t "$NAME" . > /dev/null
docker run -d --rm --name "$NAME" -p "127.0.0.1:$PORT:80" "$NAME" > /dev/null
trap 'docker stop "$NAME" > /dev/null 2>&1; docker rmi "$NAME" > /dev/null 2>&1 || true' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 1; done
fail=0
expect() {  # host, path, wanted status, wanted redirect target ("" = none)
  got=$(curl -s -o /dev/null -w "%{http_code} %{redirect_url}" -H "Host: $1" "http://127.0.0.1:$PORT$2")
  want="$3 $4"
  if [ "$got" = "$want" ]; then echo "ok    $1$2 -> $got"; else echo "WRONG $1$2 -> $got (wanted $want)"; fail=1; fi
}
expect thelibrarian.energy / 200 ""
expect thelibrarian.energy /favicon-32.png 200 ""
expect www.thelibrarian.energy / 301 "https://thelibrarian.energy/"
expect www.thelibrarian.energy /x 301 "https://thelibrarian.energy/x"
expect 10.0.0.9 / 200 ""
expect thelibrarian.energy /llms.txt 200 ""
# Over the flood limit the answer is a 429 with a JSON body, not nginx's HTML 503.
codes=""; for _ in $(seq 1 14); do codes="$codes $(curl -s -o /tmp/limited.$$ -w "%{http_code}" -X POST -H "Host: thelibrarian.energy" -H "X-Forwarded-For: 203.0.113.9" -H "Content-Type: application/json" -d '{"id":"x","verdict":"wrong"}' "http://127.0.0.1:$PORT/api/feedback")"; done
if echo "$codes" | grep -q 429 && grep -q '"error"' /tmp/limited.$$; then echo "ok    flood limit answers 429 with JSON"; else echo "WRONG flood limit:$codes"; fail=1; fi
if echo "$codes" | grep -q 503; then echo "WRONG flood limit still answers 503"; fail=1; fi
rm -f /tmp/limited.$$
curl -s -H "Host: thelibrarian.energy" "http://127.0.0.1:$PORT/" | grep -q "THE LIBRARIAN" || { echo "WRONG the page body is not the page"; fail=1; }
curl -sI -H "Host: thelibrarian.energy" "http://127.0.0.1:$PORT/" | grep -qi "content-security-policy" || { echo "WRONG no security headers on the page"; fail=1; }
exit $fail
