#!/usr/bin/env bash
set -euo pipefail

# Cursor Personal Harness — Deploy Script
# Copies agents/, rules/, and skills/ from this project to ~/.cursor/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CURSOR_DIR="$HOME/.cursor"
BACKUP_DIR="$CURSOR_DIR/.backup/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$CURSOR_DIR/.deploy-manifest"

AGENTS_SRC="$PROJECT_DIR/agents"
RULES_SRC="$PROJECT_DIR/rules"
SKILLS_SRC="$PROJECT_DIR/skills"
AGENTS_DST="$CURSOR_DIR/agents"
RULES_DST="$CURSOR_DIR/rules"
SKILLS_DST="$CURSOR_DIR/skills"

DRY_RUN=false
UNINSTALL=false
STATUS=false

usage() {
    echo "Usage: $0 [--dry-run|--uninstall|--status]"
    echo ""
    echo "  (no args)    Deploy (copy) files to ~/.cursor/"
    echo "  --dry-run    Show what would be done without making changes"
    echo "  --uninstall  Remove files deployed by this script"
    echo "  --status     Show sync status (checksum comparison)"
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        --uninstall) UNINSTALL=true ;;
        --status)   STATUS=true ;;
        --help|-h)  usage ;;
        *) echo "Unknown option: $arg"; usage ;;
    esac
done

checksum() {
    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
}

checksum_dir() {
    find "$1" -type f -print0 | sort -z | xargs -0 shasum -a 256 2>/dev/null | awk '{print $1}' | shasum -a 256 | awk '{print $1}'
}

# --- Status ---
if $STATUS; then
    echo "=== Cursor Harness Status ==="
    echo ""
    echo "Agents ($AGENTS_DST):"
    for f in "$AGENTS_SRC"/*.md; do
        name="$(basename "$f")"
        target="$AGENTS_DST/$name"
        if [ -L "$target" ]; then
            echo "  ⚠️  $name (symlink — run deploy to convert)"
        elif [ -f "$target" ]; then
            if [ "$(checksum "$f")" = "$(checksum "$target")" ]; then
                echo "  ✅ $name (synced)"
            else
                echo "  ⚠️  $name (modified)"
            fi
        else
            echo "  ❌ $name (not deployed)"
        fi
    done
    echo ""
    echo "Rules ($RULES_DST):"
    for f in "$RULES_SRC"/*.mdc; do
        name="$(basename "$f")"
        target="$RULES_DST/$name"
        if [ -L "$target" ]; then
            echo "  ⚠️  $name (symlink — run deploy to convert)"
        elif [ -f "$target" ]; then
            if [ "$(checksum "$f")" = "$(checksum "$target")" ]; then
                echo "  ✅ $name (synced)"
            else
                echo "  ⚠️  $name (modified)"
            fi
        else
            echo "  ❌ $name (not deployed)"
        fi
    done
    echo ""
    echo "Skills ($SKILLS_DST):"
    if [ -d "$SKILLS_SRC" ]; then
        for d in "$SKILLS_SRC"/*/; do
            name="$(basename "$d")"
            target="$SKILLS_DST/$name"
            if [ -L "$target" ]; then
                echo "  ⚠️  $name (symlink — run deploy to convert)"
            elif [ -d "$target" ]; then
                if [ "$(checksum_dir "${d%/}")" = "$(checksum_dir "$target")" ]; then
                    echo "  ✅ $name (synced)"
                else
                    echo "  ⚠️  $name (modified)"
                fi
            else
                echo "  ❌ $name (not deployed)"
            fi
        done
    fi
    echo ""
    if [ -f "$MANIFEST" ]; then
        echo "Manifest: $MANIFEST ($(wc -l < "$MANIFEST" | tr -d ' ') entries)"
    else
        echo "Manifest: not found (deploy has not been run with copy mode yet)"
    fi
    exit 0
fi

# --- Uninstall ---
if $UNINSTALL; then
    echo "=== Uninstalling Cursor Harness ==="
    removed=0

    if [ -f "$MANIFEST" ]; then
        while IFS= read -r entry; do
            if $DRY_RUN; then
                echo "  [dry-run] Would remove: $entry"
            elif [ -f "$entry" ]; then
                rm "$entry"
                echo "  Removed: $entry"
            elif [ -d "$entry" ]; then
                rm -r "$entry"
                echo "  Removed: $entry"
            else
                echo "  Skipped (not found): $entry"
                continue
            fi
            removed=$((removed + 1))
        done < "$MANIFEST"

        if ! $DRY_RUN; then
            rm "$MANIFEST"
            echo "  Removed: $MANIFEST"
        fi
    else
        echo "  No manifest found. Falling back to name-based detection..."
        echo ""
        for f in "$AGENTS_SRC"/*.md; do
            name="$(basename "$f")"
            target="$AGENTS_DST/$name"
            if [ -L "$target" ] || [ -f "$target" ]; then
                if $DRY_RUN; then
                    echo "  [dry-run] Would remove: $target"
                else
                    rm "$target"
                    echo "  Removed: $target"
                fi
                removed=$((removed + 1))
            fi
        done
        for f in "$RULES_SRC"/*.mdc; do
            name="$(basename "$f")"
            target="$RULES_DST/$name"
            if [ -L "$target" ] || [ -f "$target" ]; then
                if $DRY_RUN; then
                    echo "  [dry-run] Would remove: $target"
                else
                    rm "$target"
                    echo "  Removed: $target"
                fi
                removed=$((removed + 1))
            fi
        done
        if [ -d "$SKILLS_SRC" ]; then
            for d in "$SKILLS_SRC"/*/; do
                name="$(basename "$d")"
                target="$SKILLS_DST/$name"
                if [ -L "$target" ] || [ -d "$target" ]; then
                    if $DRY_RUN; then
                        echo "  [dry-run] Would remove: $target"
                    else
                        rm -r "$target"
                        echo "  Removed: $target"
                    fi
                    removed=$((removed + 1))
                fi
            done
        fi
    fi

    echo "Done. Removed $removed item(s)."
    exit 0
