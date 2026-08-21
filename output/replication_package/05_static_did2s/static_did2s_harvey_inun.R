# ============================================================================
# DID2S Static Analysis - Harvey x Inundation Group
#
# Estimates the static ATT of Hurricane Harvey flooding on 90-day delinquency
# across inundation-depth-at-FFE sub-groups, restricted to TX/LA properties.
# Supports comparing modeled (First Street) vs. observed (FEMA high-water-mark)
# inundation data as a robustness check (Figure S2).
#
# Set CONFIG$use_observed_data to TRUE/FALSE to toggle between the two.
#
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)
library(did2s)
library(slider)
library(readxl)

# Configuration ---------------------------------------------------------------
CONFIG <- list(
  use_observed_data = TRUE,  # TRUE = observed (FEMA) flood data, FALSE = modeled (First Street)
  event_window = 48,
  delinquency_window = 24
)

PATH_DERIVED <- file.path("synthetic-data")
PATH_RAW     <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "05_static_did2s")
PATH_COMMON  <- file.path("output", "replication_package", "00_common")

dir.create(file.path(PATH_OUTPUT, "coefs_did2s"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATH_OUTPUT, "figs_did2s"), recursive = TRUE, showWarnings = FALSE)

source(file.path(PATH_COMMON, "helper_functions.R"))

# ============================================================================
# DATA LOADING
# ============================================================================

# Load primary dataset, restricted to TX/LA properties in the Harvey event
# (or the shared control group)
y14m_fsf <- read_rds(file.path(PATH_DERIVED, "analyze.rds")) %>%
  mutate(
    date = ymd(as_of_mon_id * 100 + 1),
    post = as.integer(relative_month > 0)
  ) %>%
  rename(group_type = group) %>%
  filter(
    state_id %in% c(22, 48),
    histid == "hist1006" | group_type == "C"
  )

# Load observed Harvey inundation data (FEMA high-water-mark interpolation)
harvey_obs <- read_csv(file.path(PATH_RAW, "tx_harvey_obs.csv"), show_col_types = FALSE) %>%
  mutate(obs_group_type = "T")

y14m_fsf <- y14m_fsf %>%
  left_join(harvey_obs, by = "property_id") %>%
  replace_na(list(obs_group_type = "C"))

# ============================================================================
# FEATURE ENGINEERING
# ============================================================================

# Calculate observed event timing (Harvey landfall: September 2017)
y14m_fsf <- y14m_fsf %>%
  mutate(obs_event_date = if_else(!is.na(obs_depth_cm), 201709L, NA_integer_)) %>%
  group_by(property_id) %>%
  fill(obs_event_date, .direction = "updown") %>%
  ungroup() %>%
  mutate(
    hist_obs_event_date = obs_event_date,
    obs_relative_month = round(time_length(
      date - ymd(hist_obs_event_date * 100 + 1),
      "month"
    )),
    obs_relative_month = case_when(
      is.na(obs_relative_month) ~ 0L,
      obs_relative_month > CONFIG$event_window ~ CONFIG$event_window,
      obs_relative_month < -CONFIG$event_window ~ -CONFIG$event_window,
      TRUE ~ as.integer(obs_relative_month)
    ),
    obs_post = as.integer(obs_relative_month > 0)
  )

# Create cumulative 90-day delinquency indicators (24-month rolling window),
# separately for the modeled and observed event timing
y14m_fsf <- y14m_fsf %>%
  arrange(ID, relative_month) %>%
  group_by(ID) %>%
  mutate(dlq90 = as.integer(slide_int(ddlq90, sum, .before = CONFIG$delinquency_window, .complete = FALSE) > 0)) %>%
  ungroup() %>%
  arrange(ID, obs_relative_month) %>%
  group_by(ID) %>%
  mutate(dlq90_obs = as.integer(slide_int(ddlq90, sum, .before = CONFIG$delinquency_window, .complete = FALSE) > 0)) %>%
  ungroup()

# ============================================================================
# INUNDATION GROUP CLASSIFICATION
# ============================================================================

