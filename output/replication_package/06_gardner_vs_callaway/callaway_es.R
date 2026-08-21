# ============================================================================
# Callaway & Sant'Anna (2021) DID Estimator - Robustness Check
#
# Re-estimates the dynamic event-study specification for 90-day delinquency
# (ddlq90) using the Callaway & Sant'Anna (2021) heterogeneity-robust DID
# estimator (via the `did` package, tested with version 2.1.1), as a
# robustness check against the primary Gardner et al. (2024) two-stage
# estimator used in 03_event_study_did2s. Produces the comparison shown in
# Figure S3.
#
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)
library(did)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "06_gardner_vs_callaway")

dir.create(PATH_OUTPUT, recursive = TRUE, showWarnings = FALSE)

# Load and prepare base data
y14m_fsf <- read_rds(file.path(PATH_DERIVED, "analyze.rds")) %>%
  rename(group_type = group) %>%
  # Create post flag for event study did
  mutate(
    date = ymd(as_of_mon_id * 100 + 1),
    date_event = ymd(event_date * 100 + 1),
    post = if_else(relative_month > 0, 1, 0)
  )

dat <- y14m_fsf %>%
  group_by(ID) %>%
  mutate(
    first_event = suppressWarnings(min(event_date, na.rm = TRUE)),
    first_event = if_else(is.infinite(first_event), NA_real_, first_event)
  ) %>%
  ungroup() %>%
  filter(is.na(event_date) | event_date == first_event) %>%
  mutate(
    ID_numeric = as.numeric(factor(ID)),
    period = as.integer(year(date) * 12L + month(date)),
    period_event = as.integer(year(date_event) * 12L + month(date_event)),
    gname = if_else(is.na(period_event), 0, period_event + 1)
  ) %>%
  select(ID_numeric, period, period_event, ddlq90, gname)

# Filter small treatment groups to avoid singular matrix errors
dat_clean <- dat %>%
  group_by(gname) %>%
  mutate(group_size = n_distinct(ID_numeric)) %>%
  ungroup() %>%
  filter(gname == 0 | group_size >= 141) %>%
  select(-group_size)

# Run did
result <- att_gt(
  yname = "ddlq90",
  tname = "period",
  idname = "ID_numeric",
  gname = "gname",
  data = dat_clean,
  allow_unbalanced_panel = TRUE,
  control_group = "notyettreated",
  clustervars = "ID_numeric"
)
write_rds(result, file.path(PATH_OUTPUT, "result_did_analyze.rds"))

# Aggregate to event study with specified window
agg_dyn <- aggte(result, type = "dynamic", min_e = -24, max_e = 24, na.rm = TRUE)
write_rds(agg_dyn, file.path(PATH_OUTPUT, "agg_dyn.rds"))
summary(agg_dyn)
ggdid(agg_dyn, xlab = "Months relative to event", xgap = 3)

# Extract dynamic effects to data frame
dynamic_results <- data.frame(
  type = agg_dyn$type,
  term = paste0("ATT(", agg_dyn$egt, ")"),
  event.time = agg_dyn$egt,
  estimate = agg_dyn$att.egt,
  std.error = agg_dyn$se.egt,
  conf.low = agg_dyn$att.egt - agg_dyn$crit.val.egt * agg_dyn$se.egt,
  conf.high = agg_dyn$att.egt + agg_dyn$crit.val.egt * agg_dyn$se.egt,
  point.conf.low = agg_dyn$att.egt - qnorm(1 - agg_dyn$DIDparams$alp / 2) * agg_dyn$se.egt,
  point.conf.high = agg_dyn$att.egt + qnorm(1 - agg_dyn$DIDparams$alp / 2) * agg_dyn$se.egt
)

# Save to CSV
write_csv(dynamic_results, file.path(PATH_OUTPUT, "FigS3-delinq90_callaway_es.csv"))
