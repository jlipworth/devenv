#!/usr/bin/env bash
# scripts/nvim-plugin-audit.sh
# Walk nvim/lazy-lock.json, query GitHub for each plugin's most recent
# commit, classify stale / abandoned. See
# docs/superpowers/specs/2026-04-12-nvim-debug-polish-design.md §6.
#
# Exit codes:
#   0 - no plugin exceeds 24 months (may have warnings)
#   1 - one or more plugins exceed 24 months
#   2 - script error (missing deps, unparsable lock, etc.)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${REPO_ROOT}/nvim/lazy-lock.json"
MAP_FILE="${REPO_ROOT}/scripts/plugin-audit-map.json"
LAZY_DIR="${HOME}/.local/share/nvim_parity_debug/lazy"

DRY_RUN=0
JSON_OUT=0
UPDATE_MAP=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --json) JSON_OUT=1 ;;
        --update-map) UPDATE_MAP=1 ;;
        -h | --help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown arg: $arg" >&2
            exit 2
            ;;
    esac
done

for dep in jq curl; do
    if ! command -v "$dep" > /dev/null 2>&1; then
        echo "Missing dep: $dep" >&2
        exit 2
    fi
done

if [[ ! -f "$LOCK_FILE" ]]; then
    echo "Lock file not found: $LOCK_FILE" >&2
    exit 2
fi

# -----------------------------------------------------------------------------
# Resolve short-name -> owner/repo map.
# Lazy v11+ stores a "url" in each lock entry; older versions don't.
# If missing, walk LAZY_DIR/*/.git/config for the remote URL.
# -----------------------------------------------------------------------------

bootstrap_map() {
    local tmp
    tmp="$(mktemp)"
    echo '{}' > "$tmp"
    if [[ ! -d "$LAZY_DIR" ]]; then
        echo "Lazy plugin dir not found: $LAZY_DIR (run :Lazy sync first)" >&2
        rm -f "$tmp"
        return 2
    fi
    while IFS= read -r -d '' gitcfg; do
        local plugin_dir plugin_name url owner_repo
        plugin_dir="$(dirname "$(dirname "$gitcfg")")"
        plugin_name="$(basename "$plugin_dir")"
        url="$(git -C "$plugin_dir" config --get remote.origin.url 2> /dev/null || true)"
        [[ -z "$url" ]] && continue
        # Normalize git@github.com:owner/repo.git and https://github.com/owner/repo.git
        owner_repo="$(echo "$url" |
            sed -E 's|^git@github.com:||; s|^https://github.com/||; s|\.git$||')"
        jq --arg k "$plugin_name" --arg v "$owner_repo" \
            '. + {($k): $v}' "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
    done < <(find "$LAZY_DIR" -maxdepth 3 -name config -path '*/.git/config' -print0)
    mv "$tmp" "$MAP_FILE"
    echo "Wrote $MAP_FILE" >&2
}

if [[ ! -f "$MAP_FILE" ]] || [[ "$UPDATE_MAP" == "1" ]]; then
    bootstrap_map || exit $?
fi

resolve_repo() {
    local short="$1"
    local from_lock from_map
    from_lock="$(jq -r --arg k "$short" \
        '.[$k].url // empty' "$LOCK_FILE" |
        sed -E 's|^git@github.com:||; s|^https://github.com/||; s|\.git$||')"
    if [[ -n "$from_lock" ]]; then
        echo "$from_lock"
        return 0
    fi
    from_map="$(jq -r --arg k "$short" '.[$k] // empty' "$MAP_FILE")"
    echo "$from_map"
}

# -----------------------------------------------------------------------------
# Query GitHub for last commit date.
# -----------------------------------------------------------------------------

query_last_commit() {
    local owner_repo="$1"
    local auth=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    local resp
    resp="$(curl -fsSL "${auth[@]}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${owner_repo}/commits?per_page=1" 2> /dev/null)"
    if [[ -z "$resp" ]]; then
        echo "NET_ERR"
        return
    fi
    # Array with one entry; date lives at [0].commit.committer.date
    echo "$resp" | jq -r '.[0].commit.committer.date // "PARSE_ERR"' 2> /dev/null || echo "PARSE_ERR"
}

# -----------------------------------------------------------------------------
# Main loop.
# -----------------------------------------------------------------------------

today_epoch="$(date +%s)"
warn_cutoff_sec=$((60 * 60 * 24 * 30 * 12)) # 12 mo
fail_cutoff_sec=$((60 * 60 * 24 * 30 * 24)) # 24 mo

declare -a rows=()
ok_count=0
warn_count=0
fail_count=0

while IFS= read -r plugin; do
    owner_repo="$(resolve_repo "$plugin")"
    if [[ -z "$owner_repo" ]]; then
        rows+=("$(printf '%s\t%s\t%s\t%s\n' "$plugin" "?" "UNKNOWN" "no-repo-mapping")")
        warn_count=$((warn_count + 1))
        continue
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        rows+=("$(printf '%s\t%s\t%s\t%s\n' "$plugin" "-" "DRY" "$owner_repo")")
        continue
    fi

    date_iso="$(query_last_commit "$owner_repo")"
    if [[ "$date_iso" == "NET_ERR" ]] || [[ "$date_iso" == "PARSE_ERR" ]]; then
        rows+=("$(printf '%s\t%s\t%s\t%s\n' "$plugin" "?" "$date_iso" "$owner_repo")")
        continue
    fi

    last_epoch="$(date -d "$date_iso" +%s 2> /dev/null || echo 0)"
    if [[ "$last_epoch" == "0" ]]; then
        rows+=("$(printf '%s\t%s\t%s\t%s\n' "$plugin" "?" "PARSE_ERR" "$date_iso")")
        continue
    fi
    age_sec=$((today_epoch - last_epoch))
    age_mo=$((age_sec / (60 * 60 * 24 * 30)))

    status="OK"
    if ((age_sec > fail_cutoff_sec)); then
        status="FAIL"
        fail_count=$((fail_count + 1))
    elif ((age_sec > warn_cutoff_sec)); then
        status="WARN"
        warn_count=$((warn_count + 1))
    else
        ok_count=$((ok_count + 1))
    fi

    rows+=("$(printf '%s\t%s\t%s\t%s\n' "$plugin" "$age_mo" "$status" "${date_iso%T*}")")
done < <(jq -r 'keys[]' "$LOCK_FILE")

# -----------------------------------------------------------------------------
# Render.
# -----------------------------------------------------------------------------

if [[ "$JSON_OUT" == "1" ]]; then
    printf '%s\n' "${rows[@]}" | jq -R 'split("\t") | {plugin: .[0], age_months: .[1], status: .[2], detail: .[3]}' | jq -s .
else
    printf '%-32s %-10s %-9s %s\n' "Plugin" "Age (mo)" "Status" "Last commit"
    printf '%-32s %-10s %-9s %s\n' "------" "--------" "------" "-----------"
    printf '%s\n' "${rows[@]}" | sort -t $'\t' -k3,3r -k2,2nr |
        awk -F'\t' '{ printf "%-32s %-10s %-9s %s\n", $1, $2, $3, $4 }'
    echo
    echo "Summary: ${ok_count} OK, ${warn_count} WARN, ${fail_count} FAIL"
fi

if ((fail_count > 0)); then
    exit 1
fi
exit 0
