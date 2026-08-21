# ============================================================================
# DID2S Static Analysis - Per-Hurricane Sub-Sample Models
#
# Re-estimates the static ATT specification separately for each of the six
# hurricane-driven flood events in the sample (Harvey, Irma, Michael,
# Florence, Matthew, Hermine), for both 90-day delinquency and foreclosure
# outcomes. Produces the per-event heterogeneity results shown in Figure S7.
#
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)
library(did2s)
library(slider)
library(readxl)

CONFIG <- list(
  delinquency_window = 24,
  spec_idx = c(22:33) + 1  # rows in models_did2s_static.xlsx (1-based)
)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "05_static_did2s")
PATH_COMMON  <- file.path("output", "replication_package", "00_common")

dir.create(file.path(PATH_OUTPUT, "coefs_did2s"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATH_OUTPUT, "figs_did2s"), recursive = TRUE, showWarnings = FALSE)

source(file.path(PATH_COMMON, "helper_functions.R"))

# ============================================================================
# DATA PREPARATION
# ============================================================================

# Load full dataset
y14m_fsf_raw <- read_rds(file.path(PATH_DERIVED, "analyze.rds")) %>%
  mutate(
    date = ymd(as_of_mon_id * 100 + 1),
    post = as.integer(relative_month > 0)
  ) %>%
  rename(group_type = group)

# Create hurricane-to-state mappings
hurricane_info <- y14m_fsf_raw %>%
  distinct(histid, name, state_id) %>%
  filter(str_detect(name, "Hurricane")) %>%
  group_by(histid, name) %>%
  summarise(states = list(state_id), .groups = "drop") %>%
  mutate(hurricane_label = str_to_upper(str_extract(name, "(?<=Hurricane )\\w+")))

# Load model parameters
parameters <- read_xlsx(file.path(PATH_OUTPUT, "models_did2s_static.xlsx"), sheet = "Sheet1")

# Map parameters to hurricanes
idx_to_histid <- tibble(idx = CONFIG$spec_idx) %>%
  mutate(
    label = parameters$label[idx],
    hurricane_label = str_extract(label, "^\\w+")
  ) %>%
  left_join(hurricane_info, by = "hurricane_label")

# ============================================================================
# RUN MODELS
# ============================================================================

results <- map(CONFIG$spec_idx, function(idx) {

  # Get hurricane metadata
  hurricane_row <- idx_to_histid %>% filter(idx == !!idx)
  message("Processing: ", hurricane_row$hurricane_label)

  # Filter and prepare data
  y14m_fsf <- y14m_fsf_raw %>%
    filter(
      state_id %in% hurricane_row$states[[1]],
      histid == hurricane_row$histid | group_type == "C"
    ) %>%
    arrange(ID, relative_month) %>%
    group_by(ID) %>%
    mutate(
      dlq90 = as.integer(slide_int(ddlq90, sum, .before = CONFIG$delinquency_window, .complete = FALSE) > 0),
      fc = as.integer(slide_int(dfc, sum, .before = CONFIG$delinquency_window, .complete = FALSE) > 0)
    ) %>%
    ungroup()

  # Extract model specification
  model_spec <- list(
    yname = parameters$yname[idx],
    first_stage = formula(parameters$first_stage[idx]),
    second_stage = formula(parameters$second_stage[idx]),
    treatment = parameters$treatment[idx],
    cluster_var = parameters$cluster_var[idx],
    interacted = as.logical(parameters$interacted[idx]),
    output_file = parameters$output[idx]
  )

  # Estimate model
  reg <- did2s(
    data = y14m_fsf,
    yname = model_spec$yname,
    first_stage = model_spec$first_stage,
    second_stage = model_spec$second_stage,
    treatment = model_spec$treatment,
    cluster_var = model_spec$cluster_var
  )

  # Clean coefficients
  coefs <- clean_reg_fct(
    reg_in = reg,
    dat_in = y14m_fsf,
    interact_in = model_spec$interacted,
    twoway_in = TRUE,
    obsdat = FALSE
  )

  if (model_spec$interacted) {
    coefs <- coefs %>%
      mutate(Interacted_rel = str_extract(Interacted_rel, "[^:]*$"))
  }

  # Create plot
  plot <- plot_coefs_function(
    clean_coefs = coefs,
    interacted = model_spec$interacted,
    ES = FALSE
  ) +
    labs(
      title = paste("Effect on", model_spec$yname, "|", hurricane_row$hurricane_label),
      caption = "Sample: Properties affected by FSF disaster 2014/06-2021/12\nFixed Effects: Loan + Year-Month"
    )

  # Save outputs
  csv_file <- str_replace(model_spec$output_file, "\\.png$", ".csv")
  write_csv(coefs, file.path(PATH_OUTPUT, "coefs_did2s", csv_file))
  ggsave(file.path(PATH_OUTPUT, "figs_did2s", model_spec$output_file),
         plot = plot, height = 4, width = 9, bg = "white")

  list(reg = reg, coefs = coefs, plot = plot)

}) %>%
  set_names(idx_to_histid$hurricane_label)
