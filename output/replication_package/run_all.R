# ============================================================================
# run_all.R
#
# Master script for the replication package accompanying:
#   "Impacts of flood events on residential mortgage performance"
#
# Sources every analysis component in sequence. Each component can also be
# run independently (e.g. via `Rscript replication_package/03_event_study_did2s/event_study_did2s.R`)
# as long as the working directory is set to the project root (i.e., the
# directory containing `synthetic-data/` and `output/`).
#
# Required input data (synthetic data):
#   - synthetic-data/analyze.rds
#   - synthetic-data/analyze1.rds
#   - synthetic-data/y14m_check_forbearance.csv.gz
#   - synthetic-data/tx_harvey_obs.csv
#
# Required R packages:
#   tidyverse, did2s, did, readxl, slider, gt, lubridate
#
# NOTE: The event-study models (03, 04) and the full static battery (05)
# are computationally intensive (up to several days and ~300GB RAM for the
# full battery in the original runs). Consider running these individually,
# on a subset of MODEL_INDICES, or on a high-memory machine.
# ============================================================================

stopifnot(
  "Run this script with working directory set to the project root (containing synthetic-data/, output/)" =
    dir.exists("synthetic-data")
)

message("== 01: Summary statistics (Table 1 / Table S2) ==")
source("output/replication_package/01_summary_stats/summary_stats.R")

message("== 02: Control group baseline rates (Table S3) ==")
source("output/replication_package/02_baseline_stats/baseline_stats.R")

message("== 03: Event study DID2S, primary specification (Figs 2A, 3A, S4A, S5) ==")
source("output/replication_package/03_event_study_did2s/event_study_did2s.R")

message("== 04: Event study DID2S, alternate SE clustering (robustness) ==")
source("output/replication_package/04_event_study_did2s_other_SE/event_study_did2s_other_SE.R")

message("== 05a: Static DID2S battery (Figs 2B-G, 3B-G, S4B-G, S6, S8 inputs) ==")
source("output/replication_package/05_static_did2s/static_did2s_runs.R")

message("== 05b: Static DID2S, Harvey modeled vs. observed inundation (Fig S2) ==")
source("output/replication_package/05_static_did2s/static_did2s_harvey_inun.R")

message("== 05c: Static DID2S, per-hurricane sub-samples (Fig S7) ==")
source("output/replication_package/05_static_did2s/static_did2s_hurricanes.R")

message("== 05d: Static DID2S, Inundation x FICO disclosure plot (Fig S8) ==")
source("output/replication_package/05_static_did2s/static_did2s_figS8_disclosure.R")

message("== 06: Callaway & Sant'Anna (2021) robustness check (Fig S3) ==")
source("output/replication_package/06_gardner_vs_callaway/callaway_es.R")

message("== 07: Share of securitized loans (Table 1) ==")
source("output/replication_package/07_share_of_securitized_loans/share_of_securitized_loans.R")

message("== Done. ==")
