# ============================================================================
# Control group baseline statistics (Table S3)
#
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "02_baseline_stats")
dir.create(PATH_OUTPUT, recursive = TRUE, showWarnings = FALSE)

analyze <- read_rds(file.path(PATH_DERIVED, "analyze.rds"))

# ----------------------------------------------------------------------------
# Version 1: Level statistics (control group, pre-disaster months)
# ----------------------------------------------------------------------------

analyze %>%
  filter(relative_month < 0) %>%
  distinct(as_of_mon_id) -> ctrl_as_of_mon_id

overall_level <- analyze %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  filter(group == "C") %>%
  summarize(
    sub_group = "All",
    mean_ddlq90 = mean(ddlq90),
    mean_dfc = mean(dfc),
    n_banks = n_distinct(id_rssd)
  )

fico_level <- analyze %>%
  mutate(fico_orig_quartile = case_when(
    ntile(fico_orig, 4) == 1 ~ "FICO 1Q",
    ntile(fico_orig, 4) == 2 ~ "FICO 2Q",
    ntile(fico_orig, 4) == 3 ~ "FICO 3Q",
    ntile(fico_orig, 4) == 4 ~ "FICO 4Q"
  )) %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  filter(group == "C") %>%
  group_by(sub_group = fico_orig_quartile) %>%
  summarize(
    mean_ddlq90 = mean(ddlq90),
    mean_dfc = mean(dfc),
    n_banks = n_distinct(id_rssd)
  )

dti_level <- analyze %>%
  mutate(dti_orig_quartile = case_when(
    ntile(dti_ratio, 4) == 1 ~ "DTI 1Q",
    ntile(dti_ratio, 4) == 2 ~ "DTI 2Q",
    ntile(dti_ratio, 4) == 3 ~ "DTI 3Q",
    ntile(dti_ratio, 4) == 4 ~ "DTI 4Q"
  )) %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  filter(group == "C") %>%
  group_by(sub_group = dti_orig_quartile) %>%
  summarize(
    mean_ddlq90 = mean(ddlq90),
    mean_dfc = mean(dfc),
    n_banks = n_distinct(id_rssd)
  )

income_level <- analyze %>%
  filter(dti_ratio_fe > 0) %>%
  mutate(income_orig = pi_amt_orig / dti_ratio_fe * 100 * 12) %>%
  filter(!is.na(income_orig)) %>%
  mutate(income_orig_quartile = case_when(
    ntile(income_orig, 4) == 1 ~ "Income 1Q",
    ntile(income_orig, 4) == 2 ~ "Income 2Q",
    ntile(income_orig, 4) == 3 ~ "Income 3Q",
    ntile(income_orig, 4) == 4 ~ "Income 4Q"
  )) %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  filter(group == "C") %>%
  group_by(sub_group = income_orig_quartile) %>%
  summarize(
    mean_ddlq90 = mean(ddlq90),
    mean_dfc = mean(dfc),
    n_banks = n_distinct(id_rssd)
  )

sfha_level <- analyze %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  filter(group == "C") %>%
  group_by(sub_group = sfha_cat) %>%
  summarize(
    mean_ddlq90 = mean(ddlq90),
    mean_dfc = mean(dfc),
    n_banks = n_distinct(id_rssd)
  )

inun_level <- analyze %>%
  replace_na(list(hist_depth = 0)) %>%
  mutate(ffe = if_else(is.na(foundation_height), 0, foundation_height)) %>%
  mutate(inundation_depth = hist_depth - ffe) %>%
  mutate(ffe_flooded_cat = if_else(inundation_depth > 0, "Flooded", "Not Flooded")) %>%
  mutate(ffe_flooded_depth = if_else(ffe_flooded_cat == "Flooded", inundation_depth, NA_real_)) %>%
  mutate(inun_group = case_when(
    ntile(ffe_flooded_depth, 4) == 1 ~ "FFE flooded 1Q",
    ntile(ffe_flooded_depth, 4) == 2 ~ "FFE flooded 2Q",
    ntile(ffe_flooded_depth, 4) == 3 ~ "FFE flooded 3Q",
    ntile(ffe_flooded_depth, 4) == 4 ~ "FFE flooded 4Q",
    is.na(ffe_flooded_depth) & (hist_depth > 0) ~ "FFE not flooded",
    is.na(ffe_flooded_depth) & (hist_depth == 0) ~ "Control"
  )) %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  group_by(sub_group = inun_group) %>%
  summarize(
    mean_ddlq90 = mean(ddlq90),
    mean_dfc = mean(dfc),
    n_banks = n_distinct(id_rssd)
  )

