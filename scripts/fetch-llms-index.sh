#!/usr/bin/env bash
# fetch-llms-index.sh — fetch docs.openclaw.ai/llms.txt and optionally grep it
#
# llms.txt is the agent-friendly index of every doc page on docs.openclaw.ai,
# refreshed by upstream on every release. Always start here before fetching
# specific doc pages — it tells you what exists *now*, not what your local
# references think exists.
#
# Usage:
#   bash fetch-llms-index.sh                  # print full index
#   bash fetch-llms-index.sh <keyword>        # case-insensitive grep filter
#   bash fetch-llms-index.sh gateway          # e.g. find all gateway-related pages
#
# Exit codes:
#   0 — fetch succeeded (with or without grep matches)
#   1 — curl failed (network / DNS / cert)

set -uo pipefail

URL="https://docs.openclaw.ai/llms.txt"
KEYWORD="${1:-}"

BODY=$(curl -fsSL --max-time 15 "$URL")
RC=$?

if [[ "$RC" -ne 0 ]]; then
  echo "ERROR: failed to fetch $URL (curl exit $RC)" >&2
  echo "Fall back to web_search 'site:docs.openclaw.ai <topic>' or check status of upstream." >&2
  exit 1
fi

if [[ -z "$KEYWORD" ]]; then
  printf '%s\n' "$BODY"
else
  printf '%s\n' "$BODY" | grep -i -- "$KEYWORD" || {
    echo "(no matches for '$KEYWORD' in llms.txt — try a broader keyword or fetch the full index)" >&2
    exit 0
  }
fi
