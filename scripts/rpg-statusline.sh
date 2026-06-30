#!/usr/bin/env bash
# rpg-statusline.sh — Retro RPG statusline for Claude Code
#
# ❤️  HP  = Context window remaining (REAL: read from the session transcript)
# 🔮 MP  = "Mana" — a PROXY for API budget. Claude Code does NOT expose real
#          rate-limit headers (anthropic-ratelimit-*) to statusline scripts,
#          so MP is derived from session cost vs MANA_BUDGET_USD below.
#          It is a spend gauge, NOT your true rate limit.
#
# Wire it up in settings.json:
#   "statusLine": { "type": "command", "command": "~/.claude-profiles/lifanuke/rpg-statusline.sh" }
#
# Input: a JSON object on stdin (Claude Code statusline contract).

set -euo pipefail

# ----- Config -------------------------------------------------------------
BAR_WIDTH=10
MANA_BUDGET_USD="${RPG_MANA_BUDGET_USD:-5.00}"   # session "mana pool" in USD
DEFAULT_CTX_WINDOW=200000                         # tokens, standard window

# ----- ANSI palette -------------------------------------------------------
ESC=$'\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
RED="${ESC}[38;5;196m"
ORANGE="${ESC}[38;5;208m"
YELLOW="${ESC}[38;5;226m"
GREEN="${ESC}[38;5;46m"
CYAN="${ESC}[38;5;51m"
BLUE="${ESC}[38;5;39m"
PURPLE="${ESC}[38;5;141m"
GOLD="${ESC}[38;5;220m"
GREY="${ESC}[38;5;245m"

# ----- Read stdin ---------------------------------------------------------
input="$(cat)"

jqget() { printf '%s' "$input" | jq -r "$1" 2>/dev/null || true; }

model_name="$(jqget '.model.display_name // .model.id // "Adventurer"')"
model_id="$(jqget '.model.id // ""')"
transcript="$(jqget '.transcript_path // ""')"
cost_usd="$(jqget '.cost.total_cost_usd // 0')"
lines_added="$(jqget '.cost.total_lines_added // 0')"
lines_removed="$(jqget '.cost.total_lines_removed // 0')"
exceeds_200k="$(jqget '.exceeds_200k_tokens // false')"

# ----- Context window size (1M models carry "[1m]" in the id) ------------
ctx_window=$DEFAULT_CTX_WINDOW
case "$model_id" in
    *"[1m]"*|*"1m"*) ctx_window=1000000 ;;
esac
[ "$exceeds_200k" = "true" ] && [ "$ctx_window" -lt 1000000 ] && ctx_window=1000000

# ----- HP: real context occupancy from the transcript --------------------
# Sum of the most recent usage record: input + cache_read + cache_creation.
ctx_used=0
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    ctx_used="$(tail -n 200 "$transcript" 2>/dev/null | jq -s '
        [ .[]
          | select(.message.usage != null)
          | .message.usage
          | (.input_tokens // 0)
            + (.cache_read_input_tokens // 0)
            + (.cache_creation_input_tokens // 0)
        ] | last // 0' 2>/dev/null || echo 0)"
fi
[ -z "$ctx_used" ] && ctx_used=0

# HP = % of context still free. Filling context = taking damage.
hp_pct=$(( 100 - (ctx_used * 100 / ctx_window) ))
[ "$hp_pct" -lt 0 ] && hp_pct=0
[ "$hp_pct" -gt 100 ] && hp_pct=100

# ----- MP: cost-based proxy (see header note) -----------------------------
# Integer math in cents to avoid floating point.
cost_cents="$(printf '%.0f' "$(echo "$cost_usd * 100" | bc -l 2>/dev/null || echo 0)" 2>/dev/null || echo 0)"
budget_cents="$(printf '%.0f' "$(echo "$MANA_BUDGET_USD * 100" | bc -l 2>/dev/null || echo 500)" 2>/dev/null || echo 500)"
[ "$budget_cents" -le 0 ] && budget_cents=500
mp_pct=$(( 100 - (cost_cents * 100 / budget_cents) ))
[ "$mp_pct" -lt 0 ] && mp_pct=0
[ "$mp_pct" -gt 100 ] && mp_pct=100

# ----- Bar renderer -------------------------------------------------------
# render_bar <pct> <filled_color> : prints "[████░░░░░░]"
render_bar() {
    local pct="$1" color="$2"
    local filled=$(( (pct * BAR_WIDTH + 50) / 100 ))
    [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
    [ "$filled" -lt 0 ] && filled=0
    local empty=$(( BAR_WIDTH - filled ))
    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    local e=""
    for (( i=0; i<empty; i++ )); do e+="░"; done
    printf '%s[%s%s%s%s%s]%s' "$GREY" "$color" "$bar" "$DIM" "$e" "$RESET$GREY" "$RESET"
}

# Health-style color: green high → red low.
health_color() {
    local pct="$1"
    if   [ "$pct" -ge 60 ]; then printf '%s' "$GREEN"
    elif [ "$pct" -ge 30 ]; then printf '%s' "$YELLOW"
    elif [ "$pct" -ge 15 ]; then printf '%s' "$ORANGE"
    else printf '%s' "$RED"; fi
}

hp_color="$(health_color "$hp_pct")"
mp_color="$BLUE"
[ "$mp_pct" -lt 30 ] && mp_color="$PURPLE"

# Low-HP warning glyph
hp_icon="❤️ "
[ "$hp_pct" -lt 15 ] && hp_icon="💔"

# ----- Compose statusline -------------------------------------------------
class_short="$(printf '%s' "$model_name" | tr '[:lower:]' '[:upper:]' | cut -c1-8)"

printf '%s🧙 %sLv.%s%s  ' "$PURPLE" "$BOLD" "$class_short" "$RESET"
printf '%s%s%s %sHP%s %s %s%3d%%%s  ' \
    "$RED" "$hp_icon" "$RESET" "$BOLD" "$RESET" \
    "$(render_bar "$hp_pct" "$hp_color")" "$hp_color" "$hp_pct" "$RESET"
printf '%s🔮 %sMP%s %s %s%3d%%%s  ' \
    "$CYAN" "$BOLD" "$RESET" \
    "$(render_bar "$mp_pct" "$mp_color")" "$mp_color" "$mp_pct" "$RESET"
printf '%s💰 %s¢%s  ' "$GOLD" "$cost_cents" "$RESET"
printf '%s⚔️  +%s%s%s/%s-%s%s\n' "$GREEN" "$lines_added" "$RESET" "$GREY" "$RED" "$lines_removed" "$RESET"
