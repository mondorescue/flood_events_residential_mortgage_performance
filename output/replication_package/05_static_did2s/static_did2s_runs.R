# ============================================================================
# Difference-in-Differences Analysis with Two-Stage Estimator (Static)
# Analyzes flood impact on mortgage outcomes across multiple specifications
#
# Produces the main battery of static ATT sub-group estimates
# (Figures 2B-G, 3B-G, S4B-G, S6, S8; prepayment specs S5B-G noted as
# "no variation, run event study version" in the original parameter sheet
# and are therefore skipped here -- see 03_event_study_did2s for those).
#
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)
library(did2s)
library(readxl)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "05_static_did2s")
PATH_COMMON  <- file.path("output", "replication_package", "00_common")

dir.create(file.path(PATH_OUTPUT, "coefs_did2s"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATH_OUTPUT, "figs_did2s"), recursive = TRUE, showWarnings = FALSE)

source(file.path(PATH_COMMON, "helper_functions.R"))

# Load model specifications --------------------------------------------------
parameters <- read_xlsx(file.path(PATH_OUTPUT, "models_did2s_static.xlsx"), sheet = "Sheet1") %>%
  mutate(
    data_filter = if_else(
      str_detect(data, "filter"),
      str_extract(data, "(?<=filter\\().*(?=\\))"),
      NA_character_
    ),
    spec_name = c("FICO", "DTI", "Income", "SFHA", "Inundation", "NFIP", "Inundation x SFHA", "Inundation x FICO")[Specification + 1],
    is_interacted = as.logical(interacted),
    csv_path = file.path(PATH_OUTPUT, "coefs_did2s", str_replace(output, "\\.png$", ".csv")),
    fig_path = file.path(PATH_OUTPUT, "figs_did2s", output)
  )

# Load and prepare data -------------------------------------------------------
y14m_fsf <- read_rds(file.path(PATH_DERIVED, "analyze.rds")) %>%
  rename(group_type = group) %>%
  filter(between(relative_month, -24, 24)) %>%
  mutate(
    date = ymd(as_of_mon_id * 100 + 1),
    post = if_else(relative_month >= 0, 1L, 0L)
  )

# Create outcome variables ----------------------------------------------------
y14m_fsf <- y14m_fsf %>%
  arrange(ID, relative_month) %>%
  group_by(ID) %>%
  mutate(
    dlq90 = as.integer(slider::slide_int(ddlq90, sum, .before = 24, .complete = FALSE) > 0),
    dlq120 = as.integer(slider::slide_int(ddlq120, sum, .before = 24, .complete = FALSE) > 0),
    fc = as.integer(slider::slide_int(dfc, sum, .before = 24, .complete = FALSE) > 0),
    pp = prepaid
  ) %>%
  ungroup()

# Pre-compute quartile assignments used across multiple specs ----------------
y14m_fsf <- y14m_fsf %>%
  mutate(
    fico_orig_quartile = paste("FICO", paste0(ntile(fico_orig, 4), "Q")),
    dti_quartile = paste("DTI", paste0(ntile(dti_ratio, 4), "Q")),
    income_orig = pi_amt_orig / dti_ratio * 100 * 12,
    income_orig_quartile = if_else(
      !is.na(income_orig),
      paste("Income", paste0(ntile(income_orig, 4), "Q")),
      NA_character_
    ),
    claims_quartile = paste("Claims", paste0(ntile(coalesce(perc_props_covered, 0), 4), "Q"))
  )

# Helper functions -------------------------------------------------------------

#' Classify properties by inundation depth relative to foundation
classify_inundation <- function(data, depth_col, prefix = "") {
  data %>%
    mutate(
      depth = coalesce(.data[[depth_col]], 0),
      ffe = coalesce(foundation_height, 0),
      inundation_depth = depth - ffe,
      ffe_flooded_depth = if_else(inundation_depth > 0, inundation_depth, NA_real_),
      inun_group = case_when(
        !is.na(ffe_flooded_depth) ~ paste0(
          "FFE ", prefix, "flooded ",
          c("1Q", "2Q", "3Q", "4Q")[ntile(ffe_flooded_depth, 4)]
        ),
        depth > 0 ~ paste0("FFE ", prefix, "not flooded"),
        .default = paste0(prefix, "Control")
      )
    ) %>%
    select(-depth, -ffe, -inundation_depth, -ffe_flooded_depth)
}

