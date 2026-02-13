#!/usr/bin/env Rscript

get_opt <- function(args, name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit) == 0) {
    return(default)
  }
  sub(paste0("^--", name, "="), "", hit[1])
}

require_pkgs <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      "Missing required package(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

read_pm_par_value <- function(lines, key) {
  idx <- which(trimws(lines) == paste0("# ", key, ":"))
  if (length(idx) == 0 || idx[1] >= length(lines)) {
    return(NA_real_)
  }
  vals <- strsplit(trimws(lines[idx[1] + 1]), "\\s+")[[1]]
  as.numeric(vals[1])
}

as_numeric_clean <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  y[!is.finite(y)] <- NA_real_
  y
}

make_out_row <- function(
    label,
    estimate,
    uncertainty = NA_real_,
    year = NA_integer_,
    era = NA_character_,
    fleet = NA_character_,
    module_name = NA_character_,
    uncertainty_label = "stddev",
    nsim = NA_integer_
) {
  n <- max(
    length(estimate),
    length(uncertainty),
    length(year),
    length(era),
    length(fleet),
    length(module_name),
    length(uncertainty_label),
    length(nsim)
  )
  recycle <- function(x) {
    if (length(x) == n) {
      return(x)
    }
    if (length(x) == 1) {
      return(rep(x, n))
    }
    stop("Cannot recycle vector to row size for label: ", label, call. = FALSE)
  }

  estimate <- recycle(estimate)
  uncertainty <- recycle(uncertainty)
  year <- recycle(year)
  era <- recycle(era)
  fleet <- recycle(fleet)
  module_name <- recycle(module_name)
  uncertainty_label <- recycle(uncertainty_label)
  nsim <- recycle(nsim)

  data.frame(
    label = rep(label, n),
    estimate = as_numeric_clean(estimate),
    year = as.integer(year),
    fleet = as.character(fleet),
    sex = NA_character_,
    area = NA_character_,
    growth_pattern = NA_character_,
    uncertainty = as_numeric_clean(uncertainty),
    module_name = as.character(module_name),
    uncertainty_label = as.character(uncertainty_label),
    time = as.numeric(year),
    era = as.character(era),
    month = NA_integer_,
    season = NA_integer_,
    subseason = NA_integer_,
    birthseas = NA_integer_,
    initial = NA_integer_,
    likelihood = NA_character_,
    platoon = NA_integer_,
    age = NA_integer_,
    bio_pattern = NA_integer_,
    settlement = NA_integer_,
    morph = NA_integer_,
    type = NA_character_,
    factor = NA_integer_,
    part = NA_integer_,
    kind = NA_character_,
    nsim = as.integer(nsim),
    bin = NA_integer_,
    age_a = NA_integer_,
    length_bins = NA_character_,
    count = NA_integer_,
    block = NA_character_,
    stringsAsFactors = FALSE
  )
}

