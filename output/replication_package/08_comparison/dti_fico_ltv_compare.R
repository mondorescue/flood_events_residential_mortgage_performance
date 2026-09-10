# ============================================================================
# Boxplot of DTI, FICO, and LTV distributions by data source (Figure S1)
#
# Produces a three-panel boxplot comparing FR Y-14M and McDash synthetic
# samples across debt-to-income, FICO score, and loan-to-value. Box
# whiskers are drawn at the 10th/90th percentiles (not the default 1.5*IQR
# rule), and the horizontal line inside each box represents the median.
#
# NOTE: This script assumes the R working directory is the project root
# (i.e., "/path/to/floods-and-mortgages"). Run via
# run_all.R, or set your working directory accordingly before running
# standalone.
# ============================================================================

library(tidyverse)

PATH_DERIVED <- file.path("synthetic-data")
PATH_OUTPUT  <- file.path("output", "replication_package", "08_comparison")
dir.create(PATH_OUTPUT, recursive = TRUE, showWarnings = FALSE)

y14m   <- read_rds(file.path(PATH_DERIVED, "y14m_comp.rds"))
mcdash <- read_rds(file.path(PATH_DERIVED, "mcdash_comp.rds"))

y14m_plot <- y14m %>%
  transmute(
    source     = "FR Y-14M",
    dti_ratio  = dti_ratio_backend_orig / 100,
    fico_score = creditbureau_score_orig,
    ltv_ratio  = ltv_ratio_orig
  )

mcdash_plot <- mcdash %>%
  transmute(
    source     = "McDash",
    dti_ratio  = dti_ratio / 100,
    fico_score = fico_orig,
    ltv_ratio  = ltv_ratio / 100
  )

combined_long <- bind_rows(y14m_plot, mcdash_plot) %>%
  pivot_longer(
    cols = c(dti_ratio, fico_score, ltv_ratio),
    names_to = "variable",
    values_to = "value"
  ) %>%
  mutate(
    variable = factor(
      variable,
      levels = c("dti_ratio", "fico_score", "ltv_ratio"),
      labels = c("Debt-to-Income", "FICO Score", "Loan-to-Value")
    ),
    source = factor(source, levels = c("FR Y-14M", "McDash"))
  )

box_stats <- combined_long %>%
  group_by(variable, source) %>%
  summarize(
    ymin   = quantile(value, 0.10, na.rm = TRUE),
    lower  = quantile(value, 0.25, na.rm = TRUE),
    middle = quantile(value, 0.50, na.rm = TRUE),
    upper  = quantile(value, 0.75, na.rm = TRUE),
    ymax   = quantile(value, 0.90, na.rm = TRUE),
    .groups = "drop"
  )

boxplot_dti_fico_ltv <- ggplot(box_stats, aes(x = source, fill = source)) +
  geom_boxplot(
    aes(ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax),
    stat = "identity"
  ) +
  facet_wrap(~ variable, scales = "free_y", nrow = 1) +
  labs(x = NULL, y = NULL, fill = "Source") +
  theme_bw() +
  theme(
    legend.position = "none",
    strip.text = element_text(face = "bold"),
    axis.text.x = element_text(size = 10)
  )

ggsave(
  file.path(PATH_OUTPUT, "boxplot_dti_fico_ltv.png"),
  plot = boxplot_dti_fico_ltv,
  width = 10, height = 4, dpi = 300
)
message("Wrote: ", file.path(PATH_OUTPUT, "boxplot_dti_fico_ltv.png"))
print(boxplot_dti_fico_ltv)