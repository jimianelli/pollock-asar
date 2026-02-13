#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPORT_HTML="$ROOT/report/Walleye_pollock_SAR_2025.html"
REPORT_ASSETS="$ROOT/report/SAR_EBS_Walleye_pollock_skeleton_files"
FIGURES_DIR="$ROOT/figures"
DOCS_DIR="$ROOT/docs"
ASSESS_DIR="$DOCS_DIR/assessment"

if [[ ! -f "$REPORT_HTML" ]]; then
  echo "Missing report HTML: $REPORT_HTML" >&2
  echo "Render first, e.g.: quarto render $ROOT/report/SAR_EBS_Walleye_pollock_skeleton.qmd --to html" >&2
  exit 1
fi

# Render website pages (index + guide) to docs/.
quarto render "$ROOT"

# Copy assessment artifacts used by the embedded iframe on index.qmd.
rm -rf "$ASSESS_DIR"
mkdir -p "$ASSESS_DIR"
cp "$REPORT_HTML" "$ASSESS_DIR/Walleye_pollock_SAR_2025.html"
cp -R "$REPORT_ASSETS" "$ASSESS_DIR/"
cp -R "$FIGURES_DIR" "$ASSESS_DIR/"

# Embedded assessment only needs static image files in assessment/figures.
find "$ASSESS_DIR/figures" -type f ! \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.svg' -o -iname '*.webp' \) -delete

# Disable Jekyll processing to avoid any underscore/path quirks.
touch "$DOCS_DIR/.nojekyll"

echo "Updated docs site at $DOCS_DIR (with embedded assessment at $ASSESS_DIR)"
