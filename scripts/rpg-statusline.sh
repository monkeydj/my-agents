#!/usr/bin/env bash
# rpg-statusline.sh — Retro RPG statusline for Claude Code
#
# ❤️  HP  = Context window remaining (REAL: statusline .context_window, with a
#          transcript-derived fallback).
# 🔮 MP  = Mana = your 5-hour rate-limit budget remaining (REAL: statusline
#          .rate_limits.five_hour). Full MP = full 5h budget; MP drains as you
#          consume rate-limit quota (NOT context), and shows a ⟳ regen
#          countdown to the next reset. If the field is absent MP shows ??% —
#          a missing budget is never rendered as a full bar.
#
# Wire it up in settings.json:
#   "statusLine": { "type": "command", "command": "~/.claude-profiles/lifanuke/rpg-statusline.sh" }
#
# Input: a JSON object on stdin (Claude Code statusline contract).

set -euo pipefail

# ----- Config -------------------------------------------------------------
BAR_WIDTH=10
DEFAULT_CTX_WINDOW=200000                          # tokens, standard window

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
DIMGOLD="${ESC}[38;5;136m"                          # notional cost — tarnished coin
GREY="${ESC}[38;5;245m"

# ----- Muted palette (line 2: world/context, recedes behind vitals) -------
# Desaturated "parchment map" band — keeps line 2 from competing with line 1.
M_SLATE="${ESC}[38;5;67m"     # path / location
M_SAGE="${ESC}[38;5;108m"     # branch, staged, clean
M_TAN="${ESC}[38;5;179m"      # python, unstaged
M_TEAL="${ESC}[38;5;73m"      # ahead
M_LAVENDER="${ESC}[38;5;103m" # behind
M_MOSS="${ESC}[38;5;72m"      # node
# untracked keeps GREY (245) — already muted

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
cwd="$(jqget '.workspace.current_dir // .cwd // empty')"
[ -z "$cwd" ] && cwd="$PWD"

# Real context + rate-limit fields (present in current statusline contract)
ctx_pct_in="$(jqget '.context_window.used_percentage // empty')"
ctx_size_in="$(jqget '.context_window.context_window_size // .context_window.total_tokens // empty')"
five_used_in="$(jqget '.rate_limits.five_hour.used_percentage // empty')"
five_reset_in="$(jqget '.rate_limits.five_hour.resets_at // empty')"

# ----- Context window size (1M models carry "[1m]" in the id) ------------
ctx_window=$DEFAULT_CTX_WINDOW
case "$model_id" in
    *"[1m]"*|*"1m"*) ctx_window=1000000 ;;
esac
[ "$exceeds_200k" = "true" ] && [ "$ctx_window" -lt 1000000 ] && ctx_window=1000000

# ----- HP: context remaining ---------------------------------------------
# Prefer the statusline's own context_window.used_percentage; otherwise sum the
# most recent transcript usage (input + cache_read + cache_creation).
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

# HP = % of context still free. Filling context = taking damage.
hp_pct=$(( 100 - ctx_used_pct ))
[ "$hp_pct" -lt 0 ] && hp_pct=0
[ "$hp_pct" -gt 100 ] && hp_pct=100

# ----- MP: 5-hour rate-limit budget remaining -----------------------------
# Read straight from the statusline's .rate_limits.five_hour. If the field is
# absent we DON'T fake a full bar — we mark MP unknown so a missing budget never
# reads as "plenty left".
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
    diff=$(( five_reset - now ))
    if [ "$diff" -gt 0 ]; then
        rh=$(( diff / 3600 )); rm=$(( (diff % 3600) / 60 ))
        if [ "$rh" -gt 0 ]; then mp_reset_str="$(printf '%dh%dm' "$rh" "$rm")"; else mp_reset_str="$(printf '%dm' "$rm")"; fi
    fi
fi

# Cost for the 💸 segment — ¢ under $1, $X.XX at $1+.
cost_cents="$(printf '%.0f' "$(echo "${cost_usd:-0} * 100" | bc -l 2>/dev/null || echo 0)" 2>/dev/null || echo 0)"
if [ "${cost_cents:-0}" -ge 100 ]; then
    cost_label="$(printf '$%.2f' "${cost_usd:-0}")"
else
    cost_label="${cost_cents}¢"
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

# 💰 honesty: a present 5h budget means a quota plan, where the dollar figure is
# notional (API-equivalent), not real spend — mark with ~ and mute it so MP reads as
# the real currency. No budget field (API pay-go likely) → real spend → keep vivid.
if [ "$mp_known" -eq 1 ]; then
    cost_color="$DIMGOLD"; cost_prefix="~"
else
    cost_color="$GOLD"; cost_prefix=""
fi

# Low-HP warning glyph
hp_icon="❤️ "
[ "$hp_pct" -lt 15 ] && hp_icon="💔"

# ----- Compose statusline -------------------------------------------------
# Single-space discipline: segments are divided by a dim │ with exactly one
# space on each side, so no run of >1 space appears anywhere on the line.
SEP=" ${DIM}${GREY}│${RESET} "