#' Prepare dataset for a specific model specification
prepare_data_by_spec <- function(spec_name, base_data, yname, data_filter = NULL) {
  base_cols <- c("ID", "date", "relative_month", "post", yname, "group_type")

  dat <- switch(
    spec_name,

    "FICO" = base_data %>%
      select(all_of(base_cols), fico_orig_quartile),

    "DTI" = base_data %>%
      select(all_of(base_cols), dti_quartile),

    "Income" = base_data %>%
      filter(!is.na(income_orig)) %>%
      select(all_of(base_cols), income_orig_quartile),

    "SFHA" = base_data %>%
      select(all_of(base_cols), sfha_cat),

    "Inundation" = base_data %>%
      classify_inundation("hist_depth") %>%
      select(all_of(base_cols), inun_group),

    "NFIP" = base_data %>%
      select(all_of(base_cols), claims_quartile),

    "Inundation x SFHA" = base_data %>%
      classify_inundation("hist_depth") %>%
      select(all_of(base_cols), inun_group, sfha_cat),

    "Inundation x FICO" = base_data %>%
      classify_inundation("hist_depth") %>%
      select(all_of(base_cols), inun_group, fico_orig_quartile),

    stop("Unknown specification: ", spec_name)
  )

  if (!is.na(data_filter)) {
    dat <- dat %>% filter(eval(parse(text = data_filter)))
  }

  dat
}

#' Get human-readable label for outcome variable
get_outcome_label <- function(yname) {
  labels <- c(
    dlq90 = "90 days delinq.",
    dlq120 = "120 days delinq.",
    fc = "Foreclosure, REO, invol., liquid",
    pp = "Prepayment"
  )

  labels[[yname]] %||% yname
}

#' Run DiD two-stage estimation for a single model specification
run_did2s_model <- function(idx, params, base_data) {
  row <- params[idx, ]

  message("Running model ", idx, ": ", row$spec_name, " - ", row$yname)

  dat <- prepare_data_by_spec(row$spec_name, base_data, row$yname, row$data_filter)

  reg <- did2s(
    data = dat,
    yname = row$yname,
    first_stage = formula(row$first_stage),
    second_stage = formula(row$second_stage),
    treatment = row$treatment,
    cluster_var = row$cluster_var
  )

  coefs <- clean_reg_fct(
    reg_in = reg,
    dat_in = dat,
    interact_in = row$is_interacted,
    twoway_in = TRUE
  )

  if (row$is_interacted) {
    coefs <- coefs %>%
      mutate(Interacted_rel = str_extract(Interacted_rel, "[^:]*$"))
  }

  plt <- plot_coefs_function(
    clean_coefs = coefs,
    interacted = row$is_interacted,
    ES = FALSE
  ) +
    labs(
      title = paste("Effect on", get_outcome_label(row$yname), "| Spec:", row$spec_name),
      caption = "Sample: Properties hit by FSF disaster 2014/06-2021/12. Loan+YearMonth FE"
    )

  write_csv(coefs, row$csv_path)
  ggsave(
    filename = row$fig_path,
    plot = plt,
    height = 4,
    width = 9,
    bg = "white"
  )

  invisible(coefs)
}

# ----------------------------------------------------------------------------
# Run all models
# ----------------------------------------------------------------------------

# Model indices to run (0-based `idx` in the Excel sheet, converted to
# 1-based row indices). This set covers Figs 2B-G, 3B-G, S4B-G, S6, and the
# inundation x FICO disclosure specs (34-41); excludes the Harvey-specific
# (18-19) and per-hurricane (22-33) specs, which live in their own scripts.
model_indices <- c(0:17, 20:21, 34:41) + 1
walk(model_indices, ~run_did2s_model(.x, parameters, y14m_fsf))
