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

make_out_row <- function(label, estimate, uncertainty = NA_real_, year = NA_integer_, era = NA_character_) {
  n <- max(length(estimate), length(uncertainty), length(year), length(era))
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

  data.frame(
    label = rep(label, n),
    estimate = as.numeric(estimate),
    year = as.integer(year),
    fleet = NA_character_,
    sex = NA_character_,
    area = NA_character_,
    growth_pattern = NA_character_,
    uncertainty = as.numeric(uncertainty),
    module_name = NA_character_,
    uncertainty_label = "stddev",
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
    nsim = NA_integer_,
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
  catch_obs <- as.numeric(pm$obs_catch)

  n_year <- length(years)
  if (length(catch_obs) != n_year) {
    catch_obs <- rep(NA_real_, n_year)
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

  assessment_year_opt <- get_opt(args, "assessment-year", as.character(terminal_year))
  assessment_year <- as.integer(assessment_year_opt)

  std_output_file <- file.path(report_dir, "std_output_admb.rda")
  save(out_new, file = std_output_file)

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
