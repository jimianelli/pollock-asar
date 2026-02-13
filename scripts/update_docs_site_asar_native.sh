#!/usr/bin/env zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PRIMARY_EBS_DIR="/Users/jim/_mymods/noaa-afsc/ebs_pollock"
EBS_DIR="${ASAR_EBS_DIR:-$PRIMARY_EBS_DIR}"

BRIDGE_REPORT_DIR="$ROOT/report"
NATIVE_REPORT_DIR="$ROOT/report_asar_native"
REPORT_QMD="$NATIVE_REPORT_DIR/SAR_EBS_Walleye_pollock_asar_native.qmd"
REPORT_HTML="$NATIVE_REPORT_DIR/Walleye_pollock_SAR_2025_asar_native.html"
REPORT_FILES_DIR="$NATIVE_REPORT_DIR/Walleye_pollock_SAR_2025_asar_native_files"

DOCS_DIR="$ROOT/docs"
ASSESS_DIR="$DOCS_DIR/assessment_asar"

deref_symlinks() {
  local root="$1"
  while IFS= read -r link; do
    if [[ -f "$link" ]]; then
      local tmp="${link}.resolved_tmp"
      cp -L "$link" "$tmp"
      rm "$link"
      mv "$tmp" "$link"
    elif [[ ! -e "$link" ]]; then
      rm -f "$link"
    fi
  done < <(find "$root" -type l)
}

if [[ ! -d "$EBS_DIR" ]]; then
  echo "Missing EBS source directory: $EBS_DIR" >&2
  echo "Set ASAR_EBS_DIR to override." >&2
  exit 1
fi

if [[ ! -f "$REPORT_QMD" ]]; then
  echo "Missing ASAR-native report qmd: $REPORT_QMD" >&2
  exit 1
fi

echo "Using EBS model directory: $EBS_DIR"

Rscript "$ROOT/build_asar_bridge.R" --ebs-dir="$EBS_DIR" --write-template=false

cp "$BRIDGE_REPORT_DIR/std_output_admb.rda" "$NATIVE_REPORT_DIR/std_output_admb.rda"
if [[ -d "$BRIDGE_REPORT_DIR/support_files" ]]; then
  rm -rf "$NATIVE_REPORT_DIR/support_files"
  cp -R "$BRIDGE_REPORT_DIR/support_files" "$NATIVE_REPORT_DIR/support_files"
fi

quarto render "$REPORT_QMD" \
  -P ebs_dir:"$EBS_DIR" \
  -P asar_root:"$ROOT" \
  -P tables_dir:"$ROOT/tables" \
  -P figures_dir:"$ROOT/figures"

if [[ ! -f "$REPORT_HTML" ]]; then
  echo "Failed to create ASAR-native HTML report: $REPORT_HTML" >&2
  exit 1
fi

"$ROOT/scripts/update_docs_site.sh"

rm -rf "$ASSESS_DIR"
mkdir -p "$ASSESS_DIR"

cp "$REPORT_HTML" "$ASSESS_DIR/Walleye_pollock_SAR_2025_asar_native.html"
if [[ -d "$REPORT_FILES_DIR" ]]; then
  cp -R "$REPORT_FILES_DIR" "$ASSESS_DIR/"
fi
if [[ -d "$NATIVE_REPORT_DIR/support_files" ]]; then
  cp -R "$NATIVE_REPORT_DIR/support_files" "$ASSESS_DIR/"
fi
if [[ -d "$ROOT/figures" ]]; then
  cp -R "$ROOT/figures" "$ASSESS_DIR/"
fi
deref_symlinks "$ASSESS_DIR"

echo "Updated ASAR-native docs output at $ASSESS_DIR"