claims_level <- analyze %>%
  replace_na(list(perc_props_covered = 0)) %>%
  mutate(claims_quartile = case_when(
    ntile(perc_props_covered, 4) == 1 ~ "Claims 1Q",
    ntile(perc_props_covered, 4) == 2 ~ "Claims 2Q",
    ntile(perc_props_covered, 4) == 3 ~ "Claims 3Q",
    ntile(perc_props_covered, 4) == 4 ~ "Claims 4Q"
  )) %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  filter(group == "C") %>%
  group_by(sub_group = claims_quartile) %>%
  summarize(
    mean_ddlq90 = mean(ddlq90),
    mean_dfc = mean(dfc),
    n_banks = n_distinct(id_rssd)
  )

baseline_level <- bind_rows(
  overall_level %>% mutate(category = "All"),
  fico_level %>% mutate(category = "FICO"),
  dti_level %>% mutate(category = "DTI"),
  income_level %>% mutate(category = "Income"),
  sfha_level %>% mutate(category = "SFHA"),
  inun_level %>% mutate(category = "Inundation"),
  claims_level %>% mutate(category = "NFIP claims")
) %>%
  select(category, sub_group, mean_ddlq90, mean_dfc, n_banks)

write_csv(baseline_level, file.path(PATH_OUTPUT, "baseline_level.csv"))
message("Wrote: ", file.path(PATH_OUTPUT, "baseline_level.csv"))
print(baseline_level, n = Inf)

# ----------------------------------------------------------------------------
# Version 2: Rate statistics (loan-level "ever" indicators, %) --> Table S3
# ----------------------------------------------------------------------------

pre_disaster_control <- analyze %>%
  filter(as_of_mon_id %in% ctrl_as_of_mon_id$as_of_mon_id) %>%
  filter(group == "C") %>%
  group_by(id_rssd, loan_id) %>%
  summarize(
    ever_90 = as.numeric(max(ddlq90) > 0),
    ever_dfc = as.numeric(max(dfc) > 0),
    fico_orig = first(fico_orig),
    dti_ratio = first(dti_ratio),
    pi_amt_orig = first(pi_amt_orig),
    dti_ratio_fe = first(dti_ratio_fe),
    sfha_cat = first(sfha_cat),
    foundation_height = first(foundation_height),
    hist_depth = first(hist_depth),
    perc_props_covered = first(perc_props_covered),
    .groups = "drop"
  )

overall_rate <- pre_disaster_control %>%
  summarize(
    sub_group = "All",
    dlq_rate_90 = mean(ever_90) * 100,
    dfc_rate = mean(ever_dfc) * 100,
    n_loans = n(),
    n_banks = n_distinct(id_rssd)
  )

fico_rate <- pre_disaster_control %>%
  mutate(fico_orig_quartile = case_when(
    ntile(fico_orig, 4) == 1 ~ "FICO 1Q",
    ntile(fico_orig, 4) == 2 ~ "FICO 2Q",
    ntile(fico_orig, 4) == 3 ~ "FICO 3Q",
    ntile(fico_orig, 4) == 4 ~ "FICO 4Q"
  )) %>%
  group_by(sub_group = fico_orig_quartile) %>%
  summarize(
    dlq_rate_90 = mean(ever_90) * 100,
    dfc_rate = mean(ever_dfc) * 100,
    n_loans = n(),
    n_banks = n_distinct(id_rssd)
  )

dti_rate <- pre_disaster_control %>%
  mutate(dti_orig_quartile = case_when(
    ntile(dti_ratio, 4) == 1 ~ "DTI 1Q",
    ntile(dti_ratio, 4) == 2 ~ "DTI 2Q",
    ntile(dti_ratio, 4) == 3 ~ "DTI 3Q",
    ntile(dti_ratio, 4) == 4 ~ "DTI 4Q"
  )) %>%
  group_by(sub_group = dti_orig_quartile) %>%
  summarize(
    dlq_rate_90 = mean(ever_90) * 100,
    dfc_rate = mean(ever_dfc) * 100,
    n_loans = n(),
    n_banks = n_distinct(id_rssd)
  )