fi

# --- Deploy ---
echo "=== Deploying Cursor Harness ==="
$DRY_RUN && echo "(dry-run mode — no changes will be made)"
echo ""

for dir in "$AGENTS_DST" "$RULES_DST" "$SKILLS_DST"; do
    if [ ! -d "$dir" ]; then
        if $DRY_RUN; then
            echo "  [dry-run] Would create: $dir"
        else
            mkdir -p "$dir"
            echo "  Created: $dir"
        fi
    fi
done

manifest_entries=()
backup_needed=false

ensure_backup_dir() {
    if ! $backup_needed; then
        mkdir -p "$BACKUP_DIR"
        backup_needed=true
    fi
}

deploy_file() {
    local src="$1"
    local dst="$2"
    local name="$(basename "$src")"

    if [ -L "$dst" ]; then
        if ! $DRY_RUN; then
            ensure_backup_dir
            mv "$dst" "$BACKUP_DIR/$name"
            echo "  📦 Backed up (symlink): $dst → $BACKUP_DIR/$name"
        else
            echo "  [dry-run] Would backup symlink and copy: $name"
            return
        fi
    elif [ -f "$dst" ]; then
        if [ "$(checksum "$src")" = "$(checksum "$dst")" ]; then
            echo "  ✅ $name (synced)"
            manifest_entries+=("$dst")
            return
        fi
        if ! $DRY_RUN; then
            ensure_backup_dir
            mv "$dst" "$BACKUP_DIR/$name"
            echo "  📦 Backed up: $dst → $BACKUP_DIR/$name"
        else
            echo "  [dry-run] Would backup and copy: $name"
            return
        fi
    fi

    if $DRY_RUN; then
        echo "  [dry-run] Would copy: $src → $dst"
    else
        cp "$src" "$dst"
        echo "  📋 Copied: $name"
    fi
    manifest_entries+=("$dst")
}

deploy_dir() {
    local src="$1"
    local dst="$2"
    local name="$(basename "$src")"

    if [ -L "$dst" ]; then
        if ! $DRY_RUN; then
            ensure_backup_dir
            mv "$dst" "$BACKUP_DIR/$name"
            echo "  📦 Backed up (symlink): $dst → $BACKUP_DIR/$name"
        else
            echo "  [dry-run] Would backup symlink and copy: $name/"
            return
        fi
    elif [ -d "$dst" ]; then
        if [ "$(checksum_dir "$src")" = "$(checksum_dir "$dst")" ]; then
            echo "  ✅ $name/ (synced)"
            manifest_entries+=("$dst")
            return
        fi
        if ! $DRY_RUN; then
            ensure_backup_dir
            mv "$dst" "$BACKUP_DIR/$name"
            echo "  📦 Backed up: $dst → $BACKUP_DIR/$name"
        else
            echo "  [dry-run] Would backup and copy: $name/"
            return
        fi
    fi

    if $DRY_RUN; then
        echo "  [dry-run] Would copy: $src → $dst"
    else
        cp -r "$src" "$dst"
        echo "  📋 Copied: $name/"
    fi
    manifest_entries+=("$dst")
}

CLAUDE_AGENTS="$HOME/.claude/agents"
if [ -d "$CLAUDE_AGENTS" ]; then
    for f in "$AGENTS_SRC"/*.md; do
        name="$(basename "$f")"
        if [ -f "$CLAUDE_AGENTS/$name" ]; then
            echo "  ⚠️  WARNING: $name also exists in ~/.claude/agents/ (Cursor may load both)"
        fi
    done
fi

echo "Agents:"
for f in "$AGENTS_SRC"/*.md; do
    deploy_file "$f" "$AGENTS_DST/$(basename "$f")"
done

echo ""
echo "Rules:"
for f in "$RULES_SRC"/*.mdc; do
    deploy_file "$f" "$RULES_DST/$(basename "$f")"
done

echo ""
echo "Skills:"
if [ -d "$SKILLS_SRC" ]; then
    for d in "$SKILLS_SRC"/*/; do
        name="$(basename "$d")"
        deploy_dir "${d%/}" "$SKILLS_DST/$name"
    done
fi

if ! $DRY_RUN && [ ${#manifest_entries[@]} -gt 0 ]; then
    printf '%s\n' "${manifest_entries[@]}" > "$MANIFEST"
fi

echo ""
echo "Done."
if $DRY_RUN; then
    echo "(Re-run without --dry-run to apply changes)"
else
    echo "Manifest written: $MANIFEST (${#manifest_entries[@]} entries)"
fi
