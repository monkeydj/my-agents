#!/usr/bin/env bash
# rpg-statusline.sh — Retro RPG statusline for Claude Code
#
# ❤️  HP   = context window remaining (.context_window; transcript fallback)
# 🔮 MP   = 5h rate-limit budget left (.rate_limits.five_hour); ??% when absent, never faked full
# 💸 Coin = real tokens used last 7 days, summed from stats-cache.json (dailyModelTokens); 󰑐 = 7-day rate-limit reset; "??" when cache absent/unreadable
# 🕯️🔥☄️💥🌋 Buff = reasoning-effort power-up after class level, tier number + heat bar (E1→E5); JSON tier else $MAX_THINKING_TOKENS bucket; hidden when neither present
# 📜 Log  = every statusline payload appended as JSONL to /tmp/statusline.log for monitoring
#
# settings.json: "statusLine": { "type": "command", "command": "~/.claude/scripts/rpg-statusline.sh" }
# Input: JSON object on stdin (statusline contract).

set -euo pipefail

# ----- Config -------------------------------------------------------------
BAR_WIDTH=10
DEFAULT_CTX_WINDOW=200000    # standard context window, tokens

# ----- Resolve Claude config directory (once) -------------------------------
# Expects <claude-dir>/scripts/rpg-statusline.sh so the grandparent is the
# claude root (e.g. ~/.claude or a custom profile dir). Falls back to ~/.claude
# if the script path is ambiguous, so it stays robust under any profile layout.
CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
[ -z "$CLAUDE_DIR" ] && CLAUDE_DIR="$HOME/.claude"
[ -f "$CLAUDE_DIR/stats-cache.json" ] || [ -f "$CLAUDE_DIR/settings.json" ] || CLAUDE_DIR="$HOME/.claude"

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
DIMGOLD="${ESC}[38;5;136m"                          # tarnished coin
GREY="${ESC}[38;5;245m"

# ----- Muted palette (line 2 world/context, recedes behind vitals) --------
M_SLATE="${ESC}[38;5;67m"     # path / location
M_SAGE="${ESC}[38;5;108m"     # branch, staged, clean
M_TAN="${ESC}[38;5;179m"      # unstaged
M_PYTHON="${ESC}[38;5;74m"    # python (official blue)
M_TEAL="${ESC}[38;5;73m"      # ahead
M_LAVENDER="${ESC}[38;5;103m" # behind
M_MOSS="${ESC}[38;5;72m"      # node
M_RUST="${ESC}[38;5;173m"    # dirty branch
# untracked keeps GREY (245)

# ----- Read stdin ---------------------------------------------------------
input="$(cat)"

# JSONL capture for monitoring; never allowed to break the statusline.
printf '%s\n' "$input" >> /tmp/statusline.log 2>/dev/null || true

jqget() { printf '%s' "$input" | jq -r "$1" 2>/dev/null || true; }

# human_duration <seconds> → "2d4h" / "3h12m" / "45m"; empty if <=0
human_duration() {
    local s="$1"
    if [ "$s" -le 0 ] 2>/dev/null; then printf 'stale'; return; fi
    local d=$(( s / 86400 )) h=$(( (s % 86400) / 3600 )) m=$(( (s % 3600) / 60 ))
    if   [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
    elif [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"
    else printf '%dm' "$m"; fi
}

# format_tokens <int> → "1.4M" / "920K" / "12K" / raw
format_tokens() {
    awk -v n="$1" 'BEGIN{
        if (n>=1000000) printf "%.1fM", n/1000000;
        else if (n>=1000) printf "%.0fK", n/1000;
        else printf "%d", n;
    }'
}

model_name="$(jqget '.model.display_name // .model.id // "Adventurer"')"
model_id="$(jqget '.model.id // ""')"
transcript="$(jqget '.transcript_path // ""')"
lines_added="$(jqget '.cost.total_lines_added // 0')"
lines_removed="$(jqget '.cost.total_lines_removed // 0')"
exceeds_200k="$(jqget '.exceeds_200k_tokens // false')"
cwd="$(jqget '.workspace.current_dir // .cwd // empty')"
[ -z "$cwd" ] && cwd="$PWD"

# Real context + rate-limit fields from the statusline contract
ctx_pct_in="$(jqget '.context_window.used_percentage // empty')"
ctx_size_in="$(jqget '.context_window.context_window_size // .context_window.total_tokens // empty')"
five_used_in="$(jqget '.rate_limits.five_hour.used_percentage // empty')"
five_reset_in="$(jqget '.rate_limits.five_hour.resets_at // empty')"
seven_used_in="$(jqget '.rate_limits.seven_day.used_percentage // empty')"
seven_reset_in="$(jqget '.rate_limits.seven_day.resets_at // empty')"

# ----- Context window size (1M models carry "[1m]" in the id) ------------
ctx_window=$DEFAULT_CTX_WINDOW
case "$model_id" in
    *"[1m]"*|*"1m"*) ctx_window=1000000 ;;