classify_inundation <- function(data, depth_col, prefix = "") {
  ffe_col <- if (prefix == "obs ") "ffe_obs" else "ffe"

  data %>%
    replace_na(setNames(list(0), depth_col)) %>%
    mutate(
      !!ffe_col := if_else(is.na(foundation_height), 0, foundation_height),
      inundation_depth = .data[[depth_col]] - .data[[ffe_col]],
      ffe_flooded_cat = if_else(inundation_depth > 0, "Flooded", "Not flooded"),
      ffe_flooded_depth = if_else(ffe_flooded_cat == "Flooded", inundation_depth, NA_real_),
      inun_group = case_when(
        ntile(ffe_flooded_depth, 4) == 1 ~ paste0("FFE ", prefix, "flooded 1Q"),
        ntile(ffe_flooded_depth, 4) == 2 ~ paste0("FFE ", prefix, "flooded 2Q"),
        ntile(ffe_flooded_depth, 4) == 3 ~ paste0("FFE ", prefix, "flooded 3Q"),
        ntile(ffe_flooded_depth, 4) == 4 ~ paste0("FFE ", prefix, "flooded 4Q"),
        is.na(ffe_flooded_depth) & .data[[depth_col]] > 0 ~ paste0("FFE ", prefix, "not flooded"),
        is.na(ffe_flooded_depth) & .data[[depth_col]] == 0 ~ paste0(prefix, "Control")
      )
    )
}

# Apply classification based on data type (modeled vs. observed)
if (CONFIG$use_observed_data) {
  dat <- y14m_fsf %>%
    filter(state_id == 48) %>%
    classify_inundation(depth_col = "obs_depth_cm", prefix = "obs ") %>%
    rename(inun_group_obs = inun_group) %>%
    select(ID, date, obs_relative_month, obs_post, obs_group_type, dlq90_obs, inun_group_obs)
} else {
  dat <- y14m_fsf %>%
    classify_inundation(depth_col = "hist_depth", prefix = "") %>%
    select(ID, date, relative_month, post, group_type, dlq90, inun_group)
}

# ============================================================================
# MODEL SETUP
# ============================================================================

# Load model parameters (idx 18 = modeled Harvey-inundation spec,
# idx 19 = observed Harvey-inundation spec)
parameters <- read_xlsx(file.path(PATH_OUTPUT, "models_did2s_static.xlsx"), sheet = "Sheet1")
idx <- if_else(CONFIG$use_observed_data, 19, 18)

model_spec <- list(
  yname = parameters$yname[idx + 1],
  first_stage = formula(parameters$first_stage[idx + 1]),
  second_stage = formula(parameters$second_stage[idx + 1]),
  treatment = parameters$treatment[idx + 1],
  cluster_var = parameters$cluster_var[idx + 1],
  interacted = as.logical(parameters$interacted[idx + 1]),
  output_file = parameters$output[idx + 1]
)

cat("\n=== Data Summary ===\n")
print(glimpse(dat))
cat("\n=== Inundation Group Distribution ===\n")
print(count(dat, if (CONFIG$use_observed_data) inun_group_obs else inun_group))

# ============================================================================
# MODEL ESTIMATION
# ============================================================================

cat("\n=== Running DID2S Model ===\n")

reg_i <- did2s(
  data = dat,
  yname = model_spec$yname,
  first_stage = model_spec$first_stage,
  second_stage = model_spec$second_stage,
  treatment = model_spec$treatment,
  cluster_var = model_spec$cluster_var
)

# ============================================================================
# RESULTS PROCESSING
# ============================================================================

coefs <- clean_reg_fct(
  reg_in = reg_i,
  dat_in = dat,
  interact_in = model_spec$interacted,
  twoway_in = TRUE,
  obsdat = CONFIG$use_observed_data
)

if (model_spec$interacted) {
  coefs <- coefs %>%
    mutate(Interacted_rel = str_extract(Interacted_rel, "[^:]*$"))
}

# ============================================================================
# VISUALIZATION
# ============================================================================

plot <- plot_coefs_function(
  clean_coefs = coefs,
  interacted = model_spec$interacted,
  ES = FALSE
) +
  labs(
    title = "Effect on 90-Day Delinquency | Specification: Inundation Depth Quartiles",
    caption = "Sample: Properties affected by FSF disaster 2014/06-2021/12\nFixed Effects: Loan + Year-Month"
  )

# ============================================================================
# SAVE OUTPUTS
# ============================================================================

csv_file <- str_replace(model_spec$output_file, "\\.png$", ".csv")
path_csv <- file.path(PATH_OUTPUT, "coefs_did2s", csv_file)
path_plot <- file.path(PATH_OUTPUT, "figs_did2s", model_spec$output_file)

write_csv(coefs, path_csv)
ggsave(path_plot, plot = plot, height = 4, width = 9, bg = "white")

cat("\n=== Outputs Saved ===\n")
cat("Coefficients:", path_csv, "\n")
cat("Plot:", path_plot, "\n")