build_out_new_from_admb <- function(pm_rep_path, pm_par_path, f40_rep_path) {
  pm <- ebswp::read_rep(pm_rep_path)
  f40 <- readr::read_table(f40_rep_path, show_col_types = FALSE, progress = FALSE)
  par_lines <- readLines(pm_par_path, warn = FALSE)

  years <- as.integer(pm$SSB[, 1])
  ssb <- as.numeric(pm$SSB[, 2])
  ssb_se <- as.numeric(pm$SSB[, 3])
  recruits <- as.numeric(pm$R[, 2])
  recruits_se <- as.numeric(pm$R[, 3])
  fishing_mort <- as.numeric(pm$SER[, 2])
  fishing_mort_se <- as.numeric(pm$SER[, 3])
  catch_obs <- as_numeric_clean(pm$obs_catch)
  catch_pred <- as_numeric_clean(pm$pred_catch)

  n_year <- length(years)
  if (length(catch_obs) != n_year) {
    catch_obs <- rep(NA_real_, n_year)
  }
  if (length(catch_pred) != n_year) {
    catch_pred <- rep(NA_real_, n_year)
  }

  f40_years <- as.integer(f40$Year)
  idx <- match(years, f40_years)
  biomass <- as.numeric(f40$Bfshble[idx])

  terminal_year <- max(years, na.rm = TRUE)
  terminal_row <- which(f40$Year == terminal_year)
  if (length(terminal_row) == 0) {
    terminal_row <- nrow(f40)
  }

  log_rzero <- read_pm_par_value(par_lines, "log_Rzero")
  if (is.na(log_rzero)) {
    log_rzero <- read_pm_par_value(par_lines, "log_avgrec")
  }
  recruitment_unfished <- ifelse(is.na(log_rzero), NA_real_, exp(log_rzero))

  out_new <- dplyr::bind_rows(
    make_out_row("spawning_biomass", ssb, ssb_se, years, "time"),
    make_out_row("biomass", biomass, NA_real_, years, "time"),
    make_out_row("recruitment", recruits, recruits_se, years, "time"),
    make_out_row("fishing_mortality", fishing_mort, fishing_mort_se, years, "time"),
    make_out_row("catch", catch_obs, NA_real_, years, "time"),
    make_out_row("landings_observed", catch_obs, NA_real_, years, "time"),
    make_out_row("landings_expected", catch_pred, NA_real_, years, "time"),
    make_out_row("f_msy", as.numeric(f40$Fmsy[terminal_row])),
    make_out_row("terminal_fishing_mortality", fishing_mort[which.max(years)], fishing_mort_se[which.max(years)]),
    make_out_row("biomass_msy", as.numeric(f40$Bmsy[terminal_row])),
    make_out_row("spawning_biomass_msy", as.numeric(f40$Bmsy[terminal_row])),
    make_out_row("natural_mortality", mean(as.numeric(pm$M), na.rm = TRUE)),
    make_out_row("beverton_holt_steepness", as.numeric(pm$steepness[1])),
    make_out_row("recruitment_unfished", recruitment_unfished)
  )

  list(
    out_new = out_new,
    terminal_year = terminal_year,
    f40 = f40
  )
}

normalize_out_new <- function(out_new) {
  out_new$estimate <- as_numeric_clean(out_new$estimate)
  out_new$uncertainty <- as_numeric_clean(out_new$uncertainty)
  out_new$year <- suppressWarnings(as.integer(out_new$year))
  out_new$time <- ifelse(!is.na(out_new$year), as.numeric(out_new$year), NA_real_)

  keep <- !is.na(out_new$estimate) & !is.na(out_new$label) & nzchar(out_new$label)
  out_new <- out_new[keep, , drop = FALSE]

  key_cols <- c("label", "year", "fleet", "era", "nsim", "estimate", "uncertainty", "module_name")
  out_new <- out_new[!duplicated(out_new[key_cols]), , drop = FALSE]

  ord <- order(
    ifelse(is.na(out_new$era), "", out_new$era),
    out_new$label,
    ifelse(is.na(out_new$fleet), "", out_new$fleet),
    ifelse(is.na(out_new$year), Inf, out_new$year),
    ifelse(is.na(out_new$nsim), Inf, out_new$nsim)
  )
  out_new <- out_new[ord, , drop = FALSE]
  rownames(out_new) <- NULL

  out_new
}

validate_out_new <- function(out_new) {
  required_labels <- c(
    "fishing_mortality",
    "f_msy",
    "biomass",
    "biomass_msy",
    "spawning_biomass",
    "catch",
    "landings_observed",
    "natural_mortality",
    "beverton_holt_steepness",
    "recruitment_unfished"
  )
  missing_labels <- setdiff(required_labels, unique(out_new$label))
  if (length(missing_labels) > 0) {
    stop("Missing required out_new labels: ", paste(missing_labels, collapse = ", "), call. = FALSE)
  }

  if (any(!is.finite(out_new$estimate))) {
    stop("Found non-finite values in out_new$estimate after normalization.", call. = FALSE)
  }

  core_time_labels <- c("spawning_biomass", "recruitment", "fishing_mortality", "catch", "landings_observed", "biomass")
  bad_core_time <- out_new$label %in% core_time_labels & out_new$era == "time" & is.na(out_new$year)
  if (any(bad_core_time)) {
    bad_labels <- unique(out_new$label[bad_core_time])
    stop("Core time-series rows missing year for labels: ", paste(bad_labels, collapse = ", "), call. = FALSE)
  }

  message("out_new QA passed: rows=", nrow(out_new), ", labels=", length(unique(out_new$label)))
}

