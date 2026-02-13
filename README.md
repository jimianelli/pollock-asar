# ASAR Bridge For EBS Pollock

This folder bridges assessment outputs from:

- `/Users/jim/_mymods/afsc-assessments/ebs_pollock` (preferred)
- `/Users/jim/_mymods/afsc-assessments/ebs_pollock_safe` (fallback)

into ASAR report structure using:

- `/Users/jim/_mymods/asar`

The workflow avoids direct SS3 `Report.sso` conversion and instead builds an ASAR-compatible
`out_new` object from ADMB outputs (`pm.rep`, `pm.par`, `F40_t.rep`) plus model-comparison
tables/figures from `compares.qs`. If available, a `pmout` RDS file is also used to enrich
`out_new` with survey indices, projection series, scenario metrics, and expected landings.

## Run

From this folder:

```bash
Rscript build_asar_bridge.R
```

## What it creates

- `report/`: ASAR report scaffold and section files
- `report/std_output_admb.rda`: ASAR-compatible `out_new`
- `tables/*.rda`: ASAR-ready tables (`table` + `caption`)
- `figures/*.rda`: ASAR-ready figures (`figure` + `caption` + `alt_text`)
- `figures/*.png`: copied figures from `ebs_pollock/doc/figs` (if enabled)

## Optional arguments

```bash
Rscript build_asar_bridge.R \
  --ebs-dir=/Users/jim/_mymods/noaa-afsc/ebs_pollock \
  --pmout-rds=/Users/jim/_mymods/pollock/pmout24.rds \
  --assessment-year=2024 \
  --report-year=2025 \
  --office=AFSC \
  --region='Eastern Bering Sea' \
  --species='Walleye pollock' \
  --spp-latin='Gadus chalcogrammus' \
  --copy-figures=true \
  --write-template=true
```

## Adopting new models

See:

- `/Users/jim/_mymods/pollock/asar/MODEL_ADOPTION_GUIDE.qmd`

## GitHub Pages

This repo publishes a static site from `/docs` (GitHub Pages).
The left sidebar includes:

1. `Assessment Report` (embedded assessment HTML)
2. `Assessment Report (ASAR-native Draft)` (parallel draft built from ASAR chapters)
3. `Assessment PDF` (embedded assessment PDF)
4. `Model Adoption Guide` (rendered from `MODEL_ADOPTION_GUIDE.qmd`)

To refresh the published site after rendering:

```bash
/Users/jim/_mymods/pollock/asar/scripts/update_docs_site.sh
```

`update_docs_site.sh` now imports assessment text/content from:

- `/Users/jim/_mymods/afsc-assessments/ebs_pollock/ebswp.qmd` when available
- otherwise `/Users/jim/_mymods/afsc-assessments/ebs_pollock_safe/ebswp.qmd`

You can override the source directory explicitly:

```bash
ASAR_SOURCE_DIR=/path/to/assessment-repo /Users/jim/_mymods/pollock/asar/scripts/update_docs_site.sh
```

To refresh the second, ASAR-native draft document without touching the current frozen-source flow:

```bash
/Users/jim/_mymods/pollock/asar/scripts/update_docs_site_asar_native.sh
```

This renders from `/Users/jim/_mymods/pollock/asar/report_asar_native/` and publishes to
`/Users/jim/_mymods/pollock/asar/docs/assessment_asar/`.

Override the model source directory used for ADMB/bridge inputs:

```bash
ASAR_EBS_DIR=/path/to/ebs_pollock /Users/jim/_mymods/pollock/asar/scripts/update_docs_site_asar_native.sh
```
