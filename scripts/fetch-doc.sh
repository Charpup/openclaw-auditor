#!/usr/bin/env bash
# fetch-doc.sh — fetch a docs.openclaw.ai page as clean markdown
#
# docs.openclaw.ai supports HTTP content negotiation: with `Accept: text/markdown`
# it returns the raw markdown source, which is what Claude wants. Without that
# header you get HTML and have to convert (lossy).
#
# Usage:
#   bash fetch-doc.sh <path>
#   bash fetch-doc.sh gateway/configuration
#   bash fetch-doc.sh gateway/troubleshooting
#   bash fetch-doc.sh cli
#
# The <path> is whatever follows https://docs.openclaw.ai/ — get the canonical
# path list via fetch-llms-index.sh first.
#
# Exit codes:
#   0 — fetch succeeded
#   1 — bad usage or curl failed
#   2 — page not found (HTTP 4xx)

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: bash fetch-doc.sh <path>      # e.g. gateway/configuration" >&2
  echo "Run 'bash fetch-llms-index.sh' first to discover available paths." >&2
  exit 1
fi

PATH_ARG="${1#/}"  # strip leading slash if present
URL="https://docs.openclaw.ai/${PATH_ARG}"

HTTP_CODE=$(curl -sS -o /tmp/openclaw-doc-fetch.$$.body \
  -w '%{http_code}' \
  --max-time 20 \
  -H 'Accept: text/markdown' \
  "$URL")
RC=$?

if [[ "$RC" -ne 0 ]]; then
  echo "ERROR: curl failed for $URL (exit $RC)" >&2
  rm -f /tmp/openclaw-doc-fetch.$$.body
  exit 1
fi

if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "ERROR: HTTP $HTTP_CODE for $URL" >&2
  echo "Check the path against llms.txt: bash fetch-llms-index.sh <keyword>" >&2
  rm -f /tmp/openclaw-doc-fetch.$$.body
  exit 2
fi

cat /tmp/openclaw-doc-fetch.$$.body
rm -f /tmp/openclaw-doc-fetch.$$.body