append_index_series <- function(out_new, pmout, year_key, obs_key, pred_key, fleet_name, sd_key = NULL) {
  if (!all(c(year_key, obs_key, pred_key) %in% names(pmout))) {
    return(out_new)
  }

  yrs <- as.integer(pmout[[year_key]])
  obs <- as_numeric_clean(pmout[[obs_key]])
  pred <- as_numeric_clean(pmout[[pred_key]])

  n <- min(length(yrs), length(obs), length(pred))
  if (is.na(n) || n <= 0) {
    return(out_new)
  }

  yrs <- yrs[seq_len(n)]
  obs <- obs[seq_len(n)]
  pred <- pred[seq_len(n)]
  sd_obs <- rep(NA_real_, n)
  if (!is.null(sd_key) && sd_key %in% names(pmout)) {
    sd_raw <- as_numeric_clean(pmout[[sd_key]])
    if (length(sd_raw) >= n) {
      sd_obs <- sd_raw[seq_len(n)]
    }
  }

  dplyr::bind_rows(
    out_new,
    make_out_row("indices", obs, sd_obs, yrs, "time", fleet = fleet_name, module_name = "pmout"),
    make_out_row("indices_expected", pred, NA_real_, yrs, "time", fleet = fleet_name, module_name = "pmout")
  )
}

append_scenario_vector <- function(out_new, pmout, source_key, label, terminal_year) {
  if (!(source_key %in% names(pmout))) {
    return(out_new)
  }
  values <- as_numeric_clean(pmout[[source_key]])
  if (length(values) == 0) {
    return(out_new)
  }

  dplyr::bind_rows(
    out_new,
    make_out_row(
      label = label,
      estimate = values,
      uncertainty = NA_real_,
      year = rep(terminal_year, length(values)),
      era = "scenario",
      module_name = "pmout",
      nsim = seq_along(values)
    )
  )
}

append_projection_matrix <- function(
    out_new,
    pmout,
    source_key,
    label,
    terminal_year,
    start_offset = 0L,
    uncertainty_key = NULL
) {
  if (!(source_key %in% names(pmout))) {
    return(out_new)
  }

  mat <- as.matrix(pmout[[source_key]])
  if (!is.matrix(mat) || nrow(mat) == 0 || ncol(mat) == 0) {
    return(out_new)
  }

  uncertainty_mat <- matrix(NA_real_, nrow = nrow(mat), ncol = ncol(mat))
  if (!is.null(uncertainty_key) && uncertainty_key %in% names(pmout)) {
    unc_raw <- as.matrix(pmout[[uncertainty_key]])
    if (is.matrix(unc_raw) && nrow(unc_raw) > 0 && ncol(unc_raw) > 0) {
      n_row <- min(nrow(mat), nrow(unc_raw))
      n_col <- min(ncol(mat), ncol(unc_raw))
      uncertainty_mat[seq_len(n_row), seq_len(n_col)] <- unc_raw[seq_len(n_row), seq_len(n_col)]
    }
  }

  proj_years <- terminal_year + start_offset + seq_len(ncol(mat)) - 1L
  rows <- lapply(seq_len(nrow(mat)), function(i) {
    make_out_row(
      label = label,
      estimate = as_numeric_clean(mat[i, ]),
      uncertainty = as_numeric_clean(uncertainty_mat[i, ]),
      year = proj_years,
      era = "projection",
      module_name = "pmout",
      nsim = i
    )
  })

  dplyr::bind_rows(out_new, dplyr::bind_rows(rows))
}

