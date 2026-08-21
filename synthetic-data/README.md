# Synthetic replication data

This directory contains **fully synthetic** stand-ins for the confidential
inputs required by `output/replication_package`:

- `analyze.rds`
- `analyze1.rds`
- `y14m_check_forbearance.csv.gz`
- `tx_harvey_obs.csv`

No row from the real data files is copied, transformed, or otherwise present
here. Every value is drawn from probability distributions calibrated to
match published/aggregate summary statistics only.

## Scale

The synthetic panel is a **~10% scaled-down** replica:

| | Real | Synthetic |
|---|---|---|
| T loans | 43,661 | 4,597 |
| C loans | 127,559 | 12,756 |
| T loan-months | 3,033,751 | ~312,000 |
| C loan-months | 8,399,268 | ~838,000 |

Same 13-event roster (Table S1) and ~30 synthetic bank IDs, with per-event
loan counts scaled proportionally (minimum 1 loan/event).
