# ============================================================================
# Share of Securitized Loans by Investor Category
#
# Computes the distribution of loans in the treatment and control groups
# across investor categories (GSE-securitized, privately securitized,
# held on bank portfolio, or other), as reported in Table 1.
#
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)
library(gt)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "07_share_of_securitized_loans")

dir.create(PATH_OUTPUT, recursive = TRUE, showWarnings = FALSE)

# Load and prepare data
y14m_fsf <- read_rds(file.path(PATH_DERIVED, "analyze1.rds"))
y14m_additional_vars <- read_csv(
  file.path(PATH_DERIVED, "y14m_check_forbearance.csv.gz"),
  col_select = c(id_rssd, loan_id, as_of_mon_id, investor_type),
  col_types = cols(
    .default = col_character(),
    id_rssd = col_double(),
    as_of_mon_id = col_double()
  ),
  num_threads = 4
)

y14m_fsf <- left_join(y14m_fsf, y14m_additional_vars,
                       by = c("id_rssd", "loan_id", "as_of_mon_id"))

# Optionally restrict to the five largest hurricane events (uncomment to
# reproduce the sub-sample used for Table S1's forbearance discussion):
# y14m_fsf <- y14m_fsf %>% filter(
#   str_detect(name, "Florence") |
#     str_detect(name, "Harvey") | str_detect(name, "Irma") |
#     str_detect(name, "Matthew") |
#     str_detect(name, "Michael")
# )

# Produce statistics of loan type (via investor_type field) by group_type
gt_obj <- y14m_fsf %>%
  distinct(ID, id_rssd, investor_type, group_type) %>%
  mutate(investor_category = case_when(
    investor_type %in% c("1", "2", "3") ~ "Securitized (FNMA/FHLMC/GNMA)",
    investor_type == "4" ~ "Private Securitized",
    investor_type == "7" ~ "Portfolio",
    TRUE ~ "Other"
  )) %>%
  mutate(investor_category = factor(
    investor_category,
    levels = c("Securitized (FNMA/FHLMC/GNMA)", "Private Securitized", "Portfolio", "Other")
  )) %>%
  group_by(group_type, investor_category, .drop = FALSE) %>%
  summarise(
    n_loans = n_distinct(ID),
    n_banks = n_distinct(id_rssd),
    .groups = "drop"
  ) %>%
  group_by(group_type) %>%
  mutate(pct_loans = n_loans / sum(n_loans) * 100) %>%
  ungroup() %>%
  gt(groupname_col = "group_type") %>%
  cols_label(
    investor_category = "Investor Category",
    n_loans = "Loans",
    n_banks = "Banks",
    pct_loans = "% of Loans"
  ) %>%
  fmt_number(columns = c(n_loans, n_banks), decimals = 0, use_seps = TRUE) %>%
  fmt_number(columns = pct_loans, decimals = 1)

# Save outputs
gt_obj %>% gtsave(file.path(PATH_OUTPUT, "investor_table.png"))
