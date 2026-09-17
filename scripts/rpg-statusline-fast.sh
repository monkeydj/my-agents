#!/usr/bin/env bash
# rpg-statusline-fast.sh — Retro RPG statusline for Claude Code (fork-optimized)
#
# Same rendering as rpg-statusline.sh with one deliberate exception — in a repo
# with no commits yet this shows the real branch name (main) where the old
# script showed "HEAD", because `status -b` names an unborn branch and
# `rev-parse --abbrev-ref HEAD` does not.
#
# ~7 subprocesses per render instead of ~74 (156ms -> 52ms):
#   • one jq call extracts every payload field (was 14 separate jq pipelines)
#   • one `git status --porcelain -b` supplies branch, ahead/behind and file counts
#     (was 5 git calls + 3 greps + 2 awks), counted in a pure-bash loop
#   • bars, paths and durations assign to globals instead of running in $( ) subshells
#   • model version parsed with bash regex, not grep+awk
#   • runtime versions probed only when they will actually be drawn
#
# ❤️  HP   = context window remaining (.context_window; transcript fallback)
# 🔮 MP   = 5h rate-limit budget left (.rate_limits.five_hour); ??% when absent, never faked full
# 💰 Gold = 7-day rate-limit budget remaining; 󰑐 = reset in; ??% when absent, never faked full
# 🕯️🧨🔥💥🌋 Buff = reasoning-effort power-up after class level, tier number + heat bar (E1→E5); JSON tier else $MAX_THINKING_TOKENS bucket; hidden when neither present
# 📏 Gates = NARROW_COLS (drop runtimes + path) and TINY_COLS (also drop bars + resets)
# 📜 Log  = every statusline payload appended as JSONL to /tmp/statusline.log for monitoring
#
# settings.json: "statusLine": { "type": "command", "command": "~/.claude/scripts/rpg-statusline-fast.sh" }
# Input: JSON object on stdin (statusline contract). Requires bash 3.2+ (macOS stock) and jq.

set -euo pipefail

# ----- Config -------------------------------------------------------------
BAR_WIDTH=10
DEFAULT_CTX_WINDOW=200000    # standard context window, tokens

NARROW_COLS=${NARROW_COLS:-120}   # below this: drop runtimes + path
TINY_COLS=${TINY_COLS:-75}        # below this: also drop every bar and reset countdown

US=$'\037'   # unit separator: field delimiter for the single jq extraction

# ----- Terminal width -----------------------------------------------------
# The statusline payload carries no width, and our stdout is captured (not a
# tty), so tput would only report its 80-column fallback. The real size comes
# from the tty device owned by the parent claude process. 0 = undetectable,
# which keeps the full layout rather than guessing narrow.
cols="${COLUMNS:-0}"
case "$cols" in ''|*[!0-9]*) cols=0 ;; esac
if [ "$cols" -eq 0 ]; then
    tty_dev="$(ps -o tty= -p "$PPID" 2>/dev/null || true)"
    tty_dev="${tty_dev// /}"
    case "$tty_dev" in
        ''|'??') : ;;
        *)  size="$(stty -f "/dev/$tty_dev" size 2>/dev/null || true)"
            cols="${size#* }"                       # "rows cols" → cols
            case "$cols" in ''|*[!0-9]*) cols=0 ;; esac ;;
    esac
fi
narrow=0
tiny=0
if [ "$cols" -gt 0 ] && [ "$cols" -lt "$NARROW_COLS" ]; then narrow=1; fi
if [ "$cols" -gt 0 ] && [ "$cols" -lt "$TINY_COLS" ]; then narrow=1; tiny=1; fi

# ----- Resolve Claude config directory (once) -------------------------------
# Expects <claude-dir>/scripts/rpg-statusline-fast.sh so the grandparent is the
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

