# Custom shell configuration
# Source from .zshrc — omits well-known tool installers
# (Homebrew, Oh My Zsh, NVM, conda init, gcloud, bun, deno, zoxide, warp terminal)

# ---- PATH ----
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"

# ---- Env ----
export PYCURL_SSL_LIBRARY=openssl
export MYSQLCLIENT_LDFLAGS="-L/opt/homebrew/lib -lmysqlclient"
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
export LDFLAGS="-L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
export CPPFLAGS="-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1 -I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include"
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000

# ---- Python ----
_pyon_log() {
  local logdir="$HOME/.cache/pyon"
  mkdir -p "$logdir"
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" | tee -a "$logdir/pyon.log"
}

pyon() {
  if [[ -f .venv/bin/activate ]]; then
    _pyon_log "activating .venv in $(pwd)"
    source .venv/bin/activate
  elif git rev-parse --git-common-dir &>/dev/null; then
    local main_dir
    main_dir="$(dirname "$(git rev-parse --git-common-dir 2>/dev/null)")"
    if [[ -f "$main_dir/.venv/bin/activate" ]]; then
      _pyon_log "activating .venv in git root ($main_dir) from $(pwd)"
      source "$main_dir/.venv/bin/activate"
    else
      _pyon_log "no .venv found in current or git root from $(pwd)"
      echo "No .venv found in current or main project dir" >&2
      return 1
    fi
  else
    _pyon_log "no .venv found — not in a git repo, $(pwd)"
    echo "No .venv found" >&2
    return 1
  fi
}

# ---- Conda ----
condax86() {
  CONDA_SUBDIR=osx-64 conda create -n "$@"
  conda activate "$1"
  conda config --env --set subdir osx-64
}

# ---- Warp ----
ensure_warp_connected() {
  local warp_cli_path=$(command -v warp-cli)
  local max_attempts=10
  local attempt=0

  if [ -z "$warp_cli_path" ]; then
    echo "❌ warp-cli not found in PATH"
    return 1
  fi

  if "$warp_cli_path" status 2>/dev/null | grep -q "Connected"; then
    return 0
  fi

  echo "🔄 Connecting to Warp..."
  "$warp_cli_path" connect >/dev/null 2>&1

  while [ $attempt -lt $max_attempts ]; do
    sleep 1
    if "$warp_cli_path" status 2>/dev/null | grep -q "Connected"; then
      echo "✅ Warp connected successfully"
      return 0
    fi
    attempt=$((attempt + 1))
  done

  echo "❌ Failed to connect to Warp after ${max_attempts} seconds"
  return 1
}

# ---- Claude ----

# MCP-arg parser for cc. Separates --mcp-config / --strict-mcp-config from
# the rest of the argv. Sets three globals cc reads:
#   _mcp_args     — array of MCP-related flags + values
#   _other_args   — everything else
#   _mcp_explicit — "true" if caller passed an explicit --mcp-config
_parse_mcp_args() {
  _mcp_args=()
  _other_args=()
  _mcp_explicit=false

  while (($#)); do
    case "$1" in
      --mcp-config)
        _mcp_explicit=true
        (($# < 2)) && { echo "❌ missing value for --mcp-config" >&2; return 1; }
        _mcp_args+=("$1"); shift
        local saw=false
        while (($#)); do
          case "$1" in --) break ;; -*) break ;; esac
          _mcp_args+=("$1"); saw=true; shift
        done
        [[ "$saw" != true ]] && { echo "❌ missing value for --mcp-config" >&2; return 1; }
        ;;
      --mcp-config=*|--strict-mcp-config)
        _mcp_explicit=true; _mcp_args+=("$1"); shift
        ;;
      --)
        shift; _other_args+=("$@"); break
        ;;
      *)
        _other_args+=("$1"); shift
        ;;
    esac
  done
}

