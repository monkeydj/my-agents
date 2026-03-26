#!/usr/bin/env bash
# =============================================================================
# Claude Code Status Line — One-liner Session Monitor with Pac-Man Bar
# =============================================================================
# Dependencies: jq, bc
#
# ⎇ branch  ~/path  [pac-man bar]  ctx:43%  ᗩ5h:82%↓3h  ᗩ7d:62%↓3d  ↓in/↑out  Model@session  ⇌ iface ip
# =============================================================================

set -euo pipefail

# Check dependencies
command -v jq >/dev/null 2>&1 || { echo "Error: jq required" >&2; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "Error: bc required" >&2; exit 1; }

input=$(cat)

# =============================================================================
# SECTION: Pac-Man Animation State
# =============================================================================
# Toggles between mouth open/closed for animation effect
CHOMP_FILE="/tmp/.claude-pacman-chomp"
if [ -f "$CHOMP_FILE" ] && [ "$(cat "$CHOMP_FILE")" = "1" ]; then
  PAC_CHAR="●"; G1_CHAR="ᗩ"; G2_CHAR="ᗣ"; echo "0" > "$CHOMP_FILE"
else
  PAC_CHAR="ᗧ"; G1_CHAR="ᗣ"; G2_CHAR="ᗩ"; echo "1" > "$CHOMP_FILE"
fi

# =============================================================================
# SECTION: Color Definitions
# =============================================================================
# B=Blue, Y=Yellow, R=Red, P=Purple, O=Orange, W=White, GRY=Gray, CYN=Cyan
# DIM=Dim, BLD=Bold, NC=No Color
B='\033[38;5;27m'; Y='\033[1;33m'; R='\033[1;31m'; P='\033[1;35m'
O='\033[38;5;208m'; W='\033[0;37m'; DIM='\033[2m'; NC='\033[0m'
GRY='\033[0;90m'; CYN='\033[0;36m'; BLD='\033[1;37m'

# =============================================================================
# SECTION: Parse JSON Input
# =============================================================================
ctx_pct=$(echo "$input"    | jq -r '.context_window.used_percentage // "0"')
five_pct=$(echo "$input"   | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input"   | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
model=$(echo "$input"      | jq -r 'if .model | type == "object" then (.model.display_name // .model.id // empty) | gsub("\\s*\\(.*\\)"; "") else .model // empty end')
ctx_total=$(echo "$input"  | jq -r '.context_window.context_window_size // .context_window.total_tokens // empty')
cwd=$(echo "$input"        | jq -r '.workspace.current_dir // .cwd // ""')
in_tokens=$(echo "$input"  | jq -r '.context_window.total_input_tokens // 0')
out_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
session_full=$(echo "$input" | jq -r '.session_id // ""')
session="${session_full:0:8}"

# Convert percentages to integers
ctx_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo 0)
five_int=$(printf "%.0f" "${five_pct:-0}" 2>/dev/null || echo 0)
week_int=$(printf "%.0f" "${week_pct:-0}" 2>/dev/null || echo 0)

# =============================================================================
# SECTION: Helper Functions
# =============================================================================

# Format Unix timestamp to human-readable countdown (e.g., "2d3h", "4h30m")
fmt_reset() {
  local ts="$1"; [ -z "$ts" ] && return
  local now; now=$(date +%s); local diff=$(( ts - now ))
  if (( diff <= 0 )); then printf "now"; return; fi
  local d=$(( diff / 86400 )) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  if (( d > 0 )); then printf "%dd%dh" "$d" "$h"
  elif (( h > 0 )); then printf "%dh%dm" "$h" "$m"
  else printf "%dm" "$m"; fi
}

# Color percentage based on urgency: <=20% red, <=50% yellow, else white
colour_remain() {
  local remain="$1"
  if   (( remain <= 20 )); then printf "\033[1;31m%d%%\033[0m" "$remain"
  elif (( remain <= 50 )); then printf "\033[1;33m%d%%\033[0m" "$remain"
  else printf "\033[0;37m%d%%\033[0m" "$remain"; fi
}

# Format large token counts: 1M+ = "1.5M", 1K+ = "1.2K", else raw number
fmt_tokens() {
  local t="$1"; [ -z "$t" ] && return
  if (( t >= 1000000000 )); then printf "%.1fG" "$(echo "$t / 1000000000" | bc -l)"
  elif (( t >= 1000000 )); then printf "%dM" $(( t / 1000000 ))
  elif (( t >= 1000 )); then printf "%.1fK" "$(echo "$t / 1000" | bc -l)"
  else printf "%d" "$t"; fi
}

# =============================================================================
# SECTION: Network Interface Detection
# =============================================================================
# Supports macOS (route, ipconfig) and Linux (ip route)
net_iface=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
if [ -z "$net_iface" ]; then
  net_iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
fi
net_ip=""
if [ -n "$net_iface" ]; then
  net_ip=$(ipconfig getifaddr "$net_iface" 2>/dev/null)
  if [ -z "$net_ip" ]; then
    net_ip=$(ip -4 addr show "$net_iface" 2>/dev/null | awk '/inet /{gsub(/\/.*/, "", $2); print $2; exit}')
  fi
