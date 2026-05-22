#!/bin/bash
# Sync/setup Claude profiles - shared session, project, memory
# Usage:
#   ./sync_claude.sh <profile> [--from <source>]   Create/sync a profile
#   ./sync_claude.sh <profile> --from <source>       New profile, copy profile items from source
#   ./sync_claude.sh verify [<profile>]              Verify profile(s)
#   ./sync_claude.sh -h                              Show this help

set -euo pipefail

SHARED="$HOME/.claude"
PROFILES_HOME="$HOME/.claude-profiles"
ERRORS=0

SHARED_ITEMS=(
    "agents-memory"
    "sessions"
    "projects"
    "memory"
    "plans"
    "rules"
    "agents"
    "skills"
    "commands"
    "hooks"
)

PROFILE_ITEMS=(
    "CLAUDE.md"
    "settings.json"
    "settings.local.json"
    "statusline.sh"
)

usage() {
    echo "Usage:"
    echo "  $0 <profile>                 Sync an existing profile"
    echo "  $0 <profile> --from <src>    Create new profile, inheriting profile items from <src>"
    echo "  $0 verify [<profile>]        Verify profile(s)"
    echo "  $0 -h                        Show this help"
    exit 1
}

log_info() {
    echo "INFO: $*"
}

log_ok() {
    echo "OK: $*"
}

log_warn() {
    echo "WARN: $*"
}

log_error() {
    echo "ERROR: $*"
}

log_skip() {
    echo "SKIP: $*"
}

