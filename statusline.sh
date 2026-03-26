#!/usr/bin/env bash
# =============================================================================
# Claude Code Status Line — Single Line with Pac-Man Progress Bar
# =============================================================================
# Order: branch · working dir · pacman bar · context % · 5h rate · 7d rate · model @ session · network
# =============================================================================

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "Error: jq required" >&2; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "Error: bc required" >&2; exit 1; }

input=$(cat)

# =============================================================================
# SECTION: Pac-Man Animation State
# =============================================================================
CHOMP_FILE="/tmp/.claude-pacman-chomp"
if [ -f "$CHOMP_FILE" ] && [ "$(cat "$CHOMP_FILE")" = "1" ]; then
  PAC_CHAR="●"; echo "0" > "$CHOMP_FILE"
else
  PAC_CHAR="ᗧ"; echo "1" > "$CHOMP_FILE"
fi

# =============================================================================
# SECTION: Color Definitions
# =============================================================================
Y='\033[1;33m'; R='\033[1;31m'; P='\033[1;35m'
O='\033[38;5;208m'; W='\033[0;37m'; DIM='\033[2m'; NC='\033[0m'
GRY='\033[0;90m'; CYN='\033[0;36m'

# =============================================================================
# SECTION: Parse JSON Input
# =============================================================================
ctx_pct=$(echo "$input"    | jq -r '.context_window.used_percentage // "0"')
five_pct=$(echo "$input"   | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input"   | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
model=$(echo "$input"      | jq -r 'if .model | type == "object" then (.model.display_name // .model.id // empty) | gsub("\\s*\\(.*\\)"; "") else .model // empty end')
cwd=$(echo "$input"        | jq -r '.workspace.current_dir // .cwd // ""')
session_full=$(echo "$input" | jq -r '.session_id // ""')
session="${session_full:0:8}"

ctx_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo 0)
five_int=$(printf "%.0f" "${five_pct:-0}" 2>/dev/null || echo 0)
week_int=$(printf "%.0f" "${week_pct:-0}" 2>/dev/null || echo 0)

# =============================================================================
# SECTION: Helper Functions
# =============================================================================
fmt_reset() {
  local ts="$1"; [ -z "$ts" ] && return
  local now; now=$(date +%s); local diff=$(( ts - now ))
  if (( diff <= 0 )); then printf "now"; return; fi
  local d=$(( diff / 86400 )) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  if (( d > 0 )); then printf "%dd%dh" "$d" "$h"
  elif (( h > 0 )); then printf "%dh%dm" "$h" "$m"
  else printf "%dm" "$m"; fi
}

# =============================================================================
# SECTION: Terminal Width
# =============================================================================
TERM_W=$(tput cols 2>/dev/null || echo 80)
(( TERM_W < 40 )) && TERM_W=40

# =============================================================================
# SECTION: Build Sections (Order: 5-6-8-1-2-3-4-7)
# =============================================================================

# Section 5: Branch
branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

sec5_plain=""; sec5_colored=""
if [ -n "$branch" ]; then
  sec5_plain="⎇ ${branch}"
  sec5_colored="${CYN}⎇ ${branch}${NC}"
fi

# Section 6: Working Directory
short_cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

# Section 8: Pac-Man Progress Bar
BAR_W=12
filled=$(( ctx_int * BAR_W / 100 ))
(( filled > BAR_W )) && filled=$BAR_W
empty=$(( BAR_W - filled ))

bar_plain="["; bar_colored="${Y}["
for (( i=0; i<filled; i++ )); do bar_plain+="█"; bar_colored+="${Y}█${NC}"; done
bar_plain+="${PAC_CHAR}"; bar_colored+="${Y}${PAC_CHAR}${NC}"
for (( i=0; i<empty; i++ )); do bar_plain+="·"; bar_colored+="${GRY}·${NC}"; done
bar_plain+="]"; bar_colored+="${Y}]${NC}"

# Section 1: Context Percentage
ctx_remain=$(( 100 - ctx_int )); (( ctx_remain < 0 )) && ctx_remain=0
ctx_c=""; (( ctx_remain <= 20 )) && ctx_c="${R}" || (( ctx_remain <= 50 )) && ctx_c="${Y}" || ctx_c="${GRY}"
sec1_plain=" ᗧ ${ctx_remain}%"; sec1_colored=" ${ctx_c}ᗧ ${ctx_remain}%${NC}"