fi

net_plain=""; net_colored=""
if [ -n "$net_iface" ]; then
  net_plain="⇌ ${net_iface}"
  [ -n "$net_ip" ] && net_plain+=" ${net_ip}"
  # VPN interfaces: utun*, tun*, wg*, ppp*, tailscale*
  case "$net_iface" in
    utun*|tun*|wg*|ppp*|tailscale*)
      net_colored="${O}⇌ ${net_iface}${NC}"
      [ -n "$net_ip" ] && net_colored+=" ${DIM}${net_ip}${NC}"
      ;;
    *)
      net_colored="${CYN}⇌ ${net_iface}${NC}"
      [ -n "$net_ip" ] && net_colored+=" ${DIM}${net_ip}${NC}"
      ;;
  esac
fi

# =============================================================================
# SECTION: Git Info & Path
# =============================================================================
short_cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

repo=""; branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# =============================================================================
# SECTION: Width Budget & Segment Planning
# =============================================================================
TERM_W=$(tput cols 2>/dev/null || echo 80)

# Calculate remaining percentages
ctx_remain=$(( 100 - ctx_int )); (( ctx_remain < 0 )) && ctx_remain=0
five_remain=$(( 100 - five_int )); (( five_remain < 0 )) && five_remain=0
week_remain=$(( 100 - week_int )); (( week_remain < 0 )) && week_remain=0
five_rs=$(fmt_reset "$five_reset")
week_rs=$(fmt_reset "$week_reset")

# Right-side segments in plain text (for length measurement only)
in_fmt=$(fmt_tokens "$in_tokens"); out_fmt=$(fmt_tokens "$out_tokens")
tokens_plain="↓${in_fmt}/↑${out_fmt}"

stats_plain="ctx:${ctx_remain}%"
[ -n "$five_pct" ] && { stats_plain+="  ᗩ5h:${five_remain}%"; [ -n "$five_rs" ] && stats_plain+="↓${five_rs}"; }
[ -n "$week_pct" ] && { stats_plain+="  ᗩ7d:${week_remain}%"; [ -n "$week_rs" ] && stats_plain+="↓${week_rs}"; }

model_session_plain="${model:-}@${session}"

