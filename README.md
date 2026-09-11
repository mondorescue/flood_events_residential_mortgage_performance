# Replication Package

This package contains cleaned R scripts to replicate the analyses in:

> Gourevitch, J.D., Seok, B., Weill, J.A., Kousky, C., & Porter, J.R.
> *Impacts of flood events on residential mortgage performance.*

It is organized into one folder per analysis component.

## Requirements

- R (>= 4.1 recommended)
- Packages: `tidyverse`, `did2s`, `did` (v2.1.1 tested), `readxl`,
  `slider`, `gt`

##### For `09_maps`

- Python (>= 3.11 recommended)
- Packages: `matplotlib`, `numpy`, `pandas`, `seaborn`, `geopandas`

Install R packages with:

```r
install.packages(c("tidyverse", "did2s", "did", "readxl", "slider", "gt"))
```

Install Python packages with:

```python
pip install matplotlib numpy pandas seaborn geopandas
```

## Python environment setup for `run_all.R`

`run_all.R` invokes the Python map scripts (`09_maps`) as external processes via
R's `system2()`. For this to work:

1. A Python interpreter must be discoverable on the system `PATH` under the name
   `python3` or `python`. `run_all.R` resolves the interpreter with 
   `Sys.which("python3")`, then falls back to `Sys.which("python")`. If neither
   if found, the script stops with an error.
2. The required Python packages (`matplotlib`, `numpy`, `pandas`, `seaborn`,
   `geopandas`) must be installed in the interpreter that `Sys.which` locates.
   Verify with:
   ```bash
   python3 -c "import matplotlib, numpy, pandas, seaborn, geopandas"
   ```
   A nonzero exit or import error means the packages are not installed in that
   interpreter.
3. If the scripts require a specific virtual environment or conda environment,
   activate it in the same shell session before launching R, so the intended
   interpreter appears first on `PATH`. Alternatively, edit the `py` assignment
   in the section 09 block of `run_all.R` to point at the absolute path of the
   desired interpreter.
   
Each Python script is run in its own process, isolated from the R session. A
nonzero exit status from either script halts `run_all.R`.

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
- `synthetic-data/y14m_comp.rds` — loan-level sample for DTI, FICO, and LTV from
  Y-14M mortgage data
- `synthetic-data/mcdash_comp.rds` — loan-level sample for DTI, FICO, and LTV
  from McDash as a benchmark comparison against the Y-14M
- `synthetic-data/y14m_counts.rds` — loan-level Y-14M linked to events
- `synthetic-data/fsf_floods.rds` — First Street properties linked to events

## How to run

All scripts assume the R working directory is the **project root** (the
directory containing `synthetic-data/` and `output/`), *not*
this `replication_package/` folder.

To run everything in sequence:

```r
setwd("/path/to/flood_events_residential_mortgage_performance")   # project root
source("output/replication_package/run_all.R")
```

Or run any individual component directly, e.g.:

```bash
cd /path/to/flood_events_residential_mortgage_performance
Rscript output/replication_package/03_event_study_did2s/event_study_did2s.R
```

Outputs (CSVs and figures) are written into each component's own
subfolder under `output/replication_package/`.

## Folder guide

| Folder | Original source(s) | Manuscript output(s) |
|---|---|---|
| `00_common/` | `*/helper_functions.R` (deduplicated) | — (shared coefficient-cleaning / plotting helpers) |
| `01_summary_stats/` | `estimation_summary_stats/summary.R`, `summary_rate.R` | Table 1 |
| `02_baseline_stats/` | `control_group_baseline_stats/baseline.R`, `baseline_rate.R` | Table S3 |
| `03_event_study_did2s/` | `event_study_did2s/did2s_es_runs.R` | Figs 2A, 3A, S4A, S5 (primary spec, SE clustered by loan) |
| `04_event_study_did2s_other_SE/` | `event_study_did2s_other_SE/did2s_es_runs.R` | Robustness check (SE clustered by event, 5 events excluded) |
| `05_static_did2s/` | `static_did2s/did2s_static_runs.R`, `did2s_static_harvey-inun.R`, `did2s_static_hurricanes.R`, `for_disclosure_inun-x-fico.R` | Figs 2B-G, 3B-G, S4B-G, S6, S7, S8; Fig S2 |
| `06_gardner_vs_callaway/` | `gardner_vs_callaway/callaway.R` | Fig S3 (Callaway & Sant'Anna robustness check) |
| `07_share_of_securitized_loans/` | `share_of_securitized_loans/share_of_securitized_loans.R` | Table 1 (investor-type breakdown) |
| `08_comparison/` | `raw_mcdash_comparison/dti_fico_ltv_compare.R` | Fig S1 |
| `09_historical_flood_events/` | `event_counts/counts.R` | Table S1 |
| `10_maps/Figure_1` | `python_maps/figure_1.py` | Fig 1 |
| `10_maps/Figure_4` | `python_maps/figure_4.py` | Fig 4 |

## Note on `10_maps`

Figures 1 and 4 were produced in Python 3.11. `run_all.R` now runs the `10_maps`
Python scripts automatically as external processes; no manual Python step is
required when using `run_all.R`, provided the Python environment is configured
as described above.

To run the Python scripts manually instead, execute them directly with your
Python interpreter, e.g.:

```bash
cd /path/to/flood_events_residential_mortgage_performance
python3 output/replication_package/09_maps/Figure_1/figure_1.py
python3 output/replication_package/09_maps/Figure_4/figure_4.py
```

## Notes on computational cost

The full event-study battery (`03_event_study_did2s`,
`04_event_study_did2s_other_SE`) and the full static battery
(`05_static_did2s/static_did2s_runs.R`) were originally run on a
SLURM cluster due to long runtimes (up to several days) and high
memory requirements (up to ~300GB RAM for the largest specifications).
To test on a smaller scale, reduce `MODEL_INDICES` / `model_indices` in
the relevant script before running the full loop.