esac
[ "$exceeds_200k" = "true" ] && [ "$ctx_window" -lt 1000000 ] && ctx_window=1000000

# ----- HP: context remaining ---------------------------------------------
# Prefer statusline's used_percentage; else sum latest transcript usage.
[ -n "$ctx_size_in" ] && ctx_window="$ctx_size_in"
ctx_used_pct=""
[ -n "$ctx_pct_in" ] && ctx_used_pct="$(printf '%.0f' "$ctx_pct_in" 2>/dev/null || echo "")"
if [ -z "$ctx_used_pct" ]; then
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
    ctx_used_pct=$(( ctx_used * 100 / ctx_window ))
fi

# HP = % context still free (filling context = damage).
hp_pct=$(( 100 - ctx_used_pct ))
[ "$hp_pct" -lt 0 ] && hp_pct=0
[ "$hp_pct" -gt 100 ] && hp_pct=100

# ----- MP: 5-hour rate-limit budget remaining -----------------------------
# From .rate_limits.five_hour. Absent → mark unknown, never fake a full bar.
five_used="$five_used_in"
five_reset="$five_reset_in"
mp_known=1
mp_pct=0
if [ -n "$five_used" ]; then
    five_used_int="$(printf '%.0f' "$five_used" 2>/dev/null || echo "")"
    if [ -n "$five_used_int" ]; then
        mp_pct=$(( 100 - five_used_int ))
        [ "$mp_pct" -lt 0 ] && mp_pct=0
        [ "$mp_pct" -gt 100 ] && mp_pct=100
    else
        mp_known=0
    fi
else
    mp_known=0
fi

# MP regen countdown to the next 5h reset.
mp_reset_str=""
if [ -n "$five_reset" ]; then
    now="$(date +%s)"
    mp_reset_str="$(human_duration $(( five_reset - now )))"
fi

# 💸 real tokens used in the last 7 days, summed from the stats cache (dailyModelTokens).
# Falls back to the live 7-day rate-limit used-percentage from the statusline contract
# when the cache is stale/absent (Claude Code's stats recompute has known freeze bugs).
# Never a fabricated number — always one of: real count, live %, or ??.
week_known=0
week_rate_limited=0
week_used_label="??"
stats_file="$CLAUDE_DIR/stats-cache.json"
if [ -f "$stats_file" ]; then
    week_tokens="$(jq -r '
        (now - 6*86400 | gmtime | strftime("%Y-%m-%d")) as $cut
        | [ .dailyModelTokens[]?
            | select(.date >= $cut)
            | .tokensByModel // {} | to_entries[] | .value ]
        | if length == 0 then "empty" else add // 0 end
    ' "$stats_file" 2>/dev/null || echo "")"
    case "$week_tokens" in
        ''|empty|*[!0-9]*) : ;;
        *) week_used_label="$(format_tokens "$week_tokens")"; week_known=1 ;;
    esac
fi
# Fallback: live rate-limit percentage from the statusline contract.
if [ "$week_known" -eq 0 ] && [ -n "$seven_used_in" ]; then
    week_used_pct="$(printf '%.0f' "$seven_used_in" 2>/dev/null || echo "")"
    if [ -n "$week_used_pct" ]; then
        week_used_label="ⓢ${week_used_pct}%"
        week_known=1
        week_rate_limited=1
    fi
fi

# Weekly rate-limit reset countdown (independent of the token source above).
week_reset_str=""
if [ -n "$seven_reset_in" ]; then
    now="$(date +%s)"
    week_reset_str="$(human_duration $(( seven_reset_in - now )))"