append_pmout_enrichment <- function(out_new, pmout_path, terminal_year) {
  if (is.null(pmout_path) || !nzchar(pmout_path) || !file.exists(pmout_path)) {
    message("No pmout enrichment applied (file not found): ", pmout_path)
    return(out_new)
  }

  pmout <- readRDS(pmout_path)
  if (!is.list(pmout)) {
    message("Skipping pmout enrichment because object is not a list: ", pmout_path)
    return(out_new)
  }

  years <- integer()
  if ("SSB" %in% names(pmout) && is.matrix(pmout$SSB) && ncol(pmout$SSB) >= 1) {
    years <- as.integer(pmout$SSB[, 1])
  }

  if (length(years) > 0 && "age3plus" %in% names(pmout)) {
    age3plus <- as_numeric_clean(pmout$age3plus)
    n <- min(length(years), length(age3plus))
    if (n > 0) {
      age3plus_sd <- rep(NA_real_, n)
      if ("age3plus.sd" %in% names(pmout)) {
        sd_vals <- as_numeric_clean(pmout[["age3plus.sd"]])
        if (length(sd_vals) >= n) {
          age3plus_sd <- sd_vals[seq_len(n)]
        }
      }
      out_new <- dplyr::bind_rows(
        out_new,
        make_out_row(
          label = "biomass_age3plus",
          estimate = age3plus[seq_len(n)],
          uncertainty = age3plus_sd,
          year = years[seq_len(n)],
          era = "time",
          module_name = "pmout"
        )
      )
    }
  }

  out_new <- append_index_series(out_new, pmout, "yr_bts", "ob_bts", "eb_bts", "bts", "sd_ob_bts")
  out_new <- append_index_series(out_new, pmout, "yr_ats", "ob_ats", "eb_ats", "ats", "sd_ob_ats")
  out_new <- append_index_series(out_new, pmout, "yrs_avo", "obs_avo", "pred_avo", "avo", "obs_avo_std")
  out_new <- append_index_series(out_new, pmout, "yrs_cpue", "obs_cpue", "pred_cpue", "cpue", "obs_cpue_std")

  out_new <- append_scenario_vector(out_new, pmout, "Fcur_Fmsy", "status_fcur_over_fmsy", terminal_year)
  out_new <- append_scenario_vector(out_new, pmout, "Bcur_Bmsy", "status_bcur_over_bmsy", terminal_year)
  out_new <- append_scenario_vector(out_new, pmout, "Fcur_F35", "status_fcur_over_f35", terminal_year)
  out_new <- append_scenario_vector(out_new, pmout, "pfcur_fmsy", "status_prob_f_above_fmsy", terminal_year)
  out_new <- append_scenario_vector(out_new, pmout, "pbcur_bmsy", "status_prob_b_above_bmsy", terminal_year)
  out_new <- append_scenario_vector(out_new, pmout, "pfcur_f35", "status_prob_f_above_f35", terminal_year)

  # Projection matrices are scenario x year. Offsets are based on PM output conventions.
  out_new <- append_projection_matrix(
    out_new = out_new,
    pmout = pmout,
    source_key = "future_SSB",
    label = "projection_ssb",
    terminal_year = terminal_year,
    start_offset = 0L,
    uncertainty_key = "future_SSB.sd"
  )
  out_new <- append_projection_matrix(
    out_new = out_new,
    pmout = pmout,
    source_key = "future_F",
    label = "projection_fishing_mortality",
    terminal_year = terminal_year,
    start_offset = 0L
  )
  out_new <- append_projection_matrix(
    out_new = out_new,
    pmout = pmout,
    source_key = "future_SER",
    label = "projection_fishing_mortality_ser",
    terminal_year = terminal_year,
    start_offset = 1L
  )
  out_new <- append_projection_matrix(
    out_new = out_new,
    pmout = pmout,
    source_key = "future_catch",
    label = "projection_catch",
    terminal_year = terminal_year,
    start_offset = 1L
  )

  out_new
}