_cc_profile_dir() {
  local profile="$1"
  local profile_root="$HOME/.claude-profiles"

  case "$profile" in
    /*)
      print -r -- "$profile"
      ;;
    ~/*)
      print -r -- "${profile/#\~/$HOME}"
      ;;
    *)
      print -r -- "$profile_root/$profile"
      ;;
  esac
}

unalias cc 2>/dev/null
cc() {
  local mode="continue"
  local mode_count=0
  local no_telemetry=false
  local profile_dir=""
  local profile=""
  local claude_profile_mcp_filename=".mcp.json"
  local global_mcp="$HOME/.claude.mcp.json"
  local real_claude_path
  local -a args=()

  real_claude_path=$(whence -p claude)
  if [[ -z "$real_claude_path" ]]; then
    echo "❌ claude binary not found in PATH"
    return 1
  fi

  while (($#)); do
    case "$1" in
      -n|--new)       mode="new"; ((mode_count++)); shift ;;
      -r|--resume)    mode="resume"; ((mode_count++)); shift ;;
      -p|--profile)
        (($# < 2)) && { echo "❌ cc: missing profile name after $1"; return 1; }
        profile="$2"; shift 2 ;;
      -p=*|--profile=*) profile="${1#*=}"; shift ;;
      --no-telemetry) no_telemetry=true; shift ;;
      --)  shift; args+=("$@"); break ;;
      *)   args+=("$1"); shift ;;
    esac
  done

  ((mode_count > 1)) && { echo "❌ cc: --new and --resume are mutually exclusive"; return 1; }

  local -a mode_args=()
  [[ "$mode" == "continue" ]] && mode_args=(--continue)
  [[ "$mode" == "resume" ]]   && mode_args=(--resume)

  if [[ -n "$profile" ]]; then
    no_telemetry=true
    profile_dir="$(_cc_profile_dir "$profile")"
  fi

  _parse_mcp_args "${args[@]}" || return 1

  if [[ "$_mcp_explicit" != true ]]; then
    local profile_mcp="$profile_dir/$claude_profile_mcp_filename"
    if [[ -n "$profile_dir" && -f "$profile_mcp" ]]; then
      _mcp_args=(--mcp-config "$profile_mcp")
    elif [[ -f "$global_mcp" ]]; then
      _mcp_args=(--mcp-config "$global_mcp")
    fi
  fi

  [[ -n "$profile_dir" ]] && local -x CLAUDE_CONFIG_DIR="$profile_dir"

  if [[ "$no_telemetry" == true ]]; then
    local -x CLAUDE_CODE_ENABLE_TELEMETRY=0
    local -x DISABLE_TELEMETRY=1
    local -x DISABLE_ERROR_REPORTING=1
    local -x CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  fi

  if ensure_warp_connected; then
    "$real_claude_path" "${_mcp_args[@]}" "${mode_args[@]}" "${_other_args[@]}"
  else
    echo "⚠️ Cannot execute claude - Warp connection failed"
    return 1
  fi
}

alias ccnk="z CodeSpace nous_kenos; cc"
alias ccspend="npx claude-spend"
alias chaiku="claude --model haiku"
alias wsc='wt switch --create --execute=claude'

# ---- Code Review ----
alias crg="code-review-graph"
alias crgviz="crg build && crg visualize && open .code-review-graph/graph.html"

# ---- Git ----
alias gass="gaa && git stash save"
alias grobi='git rebase origin/$(git_current_branch) -i'
alias gsfb="gb | fzf | xargs gsw"
alias gwosh="gca! && ggpush -f"

# ---- Coding tools ----
alias code=code-insiders
alias centreplane="code ~/CodeSpace/centre-plane.code-workspace"

# ---- System ----
alias dirtree="ls -aR | grep \":$\" | perl -pe 's/:$//;s/[^-][^\/]*\//    /g;s/^    (\S)/└── \1/;s/(^    |    (?= ))/│   /g;s/    (\S)/└── \1/'"
alias isonow="date '+%Y-%m-%dT%T%z'"
alias timestamp="isonow | sed -E 's/[^0-9]/_/g'"
alias load_env="source <(grep -v '^#' ${1:-.env} | sed -En 's/[^#]+/export &/ p')"
alias load_ssh="ssh-add --apple-use-keychain ~/.ssh/id_inspectorio"
alias ndir="nvim ."
alias showpath="sed 's/:/\n/g' <<< \"$PATH\""
