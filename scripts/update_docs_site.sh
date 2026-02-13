#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPORT_HTML_ROOT="$ROOT/Walleye_pollock_SAR_2025.html"
REPORT_HTML_REPORT="$ROOT/report/Walleye_pollock_SAR_2025.html"
REPORT_QMD="$ROOT/report/SAR_EBS_Walleye_pollock_skeleton.qmd"
REPORT_PDF="$ROOT/Walleye_pollock_SAR_2025.pdf"
REPORT_ASSETS="$ROOT/report/SAR_EBS_Walleye_pollock_skeleton_files"
REPORT_SUPPORT="$ROOT/report/support_files"
FIGURES_DIR="$ROOT/figures"
DOCS_DIR="$ROOT/docs"
ASSESS_DIR="$DOCS_DIR/assessment"

if [[ -f "$REPORT_HTML_ROOT" ]]; then
  REPORT_HTML="$REPORT_HTML_ROOT"
elif [[ -f "$REPORT_HTML_REPORT" ]]; then
  REPORT_HTML="$REPORT_HTML_REPORT"
else
  echo "Missing report HTML: $REPORT_HTML_ROOT (or $REPORT_HTML_REPORT)" >&2
  echo "Render first, e.g.: quarto render $ROOT/report/SAR_EBS_Walleye_pollock_skeleton.qmd --to html" >&2
  exit 1
fi

# Render website pages (index + guide) to docs/.
quarto render "$ROOT"

# Ensure report-local figures path exists for PDF rendering.
if [[ ! -e "$ROOT/report/figures" ]]; then
  ln -s ../figures "$ROOT/report/figures"
fi

# Build assessment PDF if it's missing.
if [[ ! -f "$REPORT_PDF" ]]; then
  echo "Assessment PDF missing; attempting to render: $REPORT_PDF"
  if ! (
    cd "$ROOT/report" && \
    quarto render SAR_EBS_Walleye_pollock_skeleton.qmd --to pdf --output ../Walleye_pollock_SAR_2025.pdf
  ); then
    echo "Warning: PDF render failed; site will be published without PDF artifact." >&2
  fi
fi

# Copy assessment artifacts used by the embedded iframe on index.qmd.
rm -rf "$ASSESS_DIR"
mkdir -p "$ASSESS_DIR"
cp "$REPORT_HTML" "$ASSESS_DIR/Walleye_pollock_SAR_2025.html"
if [[ -f "$REPORT_PDF" ]]; then
  cp "$REPORT_PDF" "$ASSESS_DIR/Walleye_pollock_SAR_2025.pdf"
fi
cp -R "$REPORT_ASSETS" "$ASSESS_DIR/"
if [[ -d "$REPORT_SUPPORT" ]]; then
  cp -R "$REPORT_SUPPORT" "$ASSESS_DIR/"
fi
cp -R "$FIGURES_DIR" "$ASSESS_DIR/"

# Embedded assessment only needs static image files in assessment/figures.
find "$ASSESS_DIR/figures" -type f ! \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.svg' -o -iname '*.webp' \) -delete
# Explicitly exclude deprecated cartoon from published docs.
rm -f "$ASSESS_DIR/figures/pollock_cartoon.png"

# Disable Jekyll processing to avoid any underscore/path quirks.
touch "$DOCS_DIR/.nojekyll"

echo "Updated docs site at $DOCS_DIR (with embedded assessment at $ASSESS_DIR)"
