#!/usr/bin/env bash
# Run before every push to this repo: starts nginx with this config and asks it for the page under each
# host name. `nginx -t` checks syntax only; on 18 Nov 2026 a syntactically valid config sent the bare
# domain to the www redirect and the site looped for half an hour.
#   ./check.sh            needs docker; exits 1 on any wrong answer
set -euo pipefail
cd "$(dirname "$0")"
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
curl -s -H "Host: thelibrarian.energy" "http://127.0.0.1:$PORT/" | grep -q "THE LIBRARIAN" || { echo "WRONG the page body is not the page"; fail=1; }
curl -sI -H "Host: thelibrarian.energy" "http://127.0.0.1:$PORT/" | grep -qi "content-security-policy" || { echo "WRONG no security headers on the page"; fail=1; }
exit $fail
