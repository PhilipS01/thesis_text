#!/bin/bash
#
# grammarly_export.sh
#
# Interactive chapter picker for prepping thesis prose for Grammarly.
# Lets you multi-select which chapters to export, strips LaTeX markup
# with detex, and copies the combined plain text straight to your
# clipboard -- ready to paste into grammarly.com.
#
# USAGE:
#   1. Save into your thesis project, e.g. ~/thesis/scripts/grammarly_export.sh
#   2. chmod +x scripts/grammarly_export.sh
#   3. Run from your project root: ./scripts/grammarly_export.sh
#
# REQUIREMENTS:
#   - detex (ships with TeX Live; check with `which detex`)
#   - macOS (uses osascript for the picker UI and pbcopy for the clipboard)

set -euo pipefail

CHAPTERS_DIR="chapters"

if ! command -v detex &> /dev/null; then
    echo "Error: 'detex' not found on your PATH."
    echo "Try: sudo tlmgr install detex"
    exit 1
fi

if [ ! -d "$CHAPTERS_DIR" ]; then
    echo "Error: '$CHAPTERS_DIR' directory not found."
    echo "Run this from your thesis project root (the folder containing 'chapters/')."
    exit 1
fi

# Collect chapter files, sorted (Bash 3.2 compatible -- no mapfile/readarray)
CHAPTER_FILES=()
while IFS= read -r line; do
    CHAPTER_FILES+=("$line")
done < <(find "$CHAPTERS_DIR" -maxdepth 1 -name "*.tex" | sort)

if [ ${#CHAPTER_FILES[@]} -eq 0 ]; then
    echo "No .tex files found in '$CHAPTERS_DIR/'."
    exit 1
fi

# Build a comma-separated, quoted list of chapter names (without .tex) for AppleScript
NAMES=()
for f in "${CHAPTER_FILES[@]}"; do
    NAMES+=("$(basename "$f" .tex)")
done

# Build AppleScript list literal: {"einleitung", "theorie", ...}
AS_LIST=$(printf '"%s", ' "${NAMES[@]}")
AS_LIST="{${AS_LIST%, }}"

# Show native macOS multi-select dialog
SELECTION=$(osascript <<EOF
set chapterList to $AS_LIST
set chosen to choose from list chapterList with title "Grammarly Export" with prompt "Select chapter(s) to export (Cmd-click for multiple):" default items {} with multiple selections allowed
if chosen is false then
    return ""
else
    set AppleScript's text item delimiters to linefeed
    set chosenStr to chosen as text
    set AppleScript's text item delimiters to ""
    return chosenStr
end if
EOF
)

if [ -z "$SELECTION" ]; then
    echo "No chapters selected. Aborted."
    exit 0
fi

# Build detex output for each selected chapter, concatenated
TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_OUT"' EXIT

echo "Exporting selected chapters:"
while IFS= read -r chapter_name; do
    [ -z "$chapter_name" ] && continue
    src_file="$CHAPTERS_DIR/${chapter_name}.tex"

    if [ ! -f "$src_file" ]; then
        echo "  Warning: $src_file not found, skipping."
        continue
    fi

    echo "  - $chapter_name"

    {
        echo ""
        echo "===== CHAPTER: $chapter_name ====="
        echo ""
        detex "$src_file" 2>/dev/null
    } >> "$TMP_OUT"
done <<< "$SELECTION"

# Collapse excess blank lines
sed -i.bak '/^[[:space:]]*$/N;/\n[[:space:]]*$/D' "$TMP_OUT" && rm -f "$TMP_OUT.bak"

# Copy to clipboard
pbcopy < "$TMP_OUT"

WORDCOUNT=$(wc -w < "$TMP_OUT" | tr -d ' ')

echo ""
echo "Done. Copied to clipboard (${WORDCOUNT} words)."
echo "Paste directly into grammarly.com."
