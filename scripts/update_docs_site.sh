#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SOURCE_DIR="/Users/jim/_mymods/afsc-assessments/ebs_pollock_safe"
SOURCE_QMD="$SOURCE_DIR/ebswp.qmd"
SOURCE_FREEZE_HTML_JSON="$SOURCE_DIR/.quarto/_freeze/ebswp/execute-results/html.json"

STAGE_DIR="$ROOT/report/ebswp_frozen_stage"
STAGE_QMD="$STAGE_DIR/ebswp_frozen.qmd"
STAGE_HTML="$STAGE_DIR/ebswp.html"
STAGE_PDF="$STAGE_DIR/ebswp.pdf"

DOCS_DIR="$ROOT/docs"
ASSESS_DIR="$DOCS_DIR/assessment"

if [[ ! -f "$SOURCE_QMD" ]]; then
  echo "Missing source assessment qmd: $SOURCE_QMD" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_FREEZE_HTML_JSON" ]]; then
  echo "Missing frozen execution results: $SOURCE_FREEZE_HTML_JSON" >&2
  exit 1
fi

# Stage the safe assessment assets locally.
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$SOURCE_DIR/doc" "$STAGE_DIR/"
cp "$SOURCE_DIR/cjfas.csl" "$STAGE_DIR/"
if [[ -f "$SOURCE_DIR/mystyle.css" ]]; then
  cp "$SOURCE_DIR/mystyle.css" "$STAGE_DIR/"
fi

# Build a renderable assessment qmd from frozen execution output.
jq -r '.result.markdown' "$SOURCE_FREEZE_HTML_JSON" > "$STAGE_QMD"

# Remove custom filter reference that doesn't exist in this repository.
sed -i '' '/^filters:/,/^format:/ { /^filters:/d; /^  - highlight-text/d; }' "$STAGE_QMD"

pushd "$STAGE_DIR" >/dev/null

# Ensure referenced figure files exist in the expected extension.
rg -o 'doc/figs/[A-Za-z0-9_\-]+\.(png|pdf|jpg|jpeg|svg|webp)' "$STAGE_QMD" | sort -u > refs.txt
while read -r f; do
  [[ -f "$f" ]] && continue
  base="${f%.*}"
  ext="${f##*.}"
  if [[ "$ext" == "png" && -f "${base}.pdf" ]]; then
    sips -s format png "${base}.pdf" --out "${base}.png" >/dev/null
  elif [[ "$ext" == "pdf" && -f "${base}.png" ]]; then
    sips -s format pdf "${base}.png" --out "${base}.pdf" >/dev/null
  elif [[ "$ext" == "jpg" && -f "${base}.png" ]]; then
    cp "${base}.png" "${base}.jpg"
  elif [[ "$ext" == "jpeg" && -f "${base}.png" ]]; then
    cp "${base}.png" "${base}.jpeg"
  fi
done < refs.txt

# Render the imported safe assessment.
quarto render "$STAGE_QMD" --to html --output ebswp.html
quarto render "$STAGE_QMD" --to pdf --output ebswp.pdf

popd >/dev/null

if [[ ! -f "$STAGE_HTML" ]]; then
  echo "Failed to create assessment HTML in stage dir: $STAGE_HTML" >&2
  exit 1
fi

# Render website pages (index + guide) to docs/.
quarto render "$ROOT"

# Copy assessment artifacts used by the embedded iframe on index.qmd.
rm -rf "$ASSESS_DIR"
mkdir -p "$ASSESS_DIR"

cp "$STAGE_HTML" "$ASSESS_DIR/Walleye_pollock_SAR_2025.html"
if [[ -f "$STAGE_PDF" ]]; then
  cp "$STAGE_PDF" "$ASSESS_DIR/Walleye_pollock_SAR_2025.pdf"
fi
if [[ -d "$STAGE_DIR/ebswp_frozen_files" ]]; then
  cp -R "$STAGE_DIR/ebswp_frozen_files" "$ASSESS_DIR/"
fi
cp -R "$STAGE_DIR/doc" "$ASSESS_DIR/"
if [[ -f "$STAGE_DIR/mystyle.css" ]]; then
  cp "$STAGE_DIR/mystyle.css" "$ASSESS_DIR/"
fi

# Disable Jekyll processing to avoid any underscore/path quirks.
touch "$DOCS_DIR/.nojekyll"

echo "Updated docs site at $DOCS_DIR (with embedded assessment at $ASSESS_DIR)"
