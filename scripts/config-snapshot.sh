#!/usr/bin/env bash
# config-snapshot.sh — capture openclaw.json baseline + baseHash before audit-recommended changes
#
# Run this BEFORE any proposed config change. Outputs:
#   1. timestamped backup ~/.openclaw/openclaw.json.bak.<TS>
#   2. pretty-printed snapshot for diffing
#   3. baseHash from `openclaw gateway call config.get` (required by config.patch / config.apply)
#   4. per-agent overrides snapshot (catches F7-class regressions)
#
# Usage:
#   bash config-snapshot.sh
#
# Exit codes:
#   0 — snapshot complete
#   1 — openclaw.json missing or unreadable
#   2 — jq missing
#
# After audit + change applied, diff with:
#   diff <(jq -S . ~/.openclaw/openclaw.json) ~/.openclaw/upgrade-logs/audit-snapshot-pretty-<TS>.json

set -uo pipefail

CONFIG=/root/.openclaw/openclaw.json
LOG_DIR=/root/.openclaw/upgrade-logs
TS=$(date -u +%Y%m%d-%H%M%S)

if [[ ! -r "$CONFIG" ]]; then
  echo "ERROR: $CONFIG not readable" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2
  exit 2
fi

mkdir -p "$LOG_DIR"

echo "=== config-snapshot @ $(date -Iseconds) ==="
echo "TS=$TS"
echo ""

BACKUP="${CONFIG}.bak.${TS}"
cp -a "$CONFIG" "$BACKUP"
echo "[1/4] backup → $BACKUP"

PRETTY="$LOG_DIR/audit-snapshot-pretty-${TS}.json"
jq -S . "$CONFIG" > "$PRETTY"
echo "[2/4] pretty snapshot → $PRETTY  ($(wc -l < "$PRETTY") lines)"

BASEHASH_FILE="$LOG_DIR/audit-basehash-${TS}.txt"
if command -v openclaw >/dev/null 2>&1; then
  if openclaw gateway call config.get --params '{}' > "$BASEHASH_FILE" 2>&1; then
    BASEHASH=$(jq -r '.baseHash // .hash // empty' "$BASEHASH_FILE" 2>/dev/null || true)
    if [[ -n "$BASEHASH" ]]; then
      echo "[3/4] baseHash=$BASEHASH  (full response → $BASEHASH_FILE)"
      echo "      include this in subsequent config.patch/apply calls"
    else
      echo "[3/4] baseHash NOT extracted (gateway response → $BASEHASH_FILE)"
      echo "      gateway may be down — recommend restart before config.patch"
    fi
  else
    echo "[3/4] WARN: 'openclaw gateway call config.get' failed (response → $BASEHASH_FILE)"
    echo "      gateway likely down; static-only audit possible, but no baseHash for patch"
  fi
else
  echo "[3/4] SKIP: openclaw not on PATH (host doesn't have CLI installed)"
fi

AGENTS_FILE="$LOG_DIR/audit-agents-${TS}.json"
if AGENTS_JSON=$(jq '.agents // {}' "$CONFIG" 2>/dev/null); then
  printf '%s' "$AGENTS_JSON" > "$AGENTS_FILE"
  AGENT_COUNT=$(jq 'length' "$AGENTS_FILE")
  echo "[4/4] per-agent overrides → $AGENTS_FILE  (agents=$AGENT_COUNT)"
  echo "      compare post-change to detect F7 (silent override loss)"
else
  echo "[4/4] WARN: jq failed parsing .agents node"
fi

echo ""
echo "=== Snapshot complete ==="
echo "Refer to these files when writing audit results back to Notion:"
echo "  backup:       $BACKUP"
echo "  pretty:       $PRETTY"
echo "  baseHash:     $BASEHASH_FILE"
echo "  agents:       $AGENTS_FILE"
