# Replication Package

This package contains cleaned R scripts to replicate the analyses in:

> Gourevitch, J.D., Seok, B., Weill, J.A., Kousky, C., & Porter, J.R.
> *Impacts of flood events on residential mortgage performance.*

It is organized into one folder per analysis component.

## Requirements

- R (>= 4.1 recommended)
- Packages: `tidyverse`, `did2s`, `did` (v2.1.1 tested), `readxl`,
  `slider`, `gt`

Install with:

```r
install.packages(c("tidyverse", "did2s", "did", "readxl", "slider", "gt"))
```

## Required input data (synthetic data)

The synthetic panel is a **~10% scaled-down** replica. Every value is drawn from
probability distributions calibrated to match published/aggregate summary
statistics only.

Place these files under the project root before running any script:

- `synthetic-data/analyze.rds` — loan-month panel merging Y-14M mortgage
  performance data with First Street flood inundation data
- `synthetic-data/analyze1.rds` — loan-level version used for investor-type
  breakdowns
- `synthetic-data/y14m_check_forbearance.csv.gz` — supplementary loan
  attributes (investor type, etc.)
- `synthetic-data/tx_harvey_obs.csv` — observed (FEMA high-water-mark) Harvey
  inundation depths, used for the Figure S2 robustness check

## How to run

All scripts assume the R working directory is the **project root** (the
directory containing `synthetic-data/` and `output/`), *not*
this `replication_package/` folder.

To run everything in sequence:

```r
setwd("/path/to/floods-and-mortgages")   # project root
source("output/replication_package/run_all.R")
```

Or run any individual component directly, e.g.:

```bash
cd /path/to/floods-and-mortgages
Rscript output/replication_package/03_event_study_did2s/event_study_did2s.R
```

Outputs (CSVs and figures) are written into each component's own
subfolder under `output/replication_package/`.

## Folder guide

| Folder | Original source(s) | Manuscript output(s) |
|---|---|---|
| `00_common/` | `*/helper_functions.R` (deduplicated) | — (shared coefficient-cleaning / plotting helpers) |
| `01_summary_stats/` | `estimation_summary_stats/summary.R`, `summary_rate.R` | Table 1, Table S2 |
| `02_baseline_stats/` | `control_group_baseline_stats/baseline.R`, `baseline_rate.R` | Table S3 |
| `03_event_study_did2s/` | `event_study_did2s/did2s_es_runs.R` | Figs 2A, 3A, S4A, S5 (primary spec, SE clustered by loan) |
| `04_event_study_did2s_other_SE/` | `event_study_did2s_other_SE/did2s_es_runs.R` | Robustness check (SE clustered by event, 5 events excluded) |
| `05_static_did2s/` | `static_did2s/did2s_static_runs.R`, `did2s_static_harvey-inun.R`, `did2s_static_hurricanes.R`, `for_disclosure_inun-x-fico.R` | Figs 2B-G, 3B-G, S4B-G, S6, S7, S8; Fig S2 |
| `06_gardner_vs_callaway/` | `gardner_vs_callaway/callaway.R` | Fig S3 (Callaway & Sant'Anna robustness check) |
| `07_share_of_securitized_loans/` | `share_of_securitized_loans/share_of_securitized_loans.R` | Table 1 (investor-type breakdown) |

## Notes on computational cost

The full event-study battery (`03_event_study_did2s`,
`04_event_study_did2s_other_SE`) and the full static battery
(`05_static_did2s/static_did2s_runs.R`) were originally run on a
SLURM cluster due to long runtimes (up to several days) and high
memory requirements (up to ~300GB RAM for the largest specifications).
To test on a smaller scale, reduce `MODEL_INDICES` / `model_indices` in
the relevant script before running the full loop.
