#!/usr/bin/env bash
# Self-check for rpg-statusline-fast.sh. Run: bash scripts/rpg-statusline-fast.test.sh
#
# Deliberately clock-free (no reset-countdown assertions) and independent of
# rpg-statusline.sh, so it keeps working once the old script is retired.

S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rpg-statusline-fast.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# A quoting slip inside the jq program is invisible until the script runs, so
# parse it first — that is the failure this file exists to catch.
bash -n "$S" || { echo "FAIL: syntax error"; exit 1; }

# check <name> <payload> <expected substring, ANSI-stripped>
check() {
    local out err; err="$TMP/err"
    out="$(printf '%s' "$2" | COLUMNS=200 bash "$S" 2>"$err")"
    local rc=$? plain; plain="$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')"
    local lines; lines="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    if [ $rc -ne 0 ]; then echo "FAIL [$1]: exit $rc"; fail=$((fail+1)); return; fi
    if [ -s "$err" ]; then echo "FAIL [$1]: stderr: $(cat "$err")"; fail=$((fail+1)); return; fi
    if [ "$lines" != 2 ]; then echo "FAIL [$1]: $lines lines, want 2"; fail=$((fail+1)); return; fi
    case "$plain" in
        *"$3"*) pass=$((pass+1)) ;;
        *) echo "FAIL [$1]: missing '$3' in:"; printf '  %s\n' "$plain"; fail=$((fail+1)) ;;
    esac
}

# Vitals arithmetic: HP is the inverse of used context, bars round to 10 cells.
check "hp from used_pct"  '{"context_window":{"used_percentage":37}}'           'HP [██████░░░░] 63%'
check "hp clamps high"    '{"context_window":{"used_percentage":250}}'          'HP [░░░░░░░░░░] 0%'
check "hp clamps low"     '{"context_window":{"used_percentage":-40}}'          'HP [██████████] 100%'
check "pct as string"     '{"context_window":{"used_percentage":"37"}}'         'HP [██████░░░░] 63%'
check "mp unknown"        '{}'                                                  'MP [░░░░░░░░░░] ??%'
check "gold from 7day"    '{"rate_limits":{"seven_day":{"used_percentage":12}}}' 'Gold [█████████░] 88%'
check "lines changed"     '{"cost":{"total_lines_added":42,"total_lines_removed":7}}' '+42/-7'

# Class + level mapping.
check "opus"    '{"model":{"id":"claude-opus-5[1m]"}}'         '🧙 ARCHMAGE lv.50'
check "sonnet"  '{"model":{"id":"claude-sonnet-4-5-20250929"}}' '🪄 WIZARD lv.45'
check "unknown" '{"model":{"id":"totally-unknown"}}'            '🗿 MERCENARY lv.??'

# Effort buff tiers.
check "effort high" '{"reasoning_effort":"high"}' '🔥E3 ▮▮▮▯▯'
check "effort max"  '{"effort":{"level":"MAX"}}'  '🌋E5 ▮▮▮▮▮'

# Malformed input must still render two lines rather than abort under `set -e`.
check "not json"        'hello'                                               'MERCENARY'
check "empty stdin"     ''                                                    'MERCENARY'
check "iso resets_at"   '{"rate_limits":{"five_hour":{"used_percentage":10,"resets_at":"2026-01-01T00:00:00Z"}}}' 'MP [█████████░] 90%'

# Git status tokens, counted from one porcelain pass.
d="$TMP/repo"; mkdir -p "$d"
git -C "$d" init -q -b main; git -C "$d" config user.email t@t; git -C "$d" config user.name t
git -C "$d" commit -q --allow-empty -m init
for i in 1 2 3 4 5; do echo x > "$d/f$i"; done
git -C "$d" add "$d/f1" "$d/f2" "$d/f3"; echo y > "$d/f1"
check "git tokens"   "{\"cwd\":\"$d\"}" '🌿 +3 !1 ?2 main'
git -C "$d" checkout -q --detach
check "detached"     "{\"cwd\":\"$d\"}" 'HEAD'
check "not a repo"   '{"cwd":"/tmp"}'   '🏰 /tmp'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
