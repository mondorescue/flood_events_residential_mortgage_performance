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
#   - synthetic-data/y14m_comp.rds
#   - synthetic-data/mcdash_comp.rds
#   - synthetic-data/y14m_counts.rds
#   - synthetic-data/fsf_floods.rds
#
# Required R packages:
#   tidyverse, did2s, did, readxl, slider, gt
#
# Required Python (section 10, maps) -- Python >= 3.11:
#   matplotlib, numpy, pandas, seaborn, geopandas, openpyxl
#
#   Section 10 shells out to Python via system2(). A python3 (or python)
#   interpreter must be discoverable on PATH, with the packages above
#   installed in that interpreter. The Python scripts resolve their own
#   input/output paths relative to their script location, so they run
#   correctly when launched from the project root by this script.
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

message("== 01: Summary statistics (Table 1) ==")
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

message("== 08: Boxplot comparison (Fig S1) ==")
source("output/replication_package/08_comparison/dti_fico_ltv_compare.R")

message("== 09: Historical flood events (Table S1) ==")
source("output/replication_package/09_historical_flood_events/historical_flood_events.R")

message("== 10: Maps (Figs 1, 4) ==")

# Run Python map scripts as external processes.
# system2 returns the exit status; stop if nonzero.

py <- Sys.which("python3")
if (py == "") py <- Sys.which("python")
stopifnot("No python interpreter found on PATH" = py != "")

fig1_status <- system2(
  py,
  args = shQuote("output/replication_package/10_maps/Figure_1/figure_1.py")
)
if (fig1_status != 0) warning("figure_1.py exited with a nonzero status (", fig1_status, ")")

fig4_status <- system2(
  py,
  args = shQuote("output/replication_package/10_maps/Figure_4/figure_4.py")
)
if (fig4_status != 0) warning("figure_4.py exited with a nonzero status (", fig4_status, ")")

message("== Done. ==")
