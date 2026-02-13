# Guide: Adopting New Models Into The ASAR Framework

This guide describes how to integrate a new assessment model into the ASAR report workflow
used in `/Users/jim/_mymods/pollock/asar`.

## 1) Integration Targets

A model is considered “ASAR-ready” when you can produce:

1. A standardized model-results object named `out_new` saved as `.rda`.
2. Optional model-comparison tables and figures saved as ASAR-compatible `.rda` artifacts.
3. A report skeleton that renders with `asar::create_template()`.

## 2) Required Data Contracts

### 2.1 `out_new` contract

`out_new` must be a data frame with the standard stockplotr/ASAR-style columns used by
`preamble.R` (included in the report folder).

Minimum practical columns to populate correctly:

- `label` (character)
- `estimate` (numeric)
- `uncertainty` (numeric or `NA`)
- `year` (integer or `NA`)
- `era` (character; use `"time"` for annual series rows)

The bridge script currently writes the full expected column set (33 columns), which is the
recommended pattern for compatibility.

### 2.2 Labels expected by ASAR preamble

The current preamble logic computes report quantities from these label patterns:

- `fishing_mortality` (time series, terminal year used for `Fend`)
- `f_msy` or `f_target` (used for `Ftarg`)
- `biomass` (terminal `Bend`)
- `biomass_msy` or `biomass_target` (used for `Btarg`/`Bmsy` logic)
- `spawning_biomass` (terminal `SBend`)
- `spawning_biomass_msy` (optional, benchmark context)
- `catch` (terminal total catch)
- `landings_observed` (terminal total landings)
- `natural_mortality`
- `beverton_holt_steepness`
- `recruitment_unfished`

If your model has different native names, map them to these labels in your parser.

### 2.3 Table `.rda` contract

Each table object must be saved as `rda <- list(...)` containing:

- `table` (usually a `flextable` object)
- `cap` (caption text)

Optional but recommended:

- `caption` (duplicate of `cap` for portability)

### 2.4 Figure `.rda` contract

Each figure object must be saved as `rda <- list(...)` containing:

- `figure` (`ggplot` or equivalent plot object)
- `cap` (caption text)
- `alt_text` (short accessibility description)

Optional but recommended:

- `caption` (duplicate of `cap`)

## 3) Recommended File Layout

Within `/Users/jim/_mymods/pollock/asar`:

- `build_asar_bridge.R` (or model-specific bridge script)
- `report/` (ASAR scaffold and `std_output_*.rda`)
- `tables/` (`*_table.rda` artifacts)
- `figures/` (`*_figure.rda` artifacts plus optional PNG/JPG)

## 4) Step-by-Step Workflow For A New Model

## Step 1: Build a parser from native output to `out_new`

Create a parser function that:

1. Reads native model output files.
2. Extracts annual time series for biomass, spawning biomass, recruitment, fishing mortality,
   and catch/landings where available.
3. Extracts static benchmarks (e.g., Fmsy, Bmsy, steepness, R0 proxy).
4. Maps all extracted values to ASAR labels.

Use the same row-builder pattern as in:

- `/Users/jim/_mymods/pollock/asar/build_asar_bridge.R`

## Step 2: Save standardized output

Save to report folder as a stable filename, e.g.:

- `report/std_output_<model>.rda`

where the saved object name is exactly `out_new`.

## Step 3: Generate tables and figures

At minimum, generate:

1. One terminal-status table.
2. One benchmark/reference table.
3. One time-series comparison figure (if multi-model context exists).

Save each as ASAR-compatible `.rda` objects in `tables/` and `figures/`.

## Step 4: Build or refresh the ASAR template

Run `asar::create_template()` with:

- `model_results` pointing to your `std_output_*.rda`
- `tables_dir` and `figures_dir` pointing to your artifact folders

## Step 5: Render and validate

Render the report and confirm that:

1. Inline preamble values resolve (no missing object errors).
2. Tables and figures appear with captions.
3. References to `@tbl-*` and `@fig-*` resolve.

## 5) QA Checklist (Use Every Time)

1. `out_new` file exists and loads.
2. Required labels are present.
3. `estimate` and `uncertainty` are numeric.
4. `year` values are valid for time-series rows.
5. Table `.rda` contains `table` and `cap`.
6. Figure `.rda` contains `figure`, `cap`, and `alt_text`.
7. `support_files/cjfas.csl` exists before render.
8. Quarto render succeeds without missing-resource errors.

## 6) Common Failure Modes

1. Missing `cap` in `.rda`: ASAR chunk generation will reference `..._cap` and fail.
2. Missing expected labels in `out_new`: preamble variables (e.g., `Ftarg`, `SBend`) become
   empty or ambiguous.
3. Non-numeric `estimate`: preamble calculations fail or return `NA` silently.
4. Multiple candidate rows for terminal/reference values: preamble may return vectors instead
   of scalars. Reduce to one value where appropriate.
5. Missing CSL/theme support files: render fails at pandoc stage.

## 7) Practical Pattern For Additional Models

For each new model, add a dedicated parser function and append its outputs to comparison
artifacts, while keeping one canonical base-model `out_new` for report preamble quantities.

A stable pattern is:

1. `parse_<model>_output()`
2. `to_out_new_<model>()`
3. `update_comparison_tables_figures()`
4. `render_asar_report()`

This keeps model ingestion modular while preserving a single, predictable report build path.
