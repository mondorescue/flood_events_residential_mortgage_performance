# ============================================================================
# Estimation sample summary statistics (Table 1 / Table S2)
#
# Produces two versions of the summary statistics table:
#   1. "Level" statistics    -- computed on the full loan-month panel
#   2. "Rate" statistics     -- collapsed to loan-level "ever" indicators
#
# NOTE: This script assumes the R working directory is the project root
# (i.e., "/path/to/floods-and-mortgages"). Run via
# run_all.R, or set your working directory accordingly before running
# standalone.
# ============================================================================

library(tidyverse)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "01_summary_stats")
dir.create(PATH_OUTPUT, recursive = TRUE, showWarnings = FALSE)

analyze <- read_rds(file.path(PATH_DERIVED, "analyze.rds"))

pct_vars <- c("ddlq90", "ddlq120", "dfc", "prepaid")

# ----------------------------------------------------------------------------
# Version 1: Level statistics (full loan-month panel) --> Table 1
# ----------------------------------------------------------------------------

main_stats_level <- analyze %>%
  mutate(
    across(all_of(pct_vars), ~. * 100),
    sfha_binary = as.numeric(sfha_cat == "SFHA_in")
  ) %>%
  group_by(group) %>%
  summarize(
    across(c(all_of(pct_vars), "fico_orig", "dti_ratio", "sfha_binary"),
           list(
             mean = ~mean(., na.rm = TRUE),
             median = ~median(., na.rm = TRUE),
             p10 = ~quantile(., 0.1, na.rm = TRUE),
             p90 = ~quantile(., 0.9, na.rm = TRUE)
           ))
  ) %>%
  pivot_longer(-group, names_to = "stat", values_to = "value") %>%
  separate(stat, into = c("variable", "metric"), sep = "_(?=[^_]+$)", extra = "merge") %>%
  pivot_wider(names_from = c(group, metric), values_from = value, names_sep = "_")

income_stats_level <- analyze %>%
  filter(dti_ratio_fe > 0) %>%
  mutate(income_orig = pi_amt_orig / dti_ratio_fe * 100 * 12) %>%
  filter(!is.na(income_orig)) %>%
  group_by(group) %>%
  summarize(
    income_orig_mean = mean(income_orig, na.rm = TRUE),
    income_orig_median = median(income_orig, na.rm = TRUE),
    income_orig_p10 = quantile(income_orig, 0.1, na.rm = TRUE),
    income_orig_p90 = quantile(income_orig, 0.9, na.rm = TRUE)
  ) %>%
  pivot_longer(-group, names_to = "stat", values_to = "value") %>%
  separate(stat, into = c("variable", "metric"), sep = "_(?=[^_]+$)", extra = "merge") %>%
  pivot_wider(names_from = c(group, metric), values_from = value, names_sep = "_")

count_stats_level <- analyze %>%
  group_by(group) %>%
  summarize(
    n_obs = n(),
    n_loans = n_distinct(ID)
  ) %>%
  pivot_longer(-group, names_to = "variable", values_to = "value") %>%
  pivot_wider(names_from = group, values_from = value, names_prefix = "")

summary_table_level <- bind_rows(main_stats_level, income_stats_level, count_stats_level) %>%
  mutate(
    Variable = case_when(
      variable == "ddlq90" ~ "Monthly rate of 90-day delinquencies (%)",
      variable == "ddlq120" ~ "Monthly rate of 120-day delinquencies (%)",
      variable == "dfc" ~ "Monthly rate of foreclosures (%)",
      variable == "prepaid" ~ "Monthly rate of prepayments (%)",
      variable == "fico_orig" ~ "FICO score (index)",
      variable == "dti_ratio" ~ "Debt-to-income (ratio)",
      variable == "income_orig" ~ "Income ($)",
      variable == "sfha_binary" ~ "SFHA status (binary)",
      variable == "n_obs" ~ "Observations count",
      variable == "n_loans" ~ "Loan count"
    )
  ) %>%
  select(Variable, starts_with("T"), starts_with("C"), -variable)

write_csv(summary_table_level, file.path(PATH_OUTPUT, "summary_statistics_level.csv"))
message("Wrote: ", file.path(PATH_OUTPUT, "summary_statistics_level.csv"))
print(summary_table_level, width = Inf)