list_available_profiles() {
    local profile_dir

    for profile_dir in "$PROFILES_HOME"/*/; do
        [ -d "$profile_dir" ] || continue
        echo "  $(basename "$profile_dir")"
    done
}

ensure_shared() {
    local item
    local shared_dir

    for item in "${SHARED_ITEMS[@]}"; do
        shared_dir="$SHARED/$item"
        if [ ! -e "$shared_dir" ]; then
            mkdir -p "$shared_dir"
            log_info "created shared directory: $shared_dir"
        fi
    done
}

copy_item() {
    local src="$1"
    local dst="$2"

    if [ -d "$src" ]; then
        cp -a "$src" "$dst"
    elif [ -f "$src" ]; then
        cp "$src" "$dst"
    else
        return 1
    fi
}

ensure_profile_dir() {
    local profile="$1"
    local profile_dir="$2"
    local source_profile="$3"

    if [ ! -d "$profile_dir" ]; then
        if [ -z "$source_profile" ]; then
            log_error "profile '$profile' does not exist at $profile_dir"
            log_info "use --from <source> to create it from an existing profile"
            echo ""
            log_info "available profiles:"
            list_available_profiles
            exit 1
        fi

        mkdir -p "$profile_dir"
        log_info "created profile directory: $profile_dir"
        log_info "source profile for inheritance: $source_profile"
        return 0
    fi

    return 1
}

link_shared_items() {
    local profile_dir="$1"
    local item
    local dst
    local src
    local current

    for item in "${SHARED_ITEMS[@]}"; do
        dst="$profile_dir/$item"
        src="$SHARED/$item"

        if [ -L "$dst" ]; then
            current=$(readlink "$dst")
            if [ "$current" != "$src" ]; then
                rm "$dst"
                ln -s "$src" "$dst"
                log_info "updated shared link: $dst -> $src"
            else
                log_ok "shared link already correct: $dst -> $src"
            fi
        elif [ -e "$dst" ]; then
            log_warn "shared item exists as regular file/dir, skipping: $dst"
        else
            ln -s "$src" "$dst"
            log_info "created shared link: $dst -> $src"
        fi
    done
}

inherit_profile_items() {
    local profile_dir="$1"
    local source_profile="$2"
    local src_dir="$PROFILES_HOME/$source_profile"
    local item
    local src_path
    local dst_path

    if [ ! -d "$src_dir" ]; then
        log_error "source profile not found: $src_dir"
        exit 1
    fi

    log_info "copying profile-specific items from '$source_profile' into '$profile_dir'"
    for item in "${PROFILE_ITEMS[@]}"; do
        src_path="$src_dir/$item"
        dst_path="$profile_dir/$item"
        if [ -e "$dst_path" ] || [ -L "$dst_path" ]; then
            log_skip "profile item already exists: $dst_path"
        elif copy_item "$src_path" "$dst_path"; then
            log_ok "copied profile item: $src_path -> $dst_path"
        else
            log_warn "missing in source profile, not copied: $src_path"
        fi
    done
}

report_missing_profile_items() {
    local profile_dir="$1"
    local item
    local path

    for item in "${PROFILE_ITEMS[@]}"; do
        path="$profile_dir/$item"
        if [ ! -e "$path" ] && [ ! -L "$path" ]; then
            log_warn "missing profile-specific item: $path"
        fi
    done
}

materialize_profile_symlink() {
    local path="$1"
    local target
    local tmp_path

    if [ ! -L "$path" ]; then
        return 1
    fi

    target=$(readlink "$path")
    tmp_path="${path}.materialize.$$"

    if cp -pL "$path" "$tmp_path"; then
        rm "$path"
        mv "$tmp_path" "$path"
        log_info "converted profile symlink to local file: $path (from $target)"
        return 0
    fi

    rm -f "$tmp_path"
    log_error "failed to convert profile symlink to local file: $path (from $target)"
    return 1
}

normalize_profile_items() {
    local profile_dir="$1"
    local item
    local path

    for item in "${PROFILE_ITEMS[@]}"; do
        path="$profile_dir/$item"
        if [ -L "$path" ]; then
            materialize_profile_symlink "$path"
        fi
    done
}

sync_profile() {
    local profile="$1"
    local profile_dir="$PROFILES_HOME/$profile"
    local source_profile="${2:-}"
    local is_new=false

    log_info "syncing profile: $profile"

    if ensure_profile_dir "$profile" "$profile_dir" "$source_profile"; then
        is_new=true
    fi

    ensure_shared

    link_shared_items "$profile_dir"

    if [ "$is_new" = true ] && [ -n "$source_profile" ]; then
        inherit_profile_items "$profile_dir" "$source_profile"
    fi

    normalize_profile_items "$profile_dir"

    report_missing_profile_items "$profile_dir"
}

verify_shared_item() {
    local profile_dir="$1"
    local item="$2"
    local dst="$profile_dir/$item"
    local expected="$SHARED/$item"
    local actual

    if [ ! -L "$dst" ]; then
        if [ -e "$expected" ]; then
            log_error "shared item is not a symlink: $dst (expected -> $expected)"
            ERRORS=$((ERRORS + 1))
        else
            log_skip "shared source missing, verification skipped: $expected"
        fi
        return
    fi

    actual=$(readlink "$dst")
    if [ "$actual" != "$expected" ]; then
        log_error "shared link target mismatch: $dst -> $actual (expected $expected)"
        ERRORS=$((ERRORS + 1))
        return
    fi

    if [ ! -e "$dst" ]; then
        log_error "broken shared symlink: $dst -> $actual"
        ERRORS=$((ERRORS + 1))
        return
    fi

    log_ok "shared link verified: $dst -> $actual"
}

verify_profile_item() {
    local profile_dir="$1"
    local item="$2"
    local path="$profile_dir/$item"

    if [ -L "$path" ]; then
        log_error "profile-specific item should not be a symlink: $path"
        ERRORS=$((ERRORS + 1))
    elif [ ! -e "$path" ]; then
        log_warn "missing profile-specific item: $path"
        ERRORS=$((ERRORS + 1))
    else
        log_ok "profile-specific item present: $path"
    fi
}

verify_profile() {
    local profile="$1"
    local profile_dir="$PROFILES_HOME/$profile"
    local item

    log_info "checking profile: $profile"

    if [ ! -d "$profile_dir" ]; then
        log_error "profile directory does not exist: $profile_dir"
        ERRORS=$((ERRORS + 1))
        return
    fi

    for item in "${SHARED_ITEMS[@]}"; do
        verify_shared_item "$profile_dir" "$item"
    done

    for item in "${PROFILE_ITEMS[@]}"; do
        verify_profile_item "$profile_dir" "$item"
    done
}

verify_all_profiles() {
    local profile_dir
    local profile

    for profile_dir in "$PROFILES_HOME"/*/; do
        [ -d "$profile_dir" ] || continue
        profile=$(basename "$profile_dir")
        log_info "verifying profile: $profile"
        verify_profile "$profile"
        echo ""
    done
}

parse_profile_args() {
    local profile="$1"
    shift

    local source_profile=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --from)
                if [ -z "${2:-}" ]; then
                    log_error "--from requires a profile name"
                    exit 1
                fi
                source_profile="$2"
                shift 2
                ;;
            *)
                log_error "unknown argument: $1"
                usage
                ;;
        esac
    done

    sync_profile "$profile" "$source_profile"
    echo ""
    verify_profile "$profile"
}

case "${1:-}" in
    verify)
        if [ -n "${2:-}" ]; then
            verify_profile "$2"
        else
            verify_all_profiles
        fi
        ;;
    ""|-h|--help)
        usage
        ;;
    *)
        parse_profile_args "$@"
        ;;
esac

echo ""
if [ "$ERRORS" -eq 0 ]; then
    log_ok "all checks passed"
else
    log_error "$ERRORS error(s) found"
    exit 1
fi
