#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CURSOR_DIR="$HOME/.cursor"
BACKUP_DIR="$CURSOR_DIR/.backup/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$CURSOR_DIR/.deploy-manifest"

AGENTS_SRC="$REPO_DIR/agents"
RULES_SRC="$REPO_DIR/rules"
SKILLS_SRC="$REPO_DIR/skills"
HOOKS_SRC="$REPO_DIR/hooks"

AGENTS_DST="$CURSOR_DIR/agents"
RULES_DST="$CURSOR_DIR/rules"
SKILLS_DST="$CURSOR_DIR/skills"
HOOKS_DST="$CURSOR_DIR/hooks"
HOOKS_JSON_DST="$CURSOR_DIR/hooks.json"

DRY_RUN=false
UNINSTALL=false
STATUS=false
WITH_AGENTS=false
WITH_SKILLS=false
WITH_HOOKS=false

usage() {
    printf '%s\n' "Usage: $0 [--dry-run] [--status|--uninstall] [--with-agents] [--with-skills] [--with-hooks]"
    printf '%s\n' ""
    printf '%s\n' "Default deploy target: rules only."
    printf '%s\n' ""
    printf '%s\n' "  --dry-run       Show what would change"
    printf '%s\n' "  --status        Show sync status"
    printf '%s\n' "  --uninstall     Remove files recorded in the deploy manifest"
    printf '%s\n' "  --with-agents   Also deploy agent definition files"
    printf '%s\n' "  --with-skills   Also deploy skill directories containing SKILL.md"
    printf '%s\n' "  --with-hooks    Also deploy hooks.json and hook scripts, if present"
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --status) STATUS=true ;;
        --uninstall) UNINSTALL=true ;;
        --with-agents) WITH_AGENTS=true ;;
        --with-skills) WITH_SKILLS=true ;;
        --with-hooks) WITH_HOOKS=true ;;
        --help|-h) usage ;;
        *) printf 'Unknown option: %s\n' "$arg"; usage ;;
    esac
done

checksum() {
    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
}

checksum_dir() {
    find "$1" -type f -print0 2>/dev/null | sort -z | xargs -0 shasum -a 256 2>/dev/null | awk '{print $1}' | shasum -a 256 | awk '{print $1}'
}

ensure_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
}

has_glob_match() {
    local pattern="$1"
    compgen -G "$pattern" >/dev/null
}

copy_file() {
    local src="$1"
    local dst="$2"
    local name

    name="$(basename "$src")"

    if [ -f "$dst" ] || [ -L "$dst" ]; then
        if [ -f "$dst" ] && [ "$(checksum "$src")" = "$(checksum "$dst")" ]; then
            printf '  synced: %s\n' "$dst"
            MANIFEST_ENTRIES+=("$dst")
            return
        fi
        if $DRY_RUN; then
            printf '  [dry-run] Would back up and copy: %s\n' "$dst"
            return
        fi
        ensure_backup_dir
        mv "$dst" "$BACKUP_DIR/$name"
        printf '  backed up: %s\n' "$dst"
    fi

    if $DRY_RUN; then
        printf '  [dry-run] Would copy: %s -> %s\n' "$src" "$dst"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    printf '  copied: %s\n' "$dst"
    MANIFEST_ENTRIES+=("$dst")
}

copy_dir() {
    local src="$1"
    local dst="$2"
    local name

    name="$(basename "$src")"

    if [ -d "$dst" ] || [ -L "$dst" ]; then
        if [ -d "$dst" ] && [ "$(checksum_dir "$src")" = "$(checksum_dir "$dst")" ]; then
            printf '  synced: %s\n' "$dst"
            MANIFEST_ENTRIES+=("$dst")
            return
        fi
        if $DRY_RUN; then
            printf '  [dry-run] Would back up and copy: %s\n' "$dst"
            return
        fi
        ensure_backup_dir
        mv "$dst" "$BACKUP_DIR/$name"
        printf '  backed up: %s\n' "$dst"
    fi

    if $DRY_RUN; then
        printf '  [dry-run] Would copy: %s -> %s\n' "$src" "$dst"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
    printf '  copied: %s\n' "$dst"
    MANIFEST_ENTRIES+=("$dst")
}

show_file_status() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [ ! -f "$src" ]; then
        return
    fi
    if [ -f "$dst" ] && [ "$(checksum "$src")" = "$(checksum "$dst")" ]; then
        printf '  synced: %s\n' "$label"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
        printf '  changed: %s\n' "$label"
    else
        printf '  missing: %s\n' "$label"
    fi
}

show_dir_status() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [ ! -d "$src" ]; then
        return
    fi
    if [ -d "$dst" ] && [ "$(checksum_dir "$src")" = "$(checksum_dir "$dst")" ]; then
        printf '  synced: %s\n' "$label"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
        printf '  changed: %s\n' "$label"
    else
        printf '  missing: %s\n' "$label"
    fi
}

remove_manifest_entries() {
    if [ ! -f "$MANIFEST" ]; then
        printf 'No manifest found: %s\n' "$MANIFEST"
        return 0
    fi

    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        if [ -f "$entry" ] || [ -L "$entry" ]; then
            if $DRY_RUN; then
                printf '  [dry-run] Would remove: %s\n' "$entry"
            else
                rm "$entry"
                printf '  removed: %s\n' "$entry"
            fi
        elif [ -d "$entry" ]; then
            if $DRY_RUN; then
                printf '  [dry-run] Would remove: %s\n' "$entry"
            else
                rm -r "$entry"
                printf '  removed: %s\n' "$entry"
            fi
        fi
    done < "$MANIFEST"

    if ! $DRY_RUN; then
        rm "$MANIFEST"
        printf '  removed: %s\n' "$MANIFEST"
    fi
}

