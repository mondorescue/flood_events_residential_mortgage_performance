# ============================================================================
# Post-processing: Inundation x FICO disclosure plot (Figure S8)
#
# Reads the per-sub-group coefficient CSVs produced by static_did2s_runs.R
# for the "Inundation x FICO" specification (model indices 34-41, output
# files matching "_inun_fico_[1-4]_static.csv") and combines them into a
# single disclosure-ready plot showing ATT on 90-day delinquency and
# foreclosure across inundation depth quartiles, faceted/colored by FICO
# quartile.
#
# NOTE: Run static_did2s_runs.R first to generate the input CSVs.
# NOTE: Run with working directory = project root.
# ============================================================================

library(tidyverse)

PATH_OUTPUT <- file.path("output", "replication_package", "05_static_did2s")

f <- list.files(
  file.path(PATH_OUTPUT, "coefs_did2s"),
  pattern = "_inun_fico_[1-4]_static.csv",
  full.names = TRUE
)

df <- map_dfr(f, ~{
  read_csv(.x, show_col_types = FALSE) %>%
    mutate(
      file_group = str_extract(basename(.x), "^(delinq90|foreclo)"),
      fico_group = str_extract(basename(.x), "fico_([1-4])") %>% str_extract("[1-4]")
    )
}) %>%
  mutate(
    coef = coef * 100,
    se = se * 100,
    fico_group = factor(fico_group,
                        levels = c("1", "2", "3", "4"),
                        labels = c("1Q", "2Q", "3Q", "4Q")),
    Interacted_rel = factor(Interacted_rel,
                            levels = c("FFE not flooded", "FFE flooded 1Q",
                                       "FFE flooded 2Q", "FFE flooded 3Q",
                                       "FFE flooded 4Q"),
                            labels = c("<0", "1Q", "2Q", "3Q", "4Q")),
    file_group = factor(file_group,
                        levels = c("delinq90", "foreclo"),
                        labels = c("ATT on 90-day delinquency (pp)",
                                   "ATT on foreclosure (pp)"))
  )

p <-
  ggplot(df, aes(x = Interacted_rel, y = coef, color = fico_group)) +
  geom_hline(yintercept = 0, color = "black") +
  geom_point(position = position_dodge(width = 0.5)) +
  geom_errorbar(aes(ymin = coef - 1.96 * se, ymax = coef + 1.96 * se),
                width = 0, position = position_dodge(width = 0.5)) +
  facet_wrap(~ file_group) +
  scale_y_continuous(breaks = scales::breaks_width(1), labels = scales::label_number(accuracy = 1)) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    panel.border = element_rect(color = "black", fill = NA),
    axis.ticks = element_line(),
    axis.ticks.length = unit(0.25, "cm"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    axis.text.y = element_text()
  ) +
  labs(x = "Inundation depth at FFE",
       y = "",
       color = "FICO quartile")

p
ggsave(file.path(PATH_OUTPUT, "figS8_inundation_x_fico.pdf"), plot = p, width = 10, height = 5)