# Right side total: 4 segments (stats tokens model_session net) + separators
# 3 separators between them (2 chars each) + 2 chars gap before bar = 8 total
right_fixed=$(( ${#stats_plain} + ${#tokens_plain} + ${#model_session_plain} + ${#net_plain} + 8 ))

# Left budget for: branch + separator + path + separator + bar
left_budget=$(( TERM_W - right_fixed ))
(( left_budget < 30 )) && left_budget=30

# Branch: cap at 35 visible chars (⎇ + space + name)
branch_display=""
branch_plain=""
if [ -n "$branch" ]; then
  if (( ${#branch} > 33 )); then
    branch_display="${branch:0:32}…"
  else
    branch_display="$branch"
  fi
  branch_plain="⎇ ${branch_display}"
fi

# Separator cost only if branch is present
branch_sep=0; (( ${#branch_plain} > 0 )) && branch_sep=2

# Path: remaining after branch + separator, preserving min 10 chars for bar + separator
path_budget=$(( left_budget - ${#branch_plain} - branch_sep - 10 - 2 ))
(( path_budget < 5 )) && path_budget=5
if [ -n "$short_cwd" ] && (( ${#short_cwd} > path_budget )); then
  short_cwd="…${short_cwd: -$(( path_budget - 1 ))}"
fi

# Bar width: whatever remains after branch + path + their separators
bar_w=$(( left_budget - ${#branch_plain} - branch_sep - ${#short_cwd} - 2 ))
(( bar_w < 10 )) && bar_w=10

MAP_W=$bar_w

# =============================================================================
# SECTION: Game State
# =============================================================================
# Legend: Pac-Man (ᗧ/●) = context usage, Ghost ᗩ(red) = 5h rate, Ghost ᗣ(purple) = 7d rate
PAC_MIN=5
(( PAC_MIN >= MAP_W )) && PAC_MIN=$(( MAP_W / 3 ))
pac_pos=$(( PAC_MIN + ctx_int * (MAP_W - 1 - PAC_MIN) / 100 ))
(( pac_pos < PAC_MIN )) && pac_pos=$PAC_MIN
(( pac_pos >= MAP_W )) && pac_pos=$(( MAP_W - 1 ))

g1=-1; g2=-1; game_over=0
g2_caged=0

if [ -n "$five_pct" ]; then
  if (( five_int >= 100 )); then g1=$pac_pos; game_over=1
  else g1_pending=$five_int; fi
fi

if [ -n "$week_pct" ]; then
  if (( week_remain > 50 )); then g2_caged=1; fi
  if (( g2_caged == 0 )); then
    if (( week_int >= 100 )); then g2=$pac_pos; game_over=1
    else g2_pending=$week_int; fi
  fi
fi

ROOM_W=0
if (( g2_caged )); then
  ROOM_W=5
  (( pac_pos < ROOM_W )) && pac_pos=$ROOM_W
fi

if [ -n "${g1_pending:-}" ]; then
  g1_start=$ROOM_W
  g1=$(( g1_start + g1_pending * (pac_pos - g1_start) / 100 ))
fi
if [ -n "${g2_pending:-}" ]; then
  g2=$(( week_int * pac_pos / 100 ))
fi

if (( game_over == 0 )); then
  (( g1 >= 0 && g1 >= pac_pos && pac_pos > 0 )) && g1=$(( pac_pos - 1 ))
  (( g2 >= 0 && g2 >= pac_pos && pac_pos > 0 )) && g2=$(( pac_pos - 1 ))
fi
if (( g1 >= 0 && g2 >= 0 && g1 == g2 )); then
  if (( five_int <= week_int )); then (( g1 > 0 )) && ((g1--))
  else (( g2 > 0 )) && ((g2--)); fi
fi
if (( game_over == 0 )); then
  (( g1 >= 0 && g1 == pac_pos && pac_pos > 0 )) && g1=$(( pac_pos - 1 ))
  (( g2 >= 0 && g2 == pac_pos && pac_pos > 0 )) && g2=$(( pac_pos - 1 ))
fi

# =============================================================================
# SECTION: Build Pac-Man Bar
# =============================================================================
go_text=" GAME OVER"
go_start=-1
if (( game_over )); then
  go_start=$(( pac_pos + 1 ))
  if (( go_start + ${#go_text} > MAP_W )); then
    go_start=$(( MAP_W - ${#go_text} ))
    (( go_start <= pac_pos )) && go_start=$(( pac_pos + 1 ))
  fi
fi

game=""
if (( g2_caged )); then
  if [ "$PAC_CHAR" = "ᗧ" ]; then
    game+="\033[1;35m${G2_CHAR}\033[0m  ${B}▌${NC} "
  else
    game+="  \033[1;35m${G2_CHAR}\033[0m${B}▌${NC} "
  fi
fi
cherry_pos=$(( PAC_MIN + 95 * (MAP_W - 1 - PAC_MIN) / 100 ))

for (( i=ROOM_W; i<MAP_W; i++ )); do
  if (( game_over && go_start >= 0 && i >= go_start && i < go_start + ${#go_text} )); then
    ci=$(( i - go_start ))
    ch="${go_text:$ci:1}"
    if [[ "$ch" == " " ]]; then game+=" "
    else game+="\033[1;31m${ch}\033[0m"; fi
  elif (( game_over && i == pac_pos )); then
    if (( g1 >= 0 && g1 == pac_pos )); then game+="\033[1;31m${G1_CHAR}\033[0m"
    else game+="\033[1;35m${G2_CHAR}\033[0m"; fi
  elif (( !game_over && i == pac_pos )); then
    game+="\033[1;33m${PAC_CHAR}\033[0m"
  elif (( g1 >= 0 && i == g1 && !(game_over && g1 == pac_pos) )); then
    game+="\033[1;31m${G1_CHAR}\033[0m"
  elif (( g2 >= 0 && i == g2 && !(game_over && g2 == pac_pos) )); then
    game+="\033[1;35m${G2_CHAR}\033[0m"
  elif (( i > pac_pos && i == cherry_pos )); then
    game+="\033[1;31mᐝ\033[0m"
  elif (( i > pac_pos )); then
    game+="\033[0;37m·\033[0m"
  else
    game+=" "
  fi
done

# =============================================================================
# SECTION: Build Colored Segments
# =============================================================================
branch_colored=""
[ -n "$branch_display" ] && branch_colored="${CYN}⎇ ${branch_display}${NC}"

path_colored="${GRY}${short_cwd}${NC}"

ctx_c=$(colour_remain "$ctx_remain")
stats_colored="\033[2mctx\033[0m:${ctx_c}"
if [ -n "$five_pct" ]; then
  five_c=$(colour_remain "$five_remain")
  stats_colored+="  \033[1;31mᗩ\033[0m\033[2m5h\033[0m:${five_c}"
  [ -n "$five_rs" ] && stats_colored+="\033[2m↓${five_rs}\033[0m"
fi
if [ -n "$week_pct" ]; then
  week_c=$(colour_remain "$week_remain")
  stats_colored+="  \033[1;35mᗩ\033[0m\033[2m7d\033[0m:${week_c}"
  [ -n "$week_rs" ] && stats_colored+="\033[2m↓${week_rs}\033[0m"
fi

tokens_colored="${BLD}↓${in_fmt}/↑${out_fmt}${NC}"

model_session_colored="${W}${model:-}${NC}${GRY}@${session}${NC}"

# =============================================================================
# SECTION: Output (single line)
# =============================================================================
line=""
[ -n "$branch_colored" ] && line+="${branch_colored}  "
line+="${path_colored}  ${game}  ${stats_colored}  ${tokens_colored}  ${model_session_colored}"
[ -n "$net_colored" ] && line+="  ${net_colored}"
echo -e "$line"