# ----------------------------------------------------------------------------
# Version 2: Rate statistics (loan-level "ever" indicators)
# ----------------------------------------------------------------------------

loan_level <- analyze %>%
  group_by(ID, group) %>%
  summarize(
    ever_ddlq90 = as.numeric(max(ddlq90, na.rm = TRUE) > 0),
    ever_ddlq120 = as.numeric(max(ddlq120, na.rm = TRUE) > 0),
    ever_dfc = as.numeric(max(dfc, na.rm = TRUE) > 0),
    ever_prepaid = as.numeric(max(prepaid, na.rm = TRUE) > 0),
    fico_orig = first(fico_orig),
    dti_ratio = first(dti_ratio),
    sfha_cat = first(sfha_cat),
    pi_amt_orig = first(pi_amt_orig),
    dti_ratio_fe = first(dti_ratio_fe),
    .groups = "drop"
  )

main_stats_rate <- loan_level %>%
  mutate(
    across(starts_with("ever_"), ~. * 100),
    sfha_binary = as.numeric(sfha_cat == "SFHA_in")
  ) %>%
  group_by(group) %>%
  summarize(
    across(c(starts_with("ever_"), "fico_orig", "dti_ratio", "sfha_binary"),
           list(
             mean = ~mean(., na.rm = TRUE),
             median = ~median(., na.rm = TRUE),
             p10 = ~quantile(., 0.1, na.rm = TRUE),
             p90 = ~quantile(., 0.9, na.rm = TRUE)
           ))
  ) %>%
  pivot_longer(-group, names_to = "stat", values_to = "value") %>%
  separate(stat, into = c("variable", "metric"), sep = "_(?=[^_]+$)", extra = "merge") %>%
  pivot_wider(names_from = c(group, metric), values_from = value, names_sep = "_")

income_stats_rate <- loan_level %>%
  filter(dti_ratio_fe > 0) %>%
  mutate(income_orig = pi_amt_orig / dti_ratio_fe * 100 * 12) %>%
  filter(!is.na(income_orig)) %>%
  group_by(group) %>%
  summarize(
    income_orig_mean = mean(income_orig, na.rm = TRUE),
    income_orig_median = median(income_orig, na.rm = TRUE),
    income_orig_p10 = quantile(income_orig, 0.1, na.rm = TRUE),
    income_orig_p90 = quantile(income_orig, 0.9, na.rm = TRUE)
  ) %>%
  pivot_longer(-group, names_to = "stat", values_to = "value") %>%
  separate(stat, into = c("variable", "metric"), sep = "_(?=[^_]+$)", extra = "merge") %>%
  pivot_wider(names_from = c(group, metric), values_from = value, names_sep = "_")

count_stats_rate <- loan_level %>%
  group_by(group) %>%
  summarize(
    n_loans = n()
  ) %>%
  pivot_longer(-group, names_to = "variable", values_to = "value") %>%
  pivot_wider(names_from = group, values_from = value, names_prefix = "")

summary_table_rate <- bind_rows(main_stats_rate, income_stats_rate, count_stats_rate) %>%
  mutate(
    Variable = case_when(
      variable == "ever_ddlq90" ~ "90-day delinquency rate (%)",
      variable == "ever_ddlq120" ~ "120-day delinquency rate (%)",
      variable == "ever_dfc" ~ "Foreclosure rate (%)",
      variable == "ever_prepaid" ~ "Prepayment rate (%)",
      variable == "fico_orig" ~ "FICO score (index)",
      variable == "dti_ratio" ~ "Debt-to-income (ratio)",
      variable == "income_orig" ~ "Income ($)",
      variable == "sfha_binary" ~ "SFHA status (binary)",
      variable == "n_loans" ~ "Loan count"
    )
  ) %>%
  select(Variable, starts_with("T"), starts_with("C"), -variable)

write_csv(summary_table_rate, file.path(PATH_OUTPUT, "summary_statistics_rate.csv"))
message("Wrote: ", file.path(PATH_OUTPUT, "summary_statistics_rate.csv"))
print(summary_table_rate, width = Inf)