# ----- One jq pass for every payload field --------------------------------
# Percentages are rounded and the effort tier lowercased inside jq, so bash
# needs no follow-up printf/tr subshells. Fields are joined with US (0x1f),
# a non-whitespace delimiter, so `read` preserves empty fields instead of
# collapsing them the way a tab or newline delimiter would.
fields="$(printf '%s' "$input" | jq -r '
    def s: if . == null then "" else tostring end;
    # tonumber? also accepts a percentage sent as a JSON string ("37"), which
    # the old printf %.0f path handled; non-numeric falls through to "".
    def pct: (tonumber? // "") | if type == "number" then (round|tostring) else "" end;
    [ (.model.display_name // .model.id // "Adventurer")
    , (.model.id // "")
    , (.transcript_path // "")
    , (.cost.total_lines_added // 0)
    , (.cost.total_lines_removed // 0)
    , (if .exceeds_200k_tokens then "1" else "0" end)
    , (.workspace.current_dir // .cwd // "")
    , (.context_window.used_percentage | pct)
    , (.context_window.context_window_size // .context_window.total_tokens // "")
    , (.rate_limits.five_hour.used_percentage | pct)
    , (.rate_limits.five_hour.resets_at // "")
    , (.rate_limits.seven_day.used_percentage | pct)
    , (.rate_limits.seven_day.resets_at // "")
    , ((.reasoning_effort // (if (.effort|type) == "object" then .effort.level else .effort end) // "") | s | ascii_downcase)
    ] | map(s | gsub("[\\r\\n]"; " ")) | join("")
' 2>/dev/null || true)"

IFS="$US" read -r model_name model_id transcript lines_added lines_removed \
    exceeds_200k cwd ctx_used_pct ctx_size_in five_used five_reset \
    seven_used seven_reset effort_tier <<< "$fields" || true

[ -z "${model_name:-}" ] && model_name="Adventurer"
[ -z "${lines_added:-}" ] && lines_added=0
[ -z "${lines_removed:-}" ] && lines_removed=0
[ -z "${cwd:-}" ] && cwd="$PWD"

# Numeric guards: anything non-integer is treated as absent rather than fed to
# $(( )), which would abort the whole statusline under `set -e`.
for v in ctx_size_in ctx_used_pct five_used five_reset seven_used seven_reset; do
    eval "case \"\${$v:-}\" in ''|*[!0-9]*) $v='' ;; esac"
done

# ----- Context window size (1M models carry "[1m]" in the id) ------------
ctx_window=$DEFAULT_CTX_WINDOW
case "$model_id" in
    *"[1m]"*|*"1m"*) ctx_window=1000000 ;;
esac
[ "$exceeds_200k" = "1" ] && [ "$ctx_window" -lt 1000000 ] && ctx_window=1000000
[ -n "$ctx_size_in" ] && ctx_window="$ctx_size_in"
[ "$ctx_window" -le 0 ] && ctx_window=$DEFAULT_CTX_WINDOW

# ----- HP: context remaining ---------------------------------------------
# Prefer statusline's used_percentage; else sum latest transcript usage.
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
    case "$ctx_used" in ''|*[!0-9]*) ctx_used=0 ;; esac
    ctx_used_pct=$(( ctx_used * 100 / ctx_window ))
fi

# HP = % context still free (filling context = damage).
hp_pct=$(( 100 - ctx_used_pct ))
[ "$hp_pct" -lt 0 ] && hp_pct=0
[ "$hp_pct" -gt 100 ] && hp_pct=100

# ----- MP / Gold: rate-limit budget remaining -----------------------------
# From .rate_limits.*. Absent → mark unknown, never fake a full bar.
mp_known=1; mp_pct=0
if [ -n "$five_used" ]; then
    mp_pct=$(( 100 - five_used ))
    [ "$mp_pct" -lt 0 ] && mp_pct=0
    [ "$mp_pct" -gt 100 ] && mp_pct=100
else
    mp_known=0
fi

gold_known=1; gold_pct=0
if [ -n "$seven_used" ]; then
    gold_pct=$(( 100 - seven_used ))
    [ "$gold_pct" -lt 0 ] && gold_pct=0
    [ "$gold_pct" -gt 100 ] && gold_pct=100
else
    gold_known=0
fi

# set_duration <seconds> → DUR = "2d4h" / "3h12m" / "45m"; "stale" if <=0.
# Assigns instead of printing so the two countdowns cost no subshell.
set_duration() {
    local s="$1" d h m
    if [ "$s" -le 0 ]; then DUR='stale'; return; fi
    d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 )); m=$(( (s % 3600) / 60 ))
    if   [ "$d" -gt 0 ]; then DUR="${d}d${h}h"
    elif [ "$h" -gt 0 ]; then DUR="${h}h${m}m"
    else DUR="${m}m"; fi
}

# Countdowns to the next resets; one `date` call covers both.
mp_reset_str=""
gold_reset_str=""
if [ -n "$five_reset" ] || [ -n "$seven_reset" ]; then
    now="$(date +%s)"
    if [ -n "$five_reset" ]; then set_duration $(( five_reset - now )); mp_reset_str="$DUR"; fi
    if [ -n "$seven_reset" ]; then set_duration $(( seven_reset - now )); gold_reset_str="$DUR"; fi
fi

# ----- Bar renderer -------------------------------------------------------
# set_bar <pct> <color> → BAR = "[████░░░░░░] " (trailing space), empty when
# tiny so the percentage sits straight after the label. Built by loop rather
# than substring slicing, which is byte-based under a non-UTF-8 locale.
set_bar() {
    local pct="$1" color="$2" filled empty i b="" e=""
    if [ "$tiny" -eq 1 ]; then BAR=""; return; fi
    filled=$(( (pct * BAR_WIDTH + 50) / 100 ))
    [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
    [ "$filled" -lt 0 ] && filled=0
    empty=$(( BAR_WIDTH - filled ))
    for (( i=0; i<filled; i++ )); do b+="█"; done
    for (( i=0; i<empty; i++ )); do e+="░"; done
    BAR="${GREY}[${color}${b}${DIM}${e}${RESET}${GREY}]${RESET} "
}

# Health-style color: green high → red low. Assigns HEALTH_COLOR.
set_health_color() {
    if   [ "$1" -ge 60 ]; then HEALTH_COLOR="$GREEN"
    elif [ "$1" -ge 30 ]; then HEALTH_COLOR="$YELLOW"
    elif [ "$1" -ge 15 ]; then HEALTH_COLOR="$ORANGE"
    else HEALTH_COLOR="$RED"; fi
}

set_health_color "$hp_pct"; hp_color="$HEALTH_COLOR"
mp_color="$BLUE"
[ "$mp_pct" -lt 30 ] && mp_color="$PURPLE"
[ "$mp_known" -eq 0 ] && mp_color="$GREY"

set_health_color "$gold_pct"; gold_color="$HEALTH_COLOR"
[ "$gold_known" -eq 0 ] && gold_color="$GREY"

# Low-HP warning glyph
hp_icon="❤️ "
[ "$hp_pct" -lt 42 ] && hp_icon="💔"

# ----- Compose statusline -------------------------------------------------
# Segments divided by a dim │ with one space each side (no run of >1 space).
SEP=" ${DIM}${GREY}│${RESET} "

# Map model → DnD class + emoji; unknown → MERCENARY. Sets class_icon, class_short.
# nocasematch replaces the old tr-to-lowercase fork.
# o-series matched with trailing dash (o3-) so bare "o1"/"o3" can't false-match a hash.
shopt -s nocasematch
case "$model_id $model_name" in
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
shopt -u nocasematch

# Model version → RPG "level" (Opus 4.8 → lv.4.8): dotted 4.8, then dash 4-5→4.5, else major 5.
# Ordered so a trailing date suffix (…-20251001) can't win over the real version.
# bash regex replaces three grep forks; BASH_REMATCH is the leftmost match, same as grep|head -1.
ver_hay="$model_name $model_id"
model_level=""
if   [[ $ver_hay =~ ([0-9]+)\.([0-9]+) ]]; then model_level="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
elif [[ $ver_hay =~ ([0-9]+)-([0-9]+) ]];  then model_level="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
elif [[ $ver_hay =~ ([0-9]+) ]];           then model_level="${BASH_REMATCH[1]}"
fi

# x10 → integer level (4.8→48, 5→50). 10# forces decimal so "08" can't be read as octal.
if [ -n "$model_level" ]; then
    case "$model_level" in
        *.*) mv_i="${model_level%%.*}"; mv_f="${model_level#*.}"
             model_level=$(( 10#$mv_i * 10 + 10#${mv_f:0:1} )) ;;
        *)   model_level=$(( 10#$model_level * 10 )) ;;
    esac
else
    model_level="??"
fi

# ----- Git (computed before line 1 — status tokens on line 1, branch on line 2) ---
# One `status --porcelain -b` supplies branch, upstream divergence and file
# states; counting them in bash replaces three grep forks and a rev-list.
branch=""; is_worktree=0; gs_tokens=""
staged=0; unstaged=0; untracked=0; ahead=0; behind=0
if command -v git >/dev/null 2>&1; then
    gd="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null || true)"
    if [ -n "$gd" ]; then
        case "$gd" in */worktrees/*) is_worktree=1 ;; esac
        porc="$(git -C "$cwd" status --porcelain=v1 -b 2>/dev/null || true)"
        head_line=""
        while IFS= read -r l; do
            case "$l" in
                '## '*) head_line="${l#\#\# }" ;;
                '??'*)  untracked=$(( untracked + 1 )) ;;
                '')     ;;
                *)      case "$l" in [MADRC]*) staged=$(( staged + 1 )) ;; esac
                        case "$l" in ?[MD]*)   unstaged=$(( unstaged + 1 )) ;; esac ;;
            esac
        done <<< "$porc"

        # "## main...origin/main [ahead 1, behind 2]" / "## main" /
        # "## HEAD (no branch)" / "## No commits yet on main"
        branch="$head_line"
        case "$branch" in 'No commits yet on '*) branch="${branch#No commits yet on }" ;; esac
        div=""
        case "$branch" in
            *' ['*']') div="${branch##*[}"; div="${div%]}"; branch="${branch%% [*}" ;;
        esac
        branch="${branch%%...*}"
        case "$branch" in 'HEAD (no branch)') branch="HEAD" ;; esac
        case "$div" in *'ahead '*)  n="${div#*ahead }";  ahead="${n%%,*}" ;; esac
        case "$div" in *'behind '*) n="${div#*behind }"; behind="${n%%,*}" ;; esac
        case "$ahead"  in ''|*[!0-9]*) ahead=0 ;; esac
        case "$behind" in ''|*[!0-9]*) behind=0 ;; esac

        add_tok() { if [ -n "$gs_tokens" ]; then gs_tokens="$gs_tokens $1"; else gs_tokens="$1"; fi; }
        [ "$staged" -gt 0 ]    && add_tok "${M_SAGE}+${staged}${RESET}"
        [ "$unstaged" -gt 0 ]  && add_tok "${M_TAN}!${unstaged}${RESET}"
        [ "$untracked" -gt 0 ] && add_tok "${GREY}?${untracked}${RESET}"
        [ "$ahead" -gt 0 ]     && add_tok "${M_TEAL}↑${ahead}${RESET}"
        [ "$behind" -gt 0 ]    && add_tok "${M_LAVENDER}↓${behind}${RESET}"
    fi
fi

# ----- Line 1: vitals — lines-changed → HP → MP → Gold → langs -------------
printf '%s⚔️ +%s%s%s/%s-%s%s' "$GREEN" "$lines_added" "$RESET" "$GREY" "$RED" "$lines_removed" "$RESET"
printf '%s' "$SEP"
set_bar "$hp_pct" "$hp_color"
printf '%s%s%s%sHP%s %s%s%d%%%s' \
    "$RED" "$hp_icon" "$RESET" "$BOLD" "$RESET" \
    "$BAR" "$hp_color" "$hp_pct" "$RESET"
printf '%s' "$SEP"
if [ "$mp_known" -eq 1 ]; then
    set_bar "$mp_pct" "$mp_color"
    printf '%s🔮 %sMP%s %s%s%d%%%s' \
        "$CYAN" "$BOLD" "$RESET" \
        "$BAR" "$mp_color" "$mp_pct" "$RESET"
    if [ "$tiny" -eq 0 ] && [ -n "$mp_reset_str" ]; then
        printf ' %s󰑐%s%s' "$DIM" "$mp_reset_str" "$RESET"
    fi
else
    set_bar 0 "$GREY"
    printf '%s🔮 %sMP%s %s%s??%%%s' \
        "$CYAN" "$BOLD" "$RESET" \
        "$BAR" "$GREY" "$RESET"
fi
printf '%s' "$SEP"
if [ "$gold_known" -eq 1 ]; then
    set_bar "$gold_pct" "$gold_color"
    printf '%s💰 %sGold%s %s%s%d%%%s' \
        "$GOLD" "$BOLD" "$RESET" \
        "$BAR" "$gold_color" "$gold_pct" "$RESET"
    if [ "$tiny" -eq 0 ] && [ -n "$gold_reset_str" ]; then
        printf ' %s󰑐%s%s' "$DIM" "$gold_reset_str" "$RESET"
    fi
else
    set_bar 0 "$GREY"
    printf '%s💰 %sGold%s %s%s??%%%s' \
        "$GOLD" "$BOLD" "$RESET" \
        "$BAR" "$GREY" "$RESET"
fi
# Runtime versions are probed here, not earlier, so a narrow terminal pays
# nothing for versions it will not draw. Parameter expansion replaces awk/cut/sed.
# ponytail: these two probes are ~19ms of the ~52ms render — the largest cost
# left. Cache them in a mtime-checked file only if the render ever feels slow.
if [ "$narrow" -eq 0 ]; then
    if command -v python3 >/dev/null 2>&1; then
        v="$(python3 --version 2>&1 || true)"; v="${v##* }"   # "Python 3.13.1" → "3.13.1"
        [ -n "$v" ] && printf '%s%s🐍 %s%s' "$SEP" "$M_PYTHON" "${v%.*}" "$RESET"
    fi
    if command -v node >/dev/null 2>&1; then
        v="$(node --version 2>&1 || true)"; v="${v#v}"        # "v22.1.0" → "22.1.0"
        [ -n "$v" ] && printf '%s%s🕷️ %s%s' "$SEP" "$M_MOSS" "${v%.*}" "$RESET"
    fi
fi
printf '\n'

# ----- Line 2: context — class → dir → git-tokens → branch -----------------
dir_icon="🏰"
[ "$is_worktree" -eq 1 ] && dir_icon="🛖"

# ----- Effort buff: RPG power-up aura from the reasoning-effort tier -------
# Source order (never fabricated): explicit tier in the statusline JSON (already
# read above), else $CLAUDE_EFFORT, else effortLevel in settings.json colocated
# with this script (no env-passthrough dependency), else bucket
# $MAX_THINKING_TOKENS into tiers. None present → no buff rendered.
if [ -z "$effort_tier" ]; then
    effort_tier="${CLAUDE_EFFORT:-}"
    # bash 3.2 has no ${var,,}; the tier set is ASCII and matched case-insensitively below.
fi
if [ -z "$effort_tier" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
    # Prefer the per-model override /effort actually writes to
    # (modelSettings.<model-id-prefix>.effortLevel); fall back to the global
    # top-level effortLevel only when no per-model entry matches. One jq call
    # covers both lookups.
    effort_tier="$(jq -r --arg mid "$model_id" '
        (((.modelSettings // {}) | to_entries | map(select($mid | startswith(.key))) | .[0].value.effortLevel)
         // .effortLevel // "") | ascii_downcase
    ' "$CLAUDE_DIR/settings.json" 2>/dev/null || true)"
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
shopt -s nocasematch
case "$effort_tier" in
    low)    effort_n=1; effort_icon="🕯️"; effort_color="$DIMGOLD" ;;
    medium) effort_n=2; effort_icon="🧨"; effort_color="$YELLOW" ;;
    high)   effort_n=3; effort_icon="🔥"; effort_color="$ORANGE" ;;
    xhigh)  effort_n=4; effort_icon="💥"; effort_color="$RED" ;;
    max)    effort_n=5; effort_icon="🌋"; effort_color="$GOLD" ;;
esac
shopt -u nocasematch
if [ "$effort_n" -gt 0 ]; then
    if [ "$tiny" -eq 1 ]; then
        effort_buff="${effort_color}${effort_icon}${BOLD}E${effort_n}${RESET}"
    else
        ebar=""
        for (( i=1; i<=5; i++ )); do
            if [ "$i" -le "$effort_n" ]; then ebar+="${effort_color}▮"; else ebar+="${DIM}▯"; fi
        done
        effort_buff="${effort_color}${effort_icon}${BOLD}E${effort_n}${RESET} ${ebar}${RESET}"
    fi
fi

line2="${PURPLE}${class_icon} ${BOLD}${class_short}${RESET} ${DIM}${PURPLE}lv.${model_level}${RESET}${effort_buff:+ $effort_buff}"

if [ "$narrow" -eq 0 ]; then
    p="$cwd"
    case "$p" in "$HOME"/*|"$HOME") p="~${p#"$HOME"}" ;; esac
    [ "${#p}" -gt 30 ] && p="…${p: -30}"
    line2="${line2}${SEP}${M_SLATE}${dir_icon} ${p}${RESET}"
fi

if [ -n "$branch" ]; then
    branch_color="$M_SAGE"
    [ $(( staged + unstaged + untracked )) -gt 0 ] && branch_color="$M_RUST"
    if [ -n "$gs_tokens" ]; then
        line2="${line2}${SEP}${branch_color}🌿 ${gs_tokens} ${branch}${RESET}"
    else
        line2="${line2}${SEP}${branch_color}🌿 ${branch}${RESET}"
    fi
fi

printf '%s\n' "$line2"
