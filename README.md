# ASAR Bridge For EBS Pollock

This folder bridges assessment outputs from:

- `/Users/jim/_mymods/noaa-afsc/ebs_pollock`

into ASAR report structure using:

- `/Users/jim/_mymods/asar`

The workflow avoids direct SS3 `Report.sso` conversion and instead builds an ASAR-compatible
`out_new` object from ADMB outputs (`pm.rep`, `pm.par`, `F40_t.rep`) plus model-comparison
tables/figures from `compares.qs`.

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
  --assessment-year=2024 \
  --report-year=2025 \
  --office=AFSC \
  --region='Eastern Bering Sea' \
  --species='Walleye pollock' \
  --spp-latin='Gadus chalcogrammus' \
  --copy-figures=true
```

## Adopting new models

See:

- `/Users/jim/_mymods/pollock/asar/MODEL_ADOPTION_GUIDE.qmd`

## GitHub Pages

This repo publishes a static site from `/docs` (GitHub Pages).
The left sidebar includes:

1. `Assessment Report` (embedded assessment HTML)
2. `Model Adoption Guide` (rendered from `MODEL_ADOPTION_GUIDE.qmd`)

To refresh the published site after rendering:

```bash
quarto render /Users/jim/_mymods/pollock/asar/report/SAR_EBS_Walleye_pollock_skeleton.qmd --to html
/Users/jim/_mymods/pollock/asar/scripts/update_docs_site.sh
```