fi

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
[ "$mp_known" -eq 0 ] && mp_color="$GREY"

# Weekly usage is real measured tokens → gold; grey ?? when the cache is unavailable.
cost_color="$GOLD"
[ "$week_known" -eq 0 ] && cost_color="$GREY"

# Low-HP warning glyph
hp_icon="❤️ "
[ "$hp_pct" -lt 42 ] && hp_icon="💔"

# ----- Compose statusline -------------------------------------------------
# Segments divided by a dim │ with one space each side (no run of >1 space).
SEP=" ${DIM}${GREY}│${RESET} "

# Map model → DnD class + emoji; unknown → MERCENARY. Sets class_icon, class_short.
# o-series matched with trailing dash (o3-) so bare "o1"/"o3" can't false-match a hash.
class_for_model() {
    local hay
    hay="$(printf '%s %s' "$model_id" "$model_name" | tr '[:upper:]' '[:lower:]')"
    case "$hay" in
        *opus*)                   class_icon="🧙"; class_short="ARCHMAGE"  ;; # deepest reasoning → arcane elder
        *sonnet*)                 class_icon="🪄"; class_short="WIZARD"    ;; # best all-round coder → trained mage
        *haiku*)                  class_icon="🗡️"; class_short="ROGUE"     ;; # fast & cheap → nimble striker
        *fable*)                  class_icon="🎸"; class_short="BARD"      ;; # creative/storyteller → performer
        *gpt*|*openai*|*o1-*|*o3-*|*o4-*) class_icon="😈"; class_short="WARLOCK" ;; # power via an outside patron
        *gemini*)                 class_icon="🏹"; class_short="RANGER"    ;; # broad-reach search/tooling → tracker
        *llama*)                  class_icon="🌿"; class_short="DRUID"     ;; # open/wild weights → nature shifter
        *mistral*|*mixtral*)      class_icon="🛡️"; class_short="PALADIN"   ;; # French chivalry → oath-bound knight
        *grok*)                   class_icon="🪓"; class_short="BARBARIAN" ;; # brash & edgy → rage fighter
        *deepseek*)               class_icon="🌀"; class_short="MONK"      ;; # the deep seeker → disciplined ascetic
        *qwen*)                   class_icon="📖"; class_short="CLERIC"    ;; # steady support model → faith healer
        *claude*)                 class_icon="🎲"; class_short="ADVENTURER";; # unrecognized Claude → generic hero
        *)                        class_icon="🗿"; class_short="MERCENARY" ;; # unknown vendor → hired sword
    esac
}
class_for_model

# Model version → RPG "level" (Opus 4.8 → lv.4.8): dotted 4.8, then dash 4-5→4.5, else major 5.
# Ordered so a trailing date suffix (…-20251001) can't win over the real version.
ver_hay="$model_name $model_id"
model_level="$(printf '%s' "$ver_hay" | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)"
if [ -z "$model_level" ]; then
    model_level="$(printf '%s' "$ver_hay" | grep -oE '[0-9]+-[0-9]+' | head -n1 | tr '-' '.' || true)"
fi
[ -z "$model_level" ] && model_level="$(printf '%s' "$ver_hay" | grep -oE '[0-9]+' | head -n1 || true)"

# x10 → integer level (4.8→48, 5→50). %.0f rounds; %d would floor 4.8*10 to 47. Unknown → ??.
if [ -n "$model_level" ]; then
    model_level="$(awk -v v="$model_level" 'BEGIN{printf "%.0f", v*10}')"
else
    model_level="??"
fi

