#!/usr/bin/env bash
# =============================================================================
# Claude Code Status Line — Session Monitor with Pac-Man Visualization
# =============================================================================
# Dependencies: jq, bc
#
# Line 1: [network] repo ⎇ branch ............... ~/path
# Line 2: CLAUDE vX.X.X  Model  ContextSize  ᗧontext XX% left
# Line 3: ╭─[Pac-Man game: context window chase]─╮
# Line 4: ║ ᗩ/ᗣ ▌ ································ ║
# Line 5: ╰───────────────────────────────────────╯
# Line 6: sessionID  ↓in/↑out  ᗩ 7d XX%  ᗩ 5h XX%
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
version=$(echo "$input"    | jq -r '.version // empty')
cwd=$(echo "$input"        | jq -r '.workspace.current_dir // .cwd // ""')
in_tokens=$(echo "$input"  | jq -r '.context_window.total_input_tokens // 0')
out_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
session_full=$(echo "$input" | jq -r '.session_id // ""')
session="${session_full:0:8}"  # Truncate to 8 chars for display

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

# Generate horizontal line of box-drawing characters
rep_hline() {
  local n=$1 s=""
  for (( i=0; i<n; i++ )); do s+="\033[38;5;27m═\033[0m"; done
  printf "%s" "$s"
}

# =============================================================================
# SECTION: Map Configuration & Game State
# =============================================================================
# Legend: Pac-Man (ᗧ/●) = context usage, Ghost ᗩ = 5h rate, Ghost ᗣ = 7d rate
# ============================================================================

PAD=1
TERM_W=$(tput cols 2>/dev/null || echo 80)
MAP_W=$(( TERM_W - 2 - PAD * 2 ))
(( MAP_W < 20 )) && MAP_W=20
TOTAL_W=$TERM_W

# Calculate remaining percentages
ctx_remain=$(( 100 - ctx_int )); (( ctx_remain < 0 )) && ctx_remain=0
five_remain=$(( 100 - five_int )); (( five_remain < 0 )) && five_remain=0
week_remain=$(( 100 - week_int )); (( week_remain < 0 )) && week_remain=0
five_rs=$(fmt_reset "$five_reset")
week_rs=$(fmt_reset "$week_reset")

# Calculate Pac-Man position based on context usage
PAC_MIN=12
pac_pos=$(( PAC_MIN + ctx_int * (MAP_W - 1 - PAC_MIN) / 100 ))
(( pac_pos < PAC_MIN )) && pac_pos=$PAC_MIN
(( pac_pos >= MAP_W )) && pac_pos=$(( MAP_W - 1 ))

# Determine ghost positions based on rate limits
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
# SECTION: Build Pac-Man Visualization Line
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
# SECTION: Build Box Borders
# =============================================================================
hline_w=$(( MAP_W + PAD * 2 ))
top_border="${B}╭${NC}$(rep_hline $hline_w)${B}╮${NC}"
bot_border="${B}╰${NC}$(rep_hline $hline_w)${B}╯${NC}"

# =============================================================================
# SECTION: Line 2 — CLAUDE Header
# =============================================================================
ctx_size=$(fmt_tokens "$ctx_total")
ctx_c=$(colour_remain "$ctx_remain")

right_plain=""
[ -n "$model" ] && right_plain+="${model} "
[ -n "$ctx_size" ] && right_plain+="${ctx_size} "
right_plain+="Xontext ${ctx_remain}% left"
right_len=${#right_plain}

left_plain="CLAUDE"
[ -n "$version" ] && left_plain+=" v${version}"
left_len=${#left_plain}
gap=$(( TERM_W - left_len - right_len ))
(( gap < 2 )) && gap=2

left_colored="${O}CLAUDE${NC}"
[ -n "$version" ] && left_colored+=" ${DIM}v${version}${NC}"

right_colored=""
[ -n "$model" ] && right_colored+="${W}${model}${NC} "
[ -n "$ctx_size" ] && right_colored+="\033[2m${ctx_size}\033[0m "
right_colored+="\033[1;33mᗧ\033[0m\033[2montext\033[0m ${ctx_c} \033[2mleft\033[0m"

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
# SECTION: Line 1 — Git Info & Path
# =============================================================================
short_cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

repo=""; branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Left: [network] repo ⎇ branch
l1_left_plain="${net_plain}"
l1_left_colored="${net_colored}"

# Right: ⎇ branch  ~/path (with truncation if needed)
branch_part="${branch:+⎇ ${branch}  }"
max_path_len=$(( TERM_W - ${#l1_left_plain} - ${#branch_part} - 2 ))
if [ -n "$short_cwd" ] && (( max_path_len > 5 )) && (( ${#short_cwd} > max_path_len )); then
  short_cwd="…${short_cwd: -$(( max_path_len - 3 ))}"
fi

l1_right_plain="${branch_part}${short_cwd}"
l1_right_colored="${branch:+${CYN}⎇ ${branch}${NC}  }${GRY}${short_cwd}${NC}"

l1_gap=$(( TERM_W - ${#l1_left_plain} - ${#l1_right_plain} ))
(( l1_gap < 1 )) && l1_gap=1
l1_gap_pad=$(printf "%*s" "$l1_gap" "")

# =============================================================================
# SECTION: Line 6 — Footer (Session & Rate Limits)
# =============================================================================
in_fmt=$(fmt_tokens "$in_tokens")
out_fmt=$(fmt_tokens "$out_tokens")

# plain-text right side for gap calculation
f_right_plain="↓${in_fmt}/↑${out_fmt}"
f_right_colored="${BLD}↓${in_fmt}/↑${out_fmt}${NC}"

if [ -n "$week_pct" ]; then
  week_c=$(colour_remain "$week_remain")
  f_right_plain+="  ᗩ 7d ${week_remain}%"
  f_right_colored+="  \033[1;35mᗩ\033[0m \033[2m7d\033[0m ${week_c}"
  if [ -n "$week_rs" ]; then
    f_right_plain+=" ↓${week_rs}"
    f_right_colored+=" \033[2m↓${week_rs}\033[0m"
  fi
fi
if [ -n "$five_pct" ]; then
  five_c=$(colour_remain "$five_remain")
  f_right_plain+="  ᗩ 5h ${five_remain}%"
  f_right_colored+="  \033[1;31mᗩ\033[0m \033[2m5h\033[0m ${five_c}"
  if [ -n "$five_rs" ]; then
    f_right_plain+=" ↓${five_rs}"
    f_right_colored+=" \033[2m↓${five_rs}\033[0m"
  fi
fi

f_left_plain="${session}"
f_left_colored="${GRY}${session}${NC}"
f_gap=$(( TERM_W - ${#f_left_plain} - ${#f_right_plain} ))
(( f_gap < 1 )) && f_gap=1
f_gap_pad=$(printf "%*s" "$f_gap" "")

# =============================================================================
# SECTION: Output
# =============================================================================
gap_pad=$(printf "%*s" "$gap" "")

echo -e "${l1_left_colored}${l1_gap_pad}${l1_right_colored}"
echo -e "${left_colored}${gap_pad}${right_colored}"
echo -e "$top_border"
echo -e "${B}║${NC} ${game} ${B}║${NC}"
echo -e "$bot_border"
echo -e "${f_left_colored}${f_gap_pad}${f_right_colored}"