# Section 2: 5h Rate
five_remain=$(( 100 - five_int )); (( five_remain < 0 )) && five_remain=0
sec2_plain=""; sec2_colored=""
if [ -n "$five_pct" ]; then
  five_c=""; (( five_remain <= 20 )) && five_c="${R}" || (( five_remain <= 50 )) && five_c="${Y}" || five_c="${GRY}"
  sec2_plain=" ᗩ 5h ${five_remain}%"; sec2_colored=" ${five_c}ᗩ 5h ${five_remain}%${NC}"
  five_rs=$(fmt_reset "$five_reset")
  if [ -n "$five_rs" ]; then
    sec2_plain+=" ↓${five_rs}"; sec2_colored+=" ${DIM}↓${five_rs}${NC}"
  fi
fi

# Section 3: 7d Rate
week_remain=$(( 100 - week_int )); (( week_remain < 0 )) && week_remain=0
sec3_plain=""; sec3_colored=""
if [ -n "$week_pct" ]; then
  week_c=""; (( week_remain <= 20 )) && week_c="${R}" || (( week_remain <= 50 )) && week_c="${Y}" || week_c="${P}"
  sec3_plain=" ᗩ 7d ${week_remain}%"; sec3_colored=" ${week_c}ᗩ 7d ${week_remain}%${NC}"
  week_rs=$(fmt_reset "$week_reset")
  if [ -n "$week_rs" ]; then
    sec3_plain+=" ↓${week_rs}"; sec3_colored+=" ${DIM}↓${week_rs}${NC}"
  fi
fi

# Section 4: Model @ Session
sec4_plain=""; sec4_colored=""
if [ -n "$model" ]; then
  sec4_plain=" ${model} @ ${session}"
  sec4_colored=" ${W}${model}${NC} ${GRY}@ ${session}${NC}"
fi

# Section 7: Network
net_iface=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
if [ -z "$net_iface" ]; then
  net_iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
fi
sec7_plain=""; sec7_colored=""
if [ -n "$net_iface" ]; then
  sec7_plain=" ⇌ ${net_iface}"
  case "$net_iface" in
    utun*|tun*|wg*|ppp*|tailscale*) sec7_colored=" ${O}⇌ ${net_iface}${NC}" ;;
    *) sec7_colored=" ${CYN}⇌ ${net_iface}${NC}" ;;
  esac
fi

# =============================================================================
# SECTION: Truncation for Narrow Terminals
# =============================================================================
content_len=${#sec5_plain}
content_len=$(( content_len + ${#short_cwd} ))
content_len=$(( content_len + ${#bar_plain} ))
content_len=$(( content_len + ${#sec1_plain} ))
content_len=$(( content_len + ${#sec2_plain} ))
content_len=$(( content_len + ${#sec3_plain} ))
content_len=$(( content_len + ${#sec4_plain} ))
content_len=$(( content_len + ${#sec7_plain} ))

while (( content_len > TERM_W )); do
  if ((${#sec7_plain} > 0)); then
    sec7_plain=""; sec7_colored=""
  elif ((${#sec5_plain} > 0)); then
    sec5_plain=""; sec5_colored=""
  elif ((${#sec4_plain} > 12)); then
    sec4_plain="${model:0:15} @ …"
    sec4_colored="${W}${model:0:15}${NC} ${GRY}@ …${NC}"
  elif ((${#short_cwd} > 8)); then
    short_cwd="…${short_cwd: -6}"
  else
    break
  fi
  
  content_len=${#sec5_plain}
  content_len=$(( content_len + ${#short_cwd} ))
  content_len=$(( content_len + ${#bar_plain} ))
  content_len=$(( content_len + ${#sec1_plain} ))
  content_len=$(( content_len + ${#sec2_plain} ))
  content_len=$(( content_len + ${#sec3_plain} ))
  content_len=$(( content_len + ${#sec4_plain} ))
  content_len=$(( content_len + ${#sec7_plain} ))
done

# =============================================================================
# SECTION: Dynamic Spacing - Fill Terminal Width
# =============================================================================
all_plain="${sec5_plain} ${short_cwd}${bar_plain}${sec1_plain}${sec2_plain}${sec3_plain}${sec4_plain}${sec7_plain}"
all_colored="${sec5_colored} ${GRY}${short_cwd}${NC}${bar_colored}${sec1_colored}${sec2_colored}${sec3_colored}${sec4_colored}${sec7_colored}"

content_len=${#all_plain}
remaining=$(( TERM_W - content_len ))

if (( remaining > 0 )); then
  fill_plain=""; fill_colored=""
  for (( i=0; i<remaining; i++ )); do fill_plain+=" "; fill_colored+=" "; done
  echo -e "${all_colored}${fill_colored}"
else
  echo -e "${all_colored}"
fi