# ----- Git (computed before line 1 — status tokens on line 1, branch on line 2) ---
shorten_path() {
    local p="$1" max=30
    case "$p" in "$HOME"/*|"$HOME") p="~${p#"$HOME"}" ;; esac
    [ "${#p}" -gt "$max" ] && p="…${p: -$max}"
    printf '%s' "$p"
}

gs_tokens=""
add_tok() {
    if [ -n "$gs_tokens" ]; then gs_tokens="$gs_tokens $1"; else gs_tokens="$1"; fi
}

branch="" ; is_worktree=0
if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    gd="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null || true)"
    case "$gd" in */worktrees/*) is_worktree=1 ;; esac
    porc="$(git -C "$cwd" status --porcelain 2>/dev/null || true)"
    staged="$(printf '%s\n' "$porc" | grep -cE '^[MADRC]' || true)"
    unstaged="$(printf '%s\n' "$porc" | grep -cE '^.[MD]' || true)"
    untracked="$(printf '%s\n' "$porc" | grep -c '^??' || true)"
    ahead=0 ; behind=0
    ab="$(git -C "$cwd" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || true)"
    if [ -n "$ab" ]; then
        behind="$(printf '%s' "$ab" | awk '{print $1+0}')"
        ahead="$(printf '%s' "$ab" | awk '{print $2+0}')"
    fi
    [ "$staged" -gt 0 ]    && add_tok "$(printf '%s+%s%s' "$M_SAGE" "$staged" "$RESET")"
    [ "$unstaged" -gt 0 ]  && add_tok "$(printf '%s!%s%s' "$M_TAN" "$unstaged" "$RESET")"
    [ "$untracked" -gt 0 ] && add_tok "$(printf '%s?%s%s' "$GREY" "$untracked" "$RESET")"
    [ "$ahead" -gt 0 ]     && add_tok "$(printf '%s↑%s%s' "$M_TEAL" "$ahead" "$RESET")"
    [ "$behind" -gt 0 ]    && add_tok "$(printf '%s↓%s%s' "$M_LAVENDER" "$behind" "$RESET")"
fi

# Language runtimes for line 1 tail (detected early; blank if absent).
py="" ; node=""
command -v python3 >/dev/null 2>&1 && py="$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2 || true)"
command -v node >/dev/null 2>&1 && node="$(node --version 2>&1 | sed 's/^v//' | cut -d. -f1,2 || true)"

# Official Seti Python logo glyph (U+E606, needs a Nerd Font); 🐍 via STATUSLINE_NF=0.
if [ "${STATUSLINE_NF:-1}" = "1" ]; then
    PY_ICON=$'\xEE\x98\x86'   # U+E606 Seti python (UTF-8; bash 3.2-safe)
else
    PY_ICON="🐍"
fi

# ----- Line 1: vitals — lines-changed → HP → MP → cost → langs ---------
printf '%s⚔️ +%s%s%s/%s-%s%s' "$GREEN" "$lines_added" "$RESET" "$GREY" "$RED" "$lines_removed" "$RESET"
printf '%s' "$SEP"
printf '%s%s%s%sHP%s %s %s%d%%%s' \
    "$RED" "$hp_icon" "$RESET" "$BOLD" "$RESET" \
    "$(render_bar "$hp_pct" "$hp_color")" "$hp_color" "$hp_pct" "$RESET"
printf '%s' "$SEP"
if [ "$mp_known" -eq 1 ]; then
    printf '%s🔮 %sMP%s %s %s%d%%%s' \
        "$CYAN" "$BOLD" "$RESET" \
        "$(render_bar "$mp_pct" "$mp_color")" "$mp_color" "$mp_pct" "$RESET"
    [ -n "$mp_reset_str" ] && printf ' %s󰑐%s%s' "$DIM" "$mp_reset_str" "$RESET"
else
    printf '%s🔮 %sMP%s %s %s??%%%s' \
        "$CYAN" "$BOLD" "$RESET" \
        "$(render_bar 0 "$GREY")" "$GREY" "$RESET"
fi
printf '%s' "$SEP"
if [ "$week_rate_limited" -eq 1 ]; then
    printf '%s💸 %s%s %s(rate-limit%%)%s' "$DIM" "$week_used_label" "$RESET" "$DIM" "$RESET"
else
    printf '%s💸 %s%s' "$cost_color" "$week_used_label" "$RESET"
fi
[ -n "$week_reset_str" ] && printf ' %s󰑐%s%s' "$DIM" "$week_reset_str" "$RESET"
[ -n "$py" ]   && printf '%s%s' "$SEP" && printf '%s%s %s%s' "$M_PYTHON" "$PY_ICON" "$py" "$RESET"
[ -n "$node" ] && printf '%s%s' "$SEP" && printf '%s⬢ %s%s' "$M_MOSS" "$node" "$RESET"
printf '\n'

# ----- Line 2: context — class → dir → git-tokens → branch -----------------
dir_icon="🏰"
[ "$is_worktree" -eq 1 ] && dir_icon="🛖"

# ----- Effort buff: RPG power-up aura from the reasoning-effort tier -------
# Source order (never fabricated): explicit tier in the statusline JSON, else
# $CLAUDE_EFFORT, else effortLevel in settings.json colocated with this script
# (no env-passthrough dependency), else bucket $MAX_THINKING_TOKENS into tiers.
# None present → no buff rendered.
effort_tier="$(jqget '.reasoning_effort // (if (.effort|type)=="object" then .effort.level else .effort end) // empty' | tr '[:upper:]' '[:lower:]')"
[ -z "$effort_tier" ] && effort_tier="$(printf '%s' "${CLAUDE_EFFORT:-}" | tr '[:upper:]' '[:lower:]')"
if [ -z "$effort_tier" ]; then
        settings_file="$CLAUDE_DIR/settings.json"
    if [ -f "$settings_file" ]; then
        effort_tier="$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    fi
fi
if [ -z "$effort_tier" ]; then
    mtt="${MAX_THINKING_TOKENS:-}"
    case "$mtt" in
        ''|*[!0-9]*) : ;;
        *)
            if   [ "$mtt" -le 0 ];     then effort_tier=""
            elif [ "$mtt" -le 4000 ];  then effort_tier="low"
            elif [ "$mtt" -le 10000 ]; then effort_tier="medium"
            elif [ "$mtt" -le 24000 ]; then effort_tier="high"
            elif [ "$mtt" -le 32000 ]; then effort_tier="xhigh"
            else effort_tier="max"; fi
            ;;
    esac
fi

# Ascending heat gradient: candle ember → molten volcano. Rendered as a
# numeric tier (E1–E5) plus a 5-cell heat bar; hidden when no tier resolves.
effort_buff=""
effort_n=0
effort_icon=""
effort_color=""
case "$effort_tier" in
    low)    effort_n=1; effort_icon="🕯️"; effort_color="$DIMGOLD" ;;
    medium) effort_n=2; effort_icon="🔥"; effort_color="$YELLOW" ;;
    high)   effort_n=3; effort_icon="☄️"; effort_color="$ORANGE" ;;
    xhigh)  effort_n=4; effort_icon="💥"; effort_color="$RED" ;;
    max)    effort_n=5; effort_icon="🌋"; effort_color="$GOLD" ;;
esac
if [ "$effort_n" -gt 0 ]; then
    ebar=""
    for (( i=1; i<=5; i++ )); do
        if [ "$i" -le "$effort_n" ]; then ebar+="${effort_color}▮"; else ebar+="${DIM}▯"; fi
    done
    effort_buff="$(printf '%s%s%sE%d%s %s%s' "$effort_color" "$effort_icon" "$BOLD" "$effort_n" "$RESET" "$ebar" "$RESET")"
fi

segs=()
segs+=("$(printf '%s%s %s%s%s %slv.%s%s%s' \
    "$PURPLE" "$class_icon" "$BOLD" "$class_short" "$RESET" "$DIM$PURPLE" "$model_level" "$RESET" \
    "${effort_buff:+ $effort_buff}")")
segs+=("$(printf '%s%s %s%s' "$M_SLATE" "$dir_icon" "$(shorten_path "$cwd")" "$RESET")")
if [ -n "$gs_tokens" ]; then
    segs+=("$(printf '%s%s%s%s' "$M_SAGE" "$gs_tokens" "$RESET")")
elif [ -n "$branch" ]; then
    segs+=("$(printf '%s✓%s' "$M_SAGE" "$RESET")")
fi
if [ -n "$branch" ]; then
    branch_color="$M_SAGE"
    [ $(( staged + unstaged + untracked )) -gt 0 ] && branch_color="$M_RUST"
    segs+=("$(printf '%s🌿 %s%s' "$branch_color" "$branch" "$RESET")")
fi

line2=""
for s in "${segs[@]}"; do
    [ -n "$line2" ] && line2="${line2}${SEP}"
    line2="${line2}${s}"
done
printf '%s\n' "$line2"
