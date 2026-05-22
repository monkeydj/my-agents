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
            echo "Created shared: $shared_dir"
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
            echo "ERROR: profile '$profile' does not exist. Use --from <source> to create from an existing profile."
            echo ""
            echo "Available profiles:"
            list_available_profiles
            exit 1
        fi

        mkdir -p "$profile_dir"
        echo "Created profile: $profile_dir"
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
                echo "Updated symlink: $dst -> $src"
            fi
        elif [ -e "$dst" ]; then
            echo "WARN: $dst exists as regular file/dir, skipping"
        else
            ln -s "$src" "$dst"
            echo "Created symlink: $dst -> $src"
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
        echo "ERROR: source profile '$source_profile' not found"
        exit 1
    fi

    echo "Inheriting profile items from '$source_profile':"
    for item in "${PROFILE_ITEMS[@]}"; do
        src_path="$src_dir/$item"
        dst_path="$profile_dir/$item"
        if [ -e "$dst_path" ] || [ -L "$dst_path" ]; then
            echo "  SKIP: $item already exists"
        elif copy_item "$src_path" "$dst_path"; then
            echo "  COPIED: $item"
        else
            echo "  MISSING in source: $item"
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
            echo "MISSING: $path"
        fi
    done
}

sync_profile() {
    local profile="$1"
    local profile_dir="$PROFILES_HOME/$profile"
    local source_profile="${2:-}"
    local is_new=false

    if ensure_profile_dir "$profile" "$profile_dir" "$source_profile"; then
        is_new=true
    fi

    ensure_shared

    link_shared_items "$profile_dir"

    if [ "$is_new" = true ] && [ -n "$source_profile" ]; then
        inherit_profile_items "$profile_dir" "$source_profile"
    fi

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
            echo "FAIL: $dst is not a symlink"
            ERRORS=$((ERRORS + 1))
        else
            echo "SKIP: $expected does not exist (source missing)"
        fi
        return
    fi

    actual=$(readlink "$dst")
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: $dst -> $actual (expected $expected)"
        ERRORS=$((ERRORS + 1))
        return
    fi

    if [ ! -e "$dst" ]; then
        echo "FAIL: $dst -> $actual (broken symlink)"
        ERRORS=$((ERRORS + 1))
        return
    fi

    echo "OK: $dst -> $actual"
}

verify_profile_item() {
    local profile_dir="$1"
    local item="$2"
    local path="$profile_dir/$item"

    if [ -L "$path" ]; then
        echo "FAIL: $path is a symlink (should be profile-specific)"
        ERRORS=$((ERRORS + 1))
    elif [ ! -e "$path" ]; then
        echo "MISSING: $path"
        ERRORS=$((ERRORS + 1))
    else
        echo "OK: $path (profile-specific)"
    fi
}

verify_profile() {
    local profile="$1"
    local profile_dir="$PROFILES_HOME/$profile"
    local item

    if [ ! -d "$profile_dir" ]; then
        echo "FAIL: profile directory '$profile_dir' does not exist"
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
        echo "=== $profile ==="
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
                    echo "ERROR: --from requires a profile name"
                    exit 1
                fi
                source_profile="$2"
                shift 2
                ;;
            *)
                echo "ERROR: unknown argument: $1"
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
    echo "All checks passed."
else
    echo "$ERRORS error(s) found."
    exit 1
fi
