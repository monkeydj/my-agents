#!/bin/bash
# Sync/setup Claude profiles - shared session, project, memory
# Usage:
#   ./sync_claude.sh <profile> [--from <source>] [--include-projects]
#   ./sync_claude.sh <profile> --from <source>       New profile, copy profile items from source
#   ./sync_claude.sh verify [<profile>] [--include-projects]
#   ./sync_claude.sh -h                              Show this help

set -euo pipefail

SHARED="$HOME/.claude"
PROFILES_HOME="$HOME/.claude-profiles"
ERRORS=0

INCLUDE_PROJECTS=false

SHARED_ITEMS=(
    "agents-memory"
    "sessions"
    "memory"
    "plans"
    "rules"
    "agents"
    "skills"
    "commands"
    "hooks"
)

OPTIONAL_SHARED_ITEMS=(
    "projects"
)

PROFILE_ITEMS=(
    "CLAUDE.md"
    "settings.json"
    "settings.local.json"
    # "statusline.sh"
)

PROFILE_DIRS=(
    "hooks.local"
)

usage() {
    echo "Usage:"
    echo "  $0 <profile> [options]              Sync an existing profile"
    echo "  $0 <profile> --from <src> [options] Create new profile, inheriting profile items from <src>"
    echo "  $0 verify [<profile>] [options]     Verify profile(s)"
    echo "  $0 -h                               Show this help"
    echo ""
    echo "Options:"
    echo "  --from <src>          Create a profile by inheriting profile-specific items from <src>"
    echo "  --include-projects    Include the shared projects directory"
    echo "  --include <item|all>  Include projects or all optional shared directories"
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

    while IFS= read -r item; do
        shared_dir="$SHARED/$item"
        if [ ! -e "$shared_dir" ]; then
            mkdir -p "$shared_dir"
            log_info "created shared directory: $shared_dir"
        fi
    done < <(active_shared_items)
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

active_shared_items() {
    printf '%s\n' "${SHARED_ITEMS[@]}"

    if [ "$INCLUDE_PROJECTS" = true ]; then
        printf '%s\n' "projects"
    fi

}

report_ignored_shared_items() {
    local item

    for item in "${OPTIONAL_SHARED_ITEMS[@]}"; do
        case "$item" in
            projects)
                [ "$INCLUDE_PROJECTS" = true ] && continue
                ;;
        esac

        log_skip "shared directory ignored by default: $SHARED/$item"
    done
}

copy_shared_items() {
    local profile_dir="$1"
    local item
    local dst
    local src

    while IFS= read -r item; do
        dst="$profile_dir/$item"
        src="$SHARED/$item"

        if [ ! -e "$src" ]; then
            log_warn "shared source missing, not copied: $src"
            continue
        fi

        if [ -L "$dst" ]; then
            rm "$dst"
            copy_item "$src" "$dst"
            log_info "replaced shared symlink with copy: $dst"
        elif [ -e "$dst" ]; then
            if [ -d "$src" ] && [ -d "$dst" ]; then
                cp -a "$src"/. "$dst"/
                log_ok "updated shared directory copy: $src -> $dst"
            elif [ -f "$src" ] && [ -f "$dst" ]; then
                cp -p "$src" "$dst"
                log_ok "updated shared file copy: $src -> $dst"
            else
                log_warn "shared item exists with different type, skipping: $dst"
            fi
        else
            copy_item "$src" "$dst"
            log_info "created shared copy: $src -> $dst"
        fi
    done < <(active_shared_items)
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

    for item in "${PROFILE_DIRS[@]}"; do
        src_path="$src_dir/$item"
        dst_path="$profile_dir/$item"
        if [ -e "$dst_path" ] || [ -L "$dst_path" ]; then
            log_skip "profile directory already exists: $dst_path"
        elif copy_item "$src_path" "$dst_path"; then
            log_ok "copied profile directory: $src_path -> $dst_path"
        else
            log_warn "missing in source profile, not copied: $src_path"
        fi
    done
}