build_comparison_artifacts <- function(compares_path, tables_dir, figures_dir, assessment_year, f40_df) {
  compares <- qs::qread(compares_path)
  ts_list <- lapply(compares, function(x) x$ts)
  ts_df <- dplyr::bind_rows(ts_list)

  if (!all(c("type", "value", "Year", "source") %in% names(ts_df))) {
    stop("Unexpected `compares.qs` format. Expected columns: type, value, Year, source.", call. = FALSE)
  }

  ts_df <- ts_df |>
    dplyr::mutate(
      Year = as.integer(Year),
      value = as.numeric(value),
      source = as.character(source),
      type = as.character(type)
    )

  metrics <- c("SSB", "Recruits")
  plot_df <- ts_df |>
    dplyr::filter(type %in% metrics, !is.na(value), Year <= assessment_year)

  model_plot <- ggplot2::ggplot(plot_df, ggplot2::aes(x = Year, y = value, color = source)) +
    ggplot2::geom_line(linewidth = 0.7, alpha = 0.9) +
    ggplot2::facet_wrap(~type, scales = "free_y", ncol = 1) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::labs(
      x = "Year",
      y = "Estimate",
      color = "Model"
    )

  rda <- list(
    figure = model_plot,
    cap = paste0("Model comparison of SSB and recruitment through ", assessment_year, "."),
    caption = paste0("Model comparison of SSB and recruitment through ", assessment_year, "."),
    alt_text = paste0("Line plot comparing SSB and recruitment trajectories by model through ", assessment_year, ".")
  )
  save(rda, file = file.path(figures_dir, "model_timeseries_figure.rda"))

  terminal_tbl <- ts_df |>
    dplyr::filter(type %in% metrics, Year == assessment_year) |>
    dplyr::select(Model = source, Metric = type, Value = value) |>
    dplyr::group_by(Model, Metric) |>
    dplyr::summarise(Value = dplyr::first(Value), .groups = "drop") |>
    tidyr::pivot_wider(names_from = Metric, values_from = Value) |>
    dplyr::arrange(Model) |>
    dplyr::mutate(
      SSB = round(SSB, 2),
      Recruits = round(Recruits, 2)
    )

  if (nrow(terminal_tbl) == 0) {
    terminal_tbl <- data.frame(
      Model = "No data",
      SSB = NA_real_,
      Recruits = NA_real_
    )
  }

  terminal_ft <- flextable::flextable(terminal_tbl)
  terminal_ft <- flextable::autofit(terminal_ft)

  rda <- list(
    table = terminal_ft,
    cap = paste0("Terminal year (", assessment_year, ") SSB and recruitment by model."),
    caption = paste0("Terminal year (", assessment_year, ") SSB and recruitment by model.")
  )
  save(rda, file = file.path(tables_dir, "terminal_status_table.rda"))

  ref_row <- f40_df |>
    dplyr::filter(Year == assessment_year)
  if (nrow(ref_row) == 0) {
    ref_row <- f40_df |>
      dplyr::filter(Year <= assessment_year) |>
      dplyr::slice_tail(n = 1)
  }

  ref_tbl <- ref_row |>
    dplyr::transmute(
      Year = as.integer(Year),
      SSB = round(as.numeric(SSB), 2),
      Bmsy = round(as.numeric(Bmsy), 2),
      `B/Bmsy` = round(as.numeric(`B/Bmsy`), 3),
      meanF = round(as.numeric(meanF), 4),
      Fmsy = round(as.numeric(Fmsy), 4),
      `F/Fmsy` = round(as.numeric(`F/Fmsy`), 3),
      F35 = round(as.numeric(F35), 4)
    )

  ref_ft <- flextable::flextable(ref_tbl)
  ref_ft <- flextable::autofit(ref_ft)

  rda <- list(
    table = ref_ft,
    cap = paste0("Reference-point summary from ADMB output for year ", ref_tbl$Year[1], "."),
    caption = paste0("Reference-point summary from ADMB output for year ", ref_tbl$Year[1], ".")
  )
  save(rda, file = file.path(tables_dir, "reference_points_table.rda"))
}

