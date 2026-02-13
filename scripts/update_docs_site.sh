#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPORT_HTML="$ROOT/report/Walleye_pollock_SAR_2025.html"
REPORT_ASSETS="$ROOT/report/SAR_EBS_Walleye_pollock_skeleton_files"
FIGURES_DIR="$ROOT/figures"
DOCS_DIR="$ROOT/docs"

if [[ ! -f "$REPORT_HTML" ]]; then
  echo "Missing report HTML: $REPORT_HTML" >&2
  echo "Render first, e.g.: quarto render $ROOT/report/SAR_EBS_Walleye_pollock_skeleton.qmd --to html" >&2
  exit 1
fi

rm -rf "$DOCS_DIR"
mkdir -p "$DOCS_DIR"

cp "$REPORT_HTML" "$DOCS_DIR/index.html"
cp -R "$REPORT_ASSETS" "$DOCS_DIR/"
cp -R "$FIGURES_DIR" "$DOCS_DIR/"

# Site only needs static image files in docs/figures.
find "$DOCS_DIR/figures" -type f ! \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.svg' -o -iname '*.webp' \) -delete

echo "Updated docs site at $DOCS_DIR"