report_missing_profile_items() {
    local profile_dir="$1"
    local item
    local path

    for item in "${PROFILE_ITEMS[@]}" "${PROFILE_DIRS[@]}"; do
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

    if cp -rpL "$path" "$tmp_path"; then
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

    for item in "${PROFILE_ITEMS[@]}" "${PROFILE_DIRS[@]}"; do
        path="$profile_dir/$item"
        if [ -L "$path" ]; then
            materialize_profile_symlink "$path"
        fi
    done
}

ensure_profile_dirs() {
    local profile_dir="$1"
    local item
    local path

    for item in "${PROFILE_DIRS[@]}"; do
        path="$profile_dir/$item"
        if [ -d "$path" ] && [ ! -L "$path" ]; then
            log_ok "profile directory exists: $path"
        elif [ ! -e "$path" ] && [ ! -L "$path" ]; then
            mkdir -p "$path"
            log_info "created profile directory: $path"
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

    report_ignored_shared_items

    copy_shared_items "$profile_dir"

    if [ "$is_new" = true ] && [ -n "$source_profile" ]; then
        inherit_profile_items "$profile_dir" "$source_profile"
    fi

    normalize_profile_items "$profile_dir"

    ensure_profile_dirs "$profile_dir"

    report_missing_profile_items "$profile_dir"
}

verify_shared_item() {
    local profile_dir="$1"
    local item="$2"
    local dst="$profile_dir/$item"
    local expected="$SHARED/$item"

    if [ ! -e "$expected" ]; then
        log_skip "shared source missing, verification skipped: $expected"
        return
    fi

    if [ -L "$dst" ]; then
        log_error "shared item should be a copy, not a symlink: $dst"
        ERRORS=$((ERRORS + 1))
        return
    fi

    if [ ! -e "$dst" ]; then
        log_error "missing shared copy: $dst (expected copy of $expected)"
        ERRORS=$((ERRORS + 1))
        return
    fi

    if [ -d "$expected" ] && [ ! -d "$dst" ]; then
        log_error "shared copy type mismatch: $dst (expected directory)"
        ERRORS=$((ERRORS + 1))
        return
    fi

    if [ -f "$expected" ] && [ ! -f "$dst" ]; then
        log_error "shared copy type mismatch: $dst (expected file)"
        ERRORS=$((ERRORS + 1))
        return
    fi

    log_ok "shared copy verified: $dst"
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

    report_ignored_shared_items

    while IFS= read -r item; do
        verify_shared_item "$profile_dir" "$item"
    done < <(active_shared_items)

    for item in "${PROFILE_ITEMS[@]}" "${PROFILE_DIRS[@]}"; do
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
            --include-projects)
                INCLUDE_PROJECTS=true
                shift
                ;;
            --include)
                parse_include_arg "${2:-}"
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

parse_include_arg() {
    local item="$1"

    if [ -z "$item" ]; then
        log_error "--include requires projects or all"
        exit 1
    fi

    case "$item" in
        projects)
            INCLUDE_PROJECTS=true
            ;;
        all)
            INCLUDE_PROJECTS=true
            ;;
        *)
            log_error "unknown optional shared item: $item"
            usage
            ;;
    esac
}

parse_verify_args() {
    shift

    local profile=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --include-projects)
                INCLUDE_PROJECTS=true
                shift
                ;;
            --include)
                parse_include_arg "${2:-}"
                shift 2
                ;;
            -*)
                log_error "unknown argument: $1"
                usage
                ;;
            *)
                if [ -n "$profile" ]; then
                    log_error "unexpected argument: $1"
                    usage
                fi
                profile="$1"
                shift
                ;;
        esac
    done

    if [ -n "$profile" ]; then
        verify_profile "$profile"
    else
        verify_all_profiles
    fi
}

case "${1:-}" in
    verify)
        parse_verify_args "$@"
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