# Map the model to a DnD-style class + emoji. Claude tiers get themed classes;
# the major outside vendors each get their own class; unknown → MERCENARY.
# Sets two globals: class_icon (party-sheet glyph) and class_short (the name).
# o-series uses the trailing dash (o3-) so bare "o1"/"o3" can't false-match an id/hash.
class_icon="🗿"
class_short="MERCENARY"
class_for_model() {
    local hay
    hay="$(printf '%s %s' "$model_id" "$model_name" | tr '[:upper:]' '[:lower:]')"
    case "$hay" in
        *opus*)                   class_icon="🧙"; class_short="ARCHMAGE"  ;; # deepest reasoning → arcane elder
        *sonnet*)                 class_icon="🪄"; class_short="WIZARD"    ;; # best all-round coder → trained mage
        *haiku*)                  class_icon="🗡️"; class_short="ROGUE"     ;; # fast & cheap → nimble striker
        *fable*)                  class_icon="🎵"; class_short="BARD"      ;; # creative/storyteller → performer
        *gpt*|*openai*|*o1-*|*o3-*|*o4-*) class_icon="😈"; class_short="WARLOCK" ;; # power via an outside patron
        *gemini*)                 class_icon="🏹"; class_short="RANGER"    ;; # broad-reach search/tooling → tracker
        *llama*)                  class_icon="🌿"; class_short="DRUID"     ;; # open/wild weights → nature shifter
        *mistral*|*mixtral*)      class_icon="🛡️"; class_short="PALADIN"   ;; # French chivalry → oath-bound knight
        *grok*)                   class_icon="🪓"; class_short="BARBARIAN" ;; # brash & edgy → rage fighter
        *deepseek*)               class_icon="🌀"; class_short="MONK"      ;; # the deep seeker → disciplined ascetic
        *qwen*)                   class_icon="📖"; class_short="CLERIC"    ;; # steady support model → faith healer
        *claude*)                 class_icon="🎲"; class_short="ADVENTURER";; # unrecognized Claude → generic hero
        *)                        class_icon="🏴‍☠️"; class_short="MERCENARY" ;; # unknown vendor → hired sword
    esac
}
class_for_model

printf '%s%s %sLv.%s%s' "$PURPLE" "$class_icon" "$BOLD" "$class_short" "$RESET"
printf '%s' "$SEP"
printf '%s%s%s%sHP%s %s %s%d%%%s' \
    "$RED" "$hp_icon" "$RESET" "$BOLD" "$RESET" \
    "$(render_bar "$hp_pct" "$hp_color")" "$hp_color" "$hp_pct" "$RESET"
printf '%s' "$SEP"
if [ "$mp_known" -eq 1 ]; then
    printf '%s🔮 %sMP%s %s %s%d%%%s' \
        "$CYAN" "$BOLD" "$RESET" \
        "$(render_bar "$mp_pct" "$mp_color")" "$mp_color" "$mp_pct" "$RESET"
    [ -n "$mp_reset_str" ] && printf ' %s⟳%s%s' "$DIM" "$mp_reset_str" "$RESET"
else
    printf '%s🔮 %sMP%s %s %s??%%%s' \
        "$CYAN" "$BOLD" "$RESET" \
        "$(render_bar 0 "$GREY")" "$GREY" "$RESET"
fi
printf '%s' "$SEP"
printf '%s💸 %s%s%s' "$cost_color" "$cost_prefix" "$cost_label" "$RESET"
printf '%s' "$SEP"
printf '%s⚔️ +%s%s%s/%s-%s%s\n' "$GREEN" "$lines_added" "$RESET" "$GREY" "$RED" "$lines_removed" "$RESET"

# ----- Second line: location, git, runtimes --------------------------------
# ~-relative path, tail-truncated so a deep tree never blows the line out.
shorten_path() {
    local p="$1" max=30
    case "$p" in "$HOME"/*|"$HOME") p="~${p#"$HOME"}" ;; esac
    [ "${#p}" -gt "$max" ] && p="…${p: -$max}"
    printf '%s' "$p"
}

# Append a token to the git-status string with single-space separation.
gs_tokens=""
add_tok() {
    if [ -n "$gs_tokens" ]; then gs_tokens="$gs_tokens $1"; else gs_tokens="$1"; fi
}

branch="" ; is_worktree=0 ; git_status=""
if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    # A linked worktree's git-dir always lives under <repo>/.git/worktrees/<name>.
    gd="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null || true)"
    case "$gd" in */worktrees/*) is_worktree=1 ;; esac
    # Detailed status, suffixed onto the branch insight:
    #   +N staged · !N unstaged · ?N untracked · ↑N ahead · ↓N behind · ✓ clean
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

    if [ -n "$gs_tokens" ]; then
        git_status=" $gs_tokens"
    else
        git_status="$(printf ' %s✓%s' "$M_SAGE" "$RESET")"
    fi
fi

py="" ; node=""
command -v python3 >/dev/null 2>&1 && py="$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2 || true)"
command -v node >/dev/null 2>&1 && node="$(node --version 2>&1 | sed 's/^v//' | cut -d. -f1,2 || true)"

# RPG-style location icon: the main repo is your castle, a worktree is an
# outlying hut. Both are single-codepoint glyphs (no variation selector) so
# they don't break the single-space rule.
dir_icon="🏰"
[ "$is_worktree" -eq 1 ] && dir_icon="🛖"

segs=()
segs+=("$(printf '%s%s %s%s' "$M_SLATE" "$dir_icon" "$(shorten_path "$cwd")" "$RESET")")
[ -n "$branch" ] && segs+=("$(printf '%s🌿 %s%s%s' "$M_SAGE" "$branch" "$RESET" "$git_status")")
[ -n "$py" ]     && segs+=("$(printf '%s🐍 %s%s' "$M_TAN" "$py" "$RESET")")
[ -n "$node" ]   && segs+=("$(printf '%s⬢ %s%s' "$M_MOSS" "$node" "$RESET")")

line2=""
for s in "${segs[@]}"; do
    [ -n "$line2" ] && line2="${line2}${SEP}"
    line2="${line2}${s}"
done
printf '%s\n' "$line2"
