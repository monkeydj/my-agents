#!/usr/bin/env bash
# refresh-stats-cache.sh — Stale-check hook for stats-cache.json
#
# When Claude Code's background stats-recompute freezes (known bug #46139),
# the cache's `lastComputedDate` stops advancing. This hook deletes the
# stale cache so it gets rebuilt fresh on the next Claude Code interaction.
#
# Trigger: SessionStart (cheap — only deletes when the cache is >MAX_STALE days old)
#
# Usage in ~/.claude/settings.json:
#   "hooks": {
#     "SessionStart": [{
#       "matcher": "*",
#       "hooks": [{ "type": "command", "command": "~/.claude/scripts/refresh-stats-cache.sh" }]
#     }]
#   }
#
# Or via cron for periodic background cleanup (recommended alongside):
#   */30 * * * * ~/.claude/scripts/refresh-stats-cache.sh --quiet

set -euo pipefail

MAX_STALE_DAYS="${MAX_STALE_DAYS:-2}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
STATS_FILE="$CLAUDE_DIR/stats-cache.json"
QUIET=false

for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=true ;;
    esac
done

if [ ! -f "$STATS_FILE" ]; then
    if [ "$QUIET" = false ]; then
        echo "refresh-stats-cache: no stats-cache.json — nothing to refresh"
    fi
    exit 0
fi

last_computed="$(jq -r '.lastComputedDate // empty' "$STATS_FILE" 2>/dev/null || echo "")"

if [ -z "$last_computed" ]; then
    # No lastComputedDate → cache is malformed or v1; safe to refresh.
    rm -f "$STATS_FILE"
    [ "$QUIET" = false ] && echo "refresh-stats-cache: removed malformed cache (no lastComputedDate)"
    exit 0
fi

# Convert dates to epoch seconds for comparison
cache_epoch="$(date -d "$last_computed" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$last_computed" +%s 2>/dev/null || echo 0)"
now_epoch="$(date +%s)"
age_days=$(( (now_epoch - cache_epoch) / 86400 ))

if [ "$age_days" -ge "$MAX_STALE_DAYS" ]; then
    rm -f "$STATS_FILE"
    [ "$QUIET" = false ] && echo "refresh-stats-cache: cache stale (${age_days}d, threshold ${MAX_STALE_DAYS}d) — deleted for rebuild"
else
    [ "$QUIET" = false ] && echo "refresh-stats-cache: cache fresh (${age_days}d old) — skipping"
fi
