#!/usr/bin/env bash
set -euo pipefail

# Cursor Personal Harness — Deploy Script
# Symlinks agents/ and rules/ from this project to ~/.cursor/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CURSOR_DIR="$HOME/.cursor"
BACKUP_DIR="$CURSOR_DIR/.backup/$(date +%Y%m%d-%H%M%S)"

AGENTS_SRC="$PROJECT_DIR/agents"
RULES_SRC="$PROJECT_DIR/rules"
AGENTS_DST="$CURSOR_DIR/agents"
RULES_DST="$CURSOR_DIR/rules"

DRY_RUN=false
UNINSTALL=false
STATUS=false

usage() {
    echo "Usage: $0 [--dry-run|--uninstall|--status]"
    echo ""
    echo "  (no args)    Deploy symlinks to ~/.cursor/"
    echo "  --dry-run    Show what would be done without making changes"
    echo "  --uninstall  Remove symlinks created by this script"
    echo "  --status     Show current symlink status"
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

# --- Status ---
if $STATUS; then
    echo "=== Cursor Harness Status ==="
    echo ""
    echo "Agents ($AGENTS_DST):"
    for f in "$AGENTS_SRC"/*.md; do
        name="$(basename "$f")"
        target="$AGENTS_DST/$name"
        if [ -L "$target" ]; then
            actual="$(readlink "$target")"
            if [ "$actual" = "$f" ]; then
                echo "  ✅ $name → $actual"
            else
                echo "  ⚠️  $name → $actual (unexpected target)"
            fi
        elif [ -f "$target" ]; then
            echo "  ⚠️  $name (regular file, not symlink)"
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
            actual="$(readlink "$target")"
            if [ "$actual" = "$f" ]; then
                echo "  ✅ $name → $actual"
            else
                echo "  ⚠️  $name → $actual (unexpected target)"
            fi
        elif [ -f "$target" ]; then
            echo "  ⚠️  $name (regular file, not symlink)"
        else
            echo "  ❌ $name (not deployed)"
        fi
    done
    exit 0
fi

# --- Uninstall ---
if $UNINSTALL; then
    echo "=== Uninstalling Cursor Harness ==="
    removed=0
    for f in "$AGENTS_SRC"/*.md; do
        name="$(basename "$f")"
        target="$AGENTS_DST/$name"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
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
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
            if $DRY_RUN; then
                echo "  [dry-run] Would remove: $target"
            else
                rm "$target"
                echo "  Removed: $target"
            fi
            removed=$((removed + 1))
        fi
    done
    echo "Done. Removed $removed symlink(s)."
    exit 0
fi

# --- Deploy ---
echo "=== Deploying Cursor Harness ==="
$DRY_RUN && echo "(dry-run mode — no changes will be made)"
echo ""

# Create target directories
for dir in "$AGENTS_DST" "$RULES_DST"; do
    if [ ! -d "$dir" ]; then
        if $DRY_RUN; then
            echo "  [dry-run] Would create: $dir"
        else
            mkdir -p "$dir"
            echo "  Created: $dir"
        fi
    fi
done

backup_needed=false
link_file() {
    local src="$1"
    local dst="$2"
    local name="$(basename "$src")"

    if [ -L "$dst" ]; then
        local current="$(readlink "$dst")"
        if [ "$current" = "$src" ]; then
            echo "  ✅ $name (already linked)"
            return
        fi
        # Symlink to different target — backup and replace
        if ! $DRY_RUN; then
            if ! $backup_needed; then
                mkdir -p "$BACKUP_DIR"
                backup_needed=true
            fi
            mv "$dst" "$BACKUP_DIR/$name"
            echo "  📦 Backed up: $dst → $BACKUP_DIR/$name"
        else
            echo "  [dry-run] Would backup and relink: $name"
            return
        fi
    elif [ -f "$dst" ]; then
        # Regular file — backup before replacing
        if ! $DRY_RUN; then
            if ! $backup_needed; then
                mkdir -p "$BACKUP_DIR"
                backup_needed=true
            fi
            mv "$dst" "$BACKUP_DIR/$name"
            echo "  📦 Backed up: $dst → $BACKUP_DIR/$name"
        else
            echo "  [dry-run] Would backup and link: $name"
            return
        fi
    fi

    if $DRY_RUN; then
        echo "  [dry-run] Would link: $dst → $src"
    else
        ln -s "$src" "$dst"
        echo "  🔗 Linked: $dst → $src"
    fi
}

# Check for Claude Code agent conflicts
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
    link_file "$f" "$AGENTS_DST/$(basename "$f")"
done

echo ""
echo "Rules:"
for f in "$RULES_SRC"/*.mdc; do
    link_file "$f" "$RULES_DST/$(basename "$f")"
done

echo ""
echo "Done."
$DRY_RUN && echo "(Re-run without --dry-run to apply changes)"