income_rate <- pre_disaster_control %>%
  filter(dti_ratio_fe > 0) %>%
  mutate(income_orig = pi_amt_orig / dti_ratio_fe * 100 * 12) %>%
  filter(!is.na(income_orig)) %>%
  mutate(income_orig_quartile = case_when(
    ntile(income_orig, 4) == 1 ~ "Income 1Q",
    ntile(income_orig, 4) == 2 ~ "Income 2Q",
    ntile(income_orig, 4) == 3 ~ "Income 3Q",
    ntile(income_orig, 4) == 4 ~ "Income 4Q"
  )) %>%
  group_by(sub_group = income_orig_quartile) %>%
  summarize(
    dlq_rate_90 = mean(ever_90) * 100,
    dfc_rate = mean(ever_dfc) * 100,
    n_loans = n(),
    n_banks = n_distinct(id_rssd)
  )

sfha_rate <- pre_disaster_control %>%
  group_by(sub_group = sfha_cat) %>%
  summarize(
    dlq_rate_90 = mean(ever_90) * 100,
    dfc_rate = mean(ever_dfc) * 100,
    n_loans = n(),
    n_banks = n_distinct(id_rssd)
  )

inun_rate <- pre_disaster_control %>%
  replace_na(list(hist_depth = 0)) %>%
  mutate(ffe = if_else(is.na(foundation_height), 0, foundation_height)) %>%
  mutate(inundation_depth = hist_depth - ffe) %>%
  mutate(ffe_flooded_cat = if_else(inundation_depth > 0, "Flooded", "Not Flooded")) %>%
  mutate(ffe_flooded_depth = if_else(ffe_flooded_cat == "Flooded", inundation_depth, NA_real_)) %>%
  mutate(inun_group = case_when(
    ntile(ffe_flooded_depth, 4) == 1 ~ "FFE flooded 1Q",
    ntile(ffe_flooded_depth, 4) == 2 ~ "FFE flooded 2Q",
    ntile(ffe_flooded_depth, 4) == 3 ~ "FFE flooded 3Q",
    ntile(ffe_flooded_depth, 4) == 4 ~ "FFE flooded 4Q",
    is.na(ffe_flooded_depth) & (hist_depth > 0) ~ "FFE not flooded",
    is.na(ffe_flooded_depth) & (hist_depth == 0) ~ "Control"
  )) %>%
  group_by(sub_group = inun_group) %>%
  summarize(
    dlq_rate_90 = mean(ever_90) * 100,
    dfc_rate = mean(ever_dfc) * 100,
    n_loans = n(),
    n_banks = n_distinct(id_rssd)
  )

claims_rate <- pre_disaster_control %>%
  replace_na(list(perc_props_covered = 0)) %>%
  mutate(claims_quartile = case_when(
    ntile(perc_props_covered, 4) == 1 ~ "Claims 1Q",
    ntile(perc_props_covered, 4) == 2 ~ "Claims 2Q",
    ntile(perc_props_covered, 4) == 3 ~ "Claims 3Q",
    ntile(perc_props_covered, 4) == 4 ~ "Claims 4Q"
  )) %>%
  group_by(sub_group = claims_quartile) %>%
  summarize(
    dlq_rate_90 = mean(ever_90) * 100,
    dfc_rate = mean(ever_dfc) * 100,
    n_loans = n(),
    n_banks = n_distinct(id_rssd)
  )

baseline_rate <- bind_rows(
  overall_rate %>% mutate(category = "All"),
  fico_rate %>% mutate(category = "FICO"),
  dti_rate %>% mutate(category = "DTI"),
  income_rate %>% mutate(category = "Income"),
  sfha_rate %>% mutate(category = "SFHA"),
  inun_rate %>% mutate(category = "Inundation"),
  claims_rate %>% mutate(category = "NFIP claims")
) %>%
  select(category, sub_group, dlq_rate_90, dfc_rate, n_loans, n_banks)

write_csv(baseline_rate, file.path(PATH_OUTPUT, "baseline_rate.csv"))
message("Wrote: ", file.path(PATH_OUTPUT, "baseline_rate.csv"))
print(baseline_rate, n = Inf)
