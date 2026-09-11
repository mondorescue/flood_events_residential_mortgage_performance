# ============================================================================
# Table S1: Historical flood events included in estimation sample
#
# Combines synthetic fsf_floods.rds (residential properties affected) and
# y14m_counts.rds (FR Y-14M loans affected) to reproduce Table IA1. River
# flood events near Dallas, TX, Beaumont, TX, and Yankton, SD are combined
# into a single row to satisfy the Federal Reserve's Y-14M data disclosure
# requirements (aggregation across at least five banks).
#
# NOTE: This script assumes the R working directory is the project root
# (i.e., "/path/to/floods-and-mortgages"). Run via
# run_all.R, or set your working directory accordingly before running
# standalone.
# ============================================================================

library(tidyverse)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "10_historical_flood_events")
dir.create(PATH_OUTPUT, recursive = TRUE, showWarnings = FALSE)

fsf_floods  <- read_rds(file.path(PATH_DERIVED, "fsf_floods.rds"))
y14m_counts <- read_rds(file.path(PATH_DERIVED, "y14m_counts.rds"))

# Events included in the estimation sample (excludes Rocky Mount, NC and
# Sioux City, SD, which are not part of the disclosed Y-14M sample).
# Names match the lowercase convention used in the source data.
included_events <- c(
  "river flood near Toledo, OH",
  "river flood near Eureka, MO",
  "Hurricane Hermine's storm surge",
  "Hurricane Matthew",
  "Hurricane Irma's storm surge",
  "Hurricane Harvey",
  "Hurricane Florence",
  "Hurricane Michael's storm surge",
  "river flood near Shepherdstown, WV",
  "river flood across eastern Nebraska",
  "river flood near Dallas, TX",
  "river flood near Beaumont, TX",
  "river flood near Yankton, SD"
)

# Events to combine into a single "Texas and South Dakota" row
combined_events <- c(
  "river flood near Dallas, TX",
  "river flood near Beaumont, TX",
  "river flood near Yankton, SD"
)

n_properties <- fsf_floods %>%
  count(name, name = "n_properties")

n_loans <- y14m_counts %>%
  distinct(ID, name) %>%
  count(name, name = "n_loans")

event_dates <- tribble(
  ~name, ~Date,
  "river flood near Toledo, OH", "June 2015",
  "river flood near Eureka, MO", "December 2015",
  "Hurricane Hermine's storm surge", "August 2016",
  "Hurricane Matthew", "September 2016",
  "Hurricane Irma's storm surge", "September 2017",
  "Hurricane Harvey", "September 2017",
  "Hurricane Florence", "September 2018",
  "Hurricane Michael's storm surge", "October 2018",
  "river flood near Shepherdstown, WV", "December 2018",
  "river flood across eastern Nebraska", "March 2019",
  "river flood near Dallas, TX", "2015, 2016, 2019",
  "river flood near Beaumont, TX", "2015, 2016, 2019",
  "river flood near Yankton, SD", "2015, 2016, 2019"
)

event_names <- tribble(
  ~name, ~Event_Name,
  "river flood near Toledo, OH", "River flood near Toledo, OH",
  "river flood near Eureka, MO", "River flood near Eureka, MO",
  "Hurricane Hermine's storm surge", "Hurricane Hermine",
  "Hurricane Matthew", "Hurricane Matthew",
  "Hurricane Irma's storm surge", "Hurricane Irma",
  "Hurricane Harvey", "Hurricane Harvey",
  "Hurricane Florence", "Hurricane Florence",
  "Hurricane Michael's storm surge", "Hurricane Michael",
  "river flood near Shepherdstown, WV", "River flood near Shepherdstown, WV",
  "river flood across eastern Nebraska", "River flood across eastern Nebraska"
)

table_s1 <- n_properties %>%
  inner_join(n_loans, by = "name") %>%
  filter(name %in% included_events) %>%
  left_join(event_dates, by = "name") %>%
  mutate(
    group_label = if_else(
      name %in% combined_events,
      "River floods in Texas and South Dakota",
      name
    )
  ) %>%
  group_by(group_label) %>%
  summarize(
    n_properties = sum(n_properties),
    n_loans = sum(n_loans),
    Date = first(Date),
    .groups = "drop"
  ) %>%
  left_join(event_names, by = c("group_label" = "name")) %>%
  mutate(
    Event_Name = if_else(
      group_label == "River floods in Texas and South Dakota",
      "River floods in Texas and South Dakota",
      Event_Name
    ),
    Date = if_else(
      group_label == "River floods in Texas and South Dakota",
      "2015, 2016, 2019",
      Date
    )
  ) %>%
  select(Event_Name, Date, n_properties, n_loans)

# Order rows to match published table
row_order <- c(
  "River flood near Toledo, OH",
  "River flood near Eureka, MO",
  "Hurricane Hermine",
  "Hurricane Matthew",
  "Hurricane Irma",
  "Hurricane Harvey",
  "Hurricane Florence",
  "Hurricane Michael",
  "River flood near Shepherdstown, WV",
  "River flood across eastern Nebraska",
  "River floods in Texas and South Dakota"
)

table_s1 <- table_s1 %>%
  mutate(Event_Name = factor(Event_Name, levels = row_order)) %>%
  arrange(Event_Name) %>%
  mutate(Event_Name = as.character(Event_Name)) %>%
  rename(
    "N Residential Properties Affected" = n_properties,
    "N FR Y-14M Loans Affected" = n_loans
  )

write_csv(table_s1, file.path(PATH_OUTPUT, "table_s1_flood_events.csv"))
message("Wrote: ", file.path(PATH_OUTPUT, "table_s1_flood_events.csv"))
print(table_ia1, width = Inf)