if $STATUS; then
    printf '%s\n' "=== Cursor Personal Settings Status ==="
    printf '%s\n' ""
    printf '%s\n' "Rules:"
    if has_glob_match "$RULES_SRC/*.mdc"; then
        for file in "$RULES_SRC"/*.mdc; do
            show_file_status "$file" "$RULES_DST/$(basename "$file")" "$(basename "$file")"
        done
    else
        printf '%s\n' "  none"
    fi

    printf '%s\n' ""
    printf '%s\n' "Optional agents:"
    found=false
    if has_glob_match "$AGENTS_SRC/*.md"; then
        for file in "$AGENTS_SRC"/*.md; do
            [ "$(basename "$file")" != "README.md" ] || continue
            found=true
            show_file_status "$file" "$AGENTS_DST/$(basename "$file")" "$(basename "$file")"
        done
    fi
    if ! $found; then
        printf '%s\n' "  none"
    fi

    printf '%s\n' ""
    printf '%s\n' "Optional skills:"
    if has_glob_match "$SKILLS_SRC/*/SKILL.md"; then
        for skill_file in "$SKILLS_SRC"/*/SKILL.md; do
            dir="$(dirname "$skill_file")"
            show_dir_status "$dir" "$SKILLS_DST/$(basename "$dir")" "$(basename "$dir")"
        done
    else
        printf '%s\n' "  none"
    fi

    printf '%s\n' ""
    printf '%s\n' "Optional hooks:"
    if [ -f "$HOOKS_SRC/hooks.json" ]; then
        show_file_status "$HOOKS_SRC/hooks.json" "$HOOKS_JSON_DST" "hooks.json"
    fi
    if has_glob_match "$HOOKS_SRC/*.sh"; then
        for file in "$HOOKS_SRC"/*.sh; do
            show_file_status "$file" "$HOOKS_DST/$(basename "$file")" "$(basename "$file")"
        done
    elif [ ! -f "$HOOKS_SRC/hooks.json" ]; then
        printf '%s\n' "  none"
    fi

    printf '%s\n' ""
    if [ -f "$MANIFEST" ]; then
        printf 'Manifest: %s (%s entries)\n' "$MANIFEST" "$(wc -l < "$MANIFEST" | tr -d ' ')"
    else
        printf 'Manifest: none\n'
    fi
    exit 0
fi

if $UNINSTALL; then
    printf '%s\n' "=== Uninstalling Cursor Personal Settings ==="
    remove_manifest_entries
    exit 0
fi

printf '%s\n' "=== Deploying Cursor Personal Settings ==="
$DRY_RUN && printf '%s\n' "(dry-run mode)"
printf '%s\n' "Default target: rules"
$WITH_AGENTS && printf '%s\n' "Optional target: agents"
$WITH_SKILLS && printf '%s\n' "Optional target: skills"
$WITH_HOOKS && printf '%s\n' "Optional target: hooks"
printf '%s\n' ""

MANIFEST_ENTRIES=()

printf '%s\n' "Rules:"
if has_glob_match "$RULES_SRC/*.mdc"; then
    for file in "$RULES_SRC"/*.mdc; do
        copy_file "$file" "$RULES_DST/$(basename "$file")"
    done
else
    printf '%s\n' "  none"
fi

if $WITH_AGENTS; then
    printf '%s\n' ""
    printf '%s\n' "Agents:"
    found=false
    if has_glob_match "$AGENTS_SRC/*.md"; then
        for file in "$AGENTS_SRC"/*.md; do
            [ "$(basename "$file")" != "README.md" ] || continue
            found=true
            copy_file "$file" "$AGENTS_DST/$(basename "$file")"
        done
    fi
    $found || printf '%s\n' "  none"
fi

if $WITH_SKILLS; then
    printf '%s\n' ""
    printf '%s\n' "Skills:"
    found=false
    if has_glob_match "$SKILLS_SRC/*/SKILL.md"; then
        for skill_file in "$SKILLS_SRC"/*/SKILL.md; do
            dir="$(dirname "$skill_file")"
            found=true
            copy_dir "$dir" "$SKILLS_DST/$(basename "$dir")"
        done
    fi
    $found || printf '%s\n' "  none"
fi

if $WITH_HOOKS; then
    printf '%s\n' ""
    printf '%s\n' "Hooks:"
    found=false
    if [ -f "$HOOKS_SRC/hooks.json" ]; then
        found=true
        copy_file "$HOOKS_SRC/hooks.json" "$HOOKS_JSON_DST"
    fi
    if has_glob_match "$HOOKS_SRC/*.sh"; then
        for file in "$HOOKS_SRC"/*.sh; do
            found=true
            copy_file "$file" "$HOOKS_DST/$(basename "$file")"
            if ! $DRY_RUN; then
                chmod +x "$HOOKS_DST/$(basename "$file")"
            fi
        done
    fi
    $found || printf '%s\n' "  none"
fi

if ! $DRY_RUN; then
    mkdir -p "$CURSOR_DIR"
    printf '%s\n' "${MANIFEST_ENTRIES[@]}" > "$MANIFEST"
    printf '%s\n' ""
    printf 'Manifest written: %s (%s entries)\n' "$MANIFEST" "${#MANIFEST_ENTRIES[@]}"
fi

printf '%s\n' "Done."