copy_existing_figures <- function(source_fig_dir, target_fig_dir) {
  if (!dir.exists(source_fig_dir)) {
    message("Figure source directory not found: ", source_fig_dir)
    return(invisible(NULL))
  }
  fig_files <- list.files(
    source_fig_dir,
    pattern = "\\.(png|jpg|jpeg)$",
    ignore.case = TRUE,
    full.names = TRUE
  )
  if (length(fig_files) == 0) {
    message("No figure files found in: ", source_fig_dir)
    return(invisible(NULL))
  }
  file.copy(fig_files, target_fig_dir, overwrite = TRUE)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  script_args <- commandArgs(trailingOnly = FALSE)
  script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)])
  script_dir <- if (length(script_file) == 0) getwd() else dirname(normalizePath(script_file))

  require_pkgs(c("asar", "ebswp", "readr", "dplyr", "tidyr", "ggplot2", "flextable", "qs"))

  ebs_dir <- get_opt(args, "ebs-dir", "/Users/jim/_mymods/noaa-afsc/ebs_pollock")
  report_year <- as.integer(get_opt(args, "report-year", format(Sys.Date(), "%Y")))
  office <- get_opt(args, "office", "AFSC")
  region <- get_opt(args, "region", "Eastern Bering Sea")
  species <- get_opt(args, "species", "Walleye pollock")
  spp_latin <- get_opt(args, "spp-latin", "Gadus chalcogrammus")
  copy_figures <- tolower(get_opt(args, "copy-figures", "true")) %in% c("true", "1", "yes", "y")
  write_template <- tolower(get_opt(args, "write-template", "true")) %in% c("true", "1", "yes", "y")
  pmout_rds <- get_opt(args, "pmout-rds", file.path(dirname(script_dir), "pmout24.rds"))

  pm_rep_path <- file.path(ebs_dir, "runs", "lastyr", "pm.rep")
  pm_par_path <- file.path(ebs_dir, "runs", "lastyr", "pm.par")
  f40_rep_path <- file.path(ebs_dir, "runs", "lastyr", "F40_t.rep")
  compares_path <- file.path(ebs_dir, "compares.qs")
  source_fig_dir <- file.path(ebs_dir, "doc", "figs")

  for (p in c(pm_rep_path, pm_par_path, f40_rep_path, compares_path)) {
    if (!file.exists(p)) {
      stop("Required file not found: ", p, call. = FALSE)
    }
  }

  report_dir <- file.path(script_dir, "report")
  tables_dir <- file.path(script_dir, "tables")
  figures_dir <- file.path(script_dir, "figures")

  dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  parsed <- build_out_new_from_admb(pm_rep_path, pm_par_path, f40_rep_path)
  out_new <- parsed$out_new
  terminal_year <- parsed$terminal_year
  f40_df <- parsed$f40
  out_new <- append_pmout_enrichment(out_new, pmout_rds, terminal_year)
  out_new <- normalize_out_new(out_new)
  validate_out_new(out_new)

  message("out_new rows: ", nrow(out_new), " | labels: ", length(unique(out_new$label)))

  assessment_year_opt <- get_opt(args, "assessment-year", as.character(terminal_year))
  assessment_year <- as.integer(assessment_year_opt)

  std_output_file <- file.path(report_dir, "std_output_admb.rda")
  save(out_new, file = std_output_file, compress = "xz")

  build_comparison_artifacts(
    compares_path = compares_path,
    tables_dir = tables_dir,
    figures_dir = figures_dir,
    assessment_year = assessment_year,
    f40_df = f40_df
  )

  if (copy_figures) {
    copy_existing_figures(
      source_fig_dir = source_fig_dir,
      target_fig_dir = figures_dir
    )
  }

  if (write_template) {
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(report_dir)

    asar::create_template(
      format = "html",
      office = office,
      region = region,
      species = species,
      spp_latin = spp_latin,
      year = report_year,
      file_dir = report_dir,
      model_results = "std_output_admb.rda",
      tables_dir = script_dir,
      figures_dir = script_dir,
      new_template = TRUE
    )

    csl_src <- system.file("resources", "cjfas.csl", package = "asar")
    csl_dst <- file.path(report_dir, "support_files", "cjfas.csl")
    if (file.exists(csl_src)) {
      file.copy(csl_src, csl_dst, overwrite = TRUE)
    }
  } else {
    message("Skipping ASAR template regeneration (--write-template=false).")
  }

  message("ASAR bridge build complete.")
  message("Report skeleton: ", file.path(report_dir, list.files(report_dir, pattern = "skeleton\\.qmd$")))
  message("Tables dir: ", tables_dir)
  message("Figures dir: ", figures_dir)
  message("Model results file: ", std_output_file)
}

main()
