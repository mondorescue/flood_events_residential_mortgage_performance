# ============================================================================
# Difference-in-Differences Analysis with Two-Stage Estimator (Event Study)
# ROBUSTNESS VERSION: alternate standard errors
#
# This is the robustness check referenced in the manuscript's SE/clustering
# discussion: standard errors are clustered at the event level (cluster_var
# = "histid") rather than the loan level, and 5 small/ambiguous historical
# events are excluded (histid in hist0005, hist0017, hist0037, hist0057,
# hist0058). Otherwise identical in specification to
# 03_event_study_did2s/event_study_did2s.R.
#
# NOTE: originally run via SLURM batch job (`batch.sh`); SLURM-specific code
# removed here. Run directly with `Rscript event_study_did2s_other_SE.R` or
# source() from run_all.R.
#
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)
library(did2s)
library(readxl)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "04_event_study_did2s_other_SE")
PATH_COMMON  <- file.path("output", "replication_package", "00_common")

dir.create(file.path(PATH_OUTPUT, "coefs_did2s"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATH_OUTPUT, "figs_did2s"), recursive = TRUE, showWarnings = FALSE)

source(file.path(PATH_COMMON, "helper_functions.R"))

# Load and prepare base data, excluding the 5 flagged historical events
y14m_fsf <- read_rds(file.path(PATH_DERIVED, "analyze.rds")) %>%
  rename(group_type = group) %>%
  mutate(
    date = ymd(as_of_mon_id * 100 + 1),
    post = if_else(relative_month > 0, 1, 0)
  ) %>%
  filter(!histid %in% c("hist0005", "hist0017", "hist0037", "hist0057", "hist0058"))

# Load model specifications
parameters <- read_xlsx(
  file.path(PATH_OUTPUT, "models_did2s_es.xlsx"),
  sheet = "Sheet1"
)

# Helper functions ----

create_quartiles <- function(data, var, prefix) {
  var_sym <- sym(var)
  quartile_col <- paste0(prefix, "_quartile")

  data %>%
    mutate(!!quartile_col := paste(prefix, ntile(!!var_sym, 4), "Q", sep = ""))
}

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

prepare_data_by_spec <- function(spec_name, base_data, yname, data_filter = NULL, cluster_var = NULL) {
  base_cols <- c("ID", "date", "relative_month", "post", yname, "group_type")

  if (!is.null(cluster_var) && !cluster_var %in% base_cols) {
    base_cols <- c(base_cols, cluster_var)
  }

  dat <- switch(
    spec_name,

    "None" = base_data %>%
      select(all_of(base_cols)),

    "SFHA" = base_data %>%
      select(all_of(base_cols), sfha_cat),

    "Inundation" = base_data %>%
      classify_inundation("hist_depth") %>%
      select(all_of(base_cols), inun_group),

    "FICO" = base_data %>%
      create_quartiles("fico_orig", "fico_orig") %>%
      select(all_of(base_cols), fico_orig_quartile),

    "DTI" = base_data %>%
      create_quartiles("dti_ratio", "dti") %>%
      select(all_of(base_cols), dti_quartile),

    "NFIP" = base_data %>%
      replace_na(list(perc_props_covered = 0)) %>%
      create_quartiles("perc_props_covered", "claims") %>%
      select(all_of(base_cols), claims_quartile),

    "Income" = base_data %>%
      mutate(income_orig = pi_amt_orig / dti_ratio * 100 * 12) %>%
      filter(!is.na(income_orig)) %>%
      create_quartiles("income_orig", "income_orig") %>%
      select(all_of(base_cols), income_orig_quartile),

    stop("Unknown specification: ", spec_name)
  )

  if (!is.null(data_filter)) {
    dat <- dat %>% filter(eval(parse(text = data_filter)))
  }

  dat
}

get_outcome_label <- function(yname) {
  case_when(
    yname == "ddlq90" ~ "1st mon. 90 days delinq.",
    yname == "ddlq120" ~ "1st mon. 120 days delinq.",
    yname == "dfc" ~ "1st mon. foreclosure, REO, invol. liquid.",
    yname == "prepaid" ~ "Prepayment",
    TRUE ~ yname
  )
}

run_did2s_model <- function(idx, params, base_data) {
  spec_name <- c(
    "None", "SFHA", "Inundation", "FICO", "DTI", "NFIP", "Income"
  )[params$Specification[idx] + 1]

  message(sprintf("%d: %s : %s", idx - 1, params$label[idx], spec_name))

  data_expr <- params$data[idx]
  data_filter <- if (str_detect(data_expr, "filter")) {
    str_extract(data_expr, "(?<=filter\\().*(?=\\))")
  } else {
    NULL
  }

  dat <- prepare_data_by_spec(
    spec_name, base_data, params$yname[idx], data_filter,
    cluster_var = params$cluster_var[idx]
  )

  reg <- did2s(
    data = dat,
    yname = params$yname[idx],
    first_stage = formula(params$first_stage[idx]),
    second_stage = formula(params$second_stage[idx]),
    treatment = params$treatment[idx],
    cluster_var = params$cluster_var[idx]
  )

  coefs <- clean_reg_fct(reg, dat, as.logical(params$interacted[idx]), twoway_in = FALSE)

  if (as.logical(params$interacted[idx])) {
    coefs <- coefs %>%
      mutate(Interacted_rel = str_extract(Interacted_rel, "[^:]*$"))
  }

  outcome_label <- get_outcome_label(params$yname[idx])

  plt <- plot_coefs_function(coefs, interacted = as.logical(params$interacted[idx]), ES = TRUE) +
    labs(
      title = paste("Effect on", outcome_label, "| Spec:", spec_name),
      caption = "Sample includes properties hit by a FSF disaster during 2014/06-2021/12. Loan+YearMonth FE"
    )

  csv_name <- str_replace(params$output[idx], "\\.png$", ".csv")
  write_csv(coefs, file.path(PATH_OUTPUT, "coefs_did2s", csv_name))
  ggsave(
    file.path(PATH_OUTPUT, "figs_did2s", params$output[idx]),
    plot = plt,
    height = 4,
    width = 9,
    bg = "white"
  )

  invisible(reg)
}

# ----------------------------------------------------------------------------
# Main execution
# ----------------------------------------------------------------------------

# Excel sheet for this robustness check only defines the 4 baseline
# dynamic-treatment-effect models (Figs 2A, 3A, S4A, S5A)
MODEL_INDICES <- 0:3
MODEL_INDICES <- MODEL_INDICES + 1

walk(MODEL_INDICES, ~run_did2s_model(.x, parameters, y14m_fsf))
