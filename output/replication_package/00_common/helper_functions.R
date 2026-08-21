# ============================================================================
# Shared helper functions for did2s coefficient cleaning and plotting
#
# Sourced by all did2s scripts in the replication package.
# ============================================================================

# Extract coefficients from a did2s model object into a tidy data frame
clean_reg_fct <- function(reg_in, dat_in, interact_in, twoway_in = FALSE, notes_in = "", obsdat = FALSE) {
  reg1 <- reg_in

  if (is.null(reg1$obs_selection$obsRemoved)) {
    dat1 <- dat_in
  } else {
    dat1 <- dat_in[reg1$obs_selection$obsRemoved, ]
  }

  if (!twoway_in) {

    if (interact_in) {
      var1 <- str_split(names(reg1$coefficients)[1], ":")[[1]][4]
      val1 <- str_split(names(reg1$coefficients)[1], ":")[[1]][6]
      sub_obs1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1)), n)
      if (obsdat) {
        sub_obs_ctrl1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1) %>% filter(obs_group_type == "C")), n)
        sub_obs_trmt1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1) %>% filter(obs_group_type == "T")), n)
      } else {
        sub_obs_ctrl1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1) %>% filter(group_type == "C")), n)
        sub_obs_trmt1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1) %>% filter(group_type == "T")), n)
      }
    } else {
      sub_obs1 <- reg1$nobs
      if (obsdat) {
        sub_obs_ctrl1 <- pull(count(dat1 %>% filter(obs_group_type == "C")), n)
        sub_obs_trmt1 <- pull(count(dat1 %>% filter(obs_group_type == "T")), n)
      } else {
        sub_obs_ctrl1 <- pull(count(dat1 %>% filter(group_type == "C")), n)
        sub_obs_trmt1 <- pull(count(dat1 %>% filter(group_type == "T")), n)
      }
    }

    if (obsdat) {
      clean_coefs <-
        tibble(
          coef_names = names(reg1$coefficients),
          coef = reg1$coefficients,
          se = unname(se(reg1)),
          obs = reg1$nobs,
          obs_ctrl = pull(count(dat1 %>% filter(obs_group_type == "C")), n),
          obs_trmt = pull(count(dat1 %>% filter(obs_group_type == "T")), n),
          sub_obs  = sub_obs1,
          sub_obs_ctrl = sub_obs_ctrl1,
          sub_obs_trmt = sub_obs_trmt1,
          outcome = as.character(reg1$fml)[2]
        ) %>%
        mutate(Rel_month = str_extract(coef_names, "(?<=::).?[:digit:]{1,2}")) %>%
        mutate(Rel_month = as.integer(Rel_month)) %>%
        mutate(Interacted_rel = str_extract(coef_names, "(?<=[:digit:]{1,3}:).*")) %>%
        mutate(notes = notes_in)
    } else {
      clean_coefs <-
        tibble(
          coef_names = names(reg1$coefficients),
          coef = reg1$coefficients,
          se = unname(se(reg1)),
          obs = reg1$nobs,
          obs_ctrl = pull(count(dat1 %>% filter(group_type == "C")), n),
          obs_trmt = pull(count(dat1 %>% filter(group_type == "T")), n),
          sub_obs  = sub_obs1,
          sub_obs_ctrl = sub_obs_ctrl1,
          sub_obs_trmt = sub_obs_trmt1,
          outcome = as.character(reg1$fml)[2]
        ) %>%
        mutate(Rel_month = str_extract(coef_names, "(?<=::).?[:digit:]{1,2}")) %>%
        mutate(Rel_month = as.integer(Rel_month)) %>%
        mutate(Interacted_rel = str_extract(coef_names, "(?<=[:digit:]{1,3}:).*")) %>%
        mutate(notes = notes_in)
    }

  } else {

    var2 <- str_split(names(reg1$coefficients)[1], ":")[[1]][1]

    if (interact_in) {
      var1 <- str_split(names(reg1$coefficients)[1], ":")[[1]][4]
      val1 <- str_split(names(reg1$coefficients)[1], ":")[[1]][6]
      sub_obs1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1)), n)
      sub_obs_ctrl1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1) %>% filter(!!sym(var2) == 0)), n)
      sub_obs_trmt1 <- pull(count(dat1 %>% filter(!!sym(var1) == val1) %>% filter(!!sym(var2) == 1)), n)
    } else {
      sub_obs1 <- reg1$nobs
      sub_obs_ctrl1 <- pull(count(dat1 %>% filter(!!sym(var2) == 0)), n)
      sub_obs_trmt1 <- pull(count(dat1 %>% filter(!!sym(var2) == 1)), n)
    }

    clean_coefs <-
      tibble(
        coef_names = names(reg1$coefficients),
        coef = reg1$coefficients,
        se = unname(se(reg1)),
        obs = reg1$nobs,
        obs_ctrl = pull(count(dat1 %>% filter(!!sym(var2) == 0)), n),
        obs_trmt = pull(count(dat1 %>% filter(!!sym(var2) == 1)), n),
        sub_obs  = sub_obs1,
        sub_obs_ctrl = sub_obs_ctrl1,
        sub_obs_trmt = sub_obs_trmt1,
        outcome = as.character(reg1$fml)[2]
      ) %>%
      mutate(Rel_month = str_extract(coef_names, "(?<=::).?[:digit:]{1,2}")) %>%
      mutate(Rel_month = as.integer(Rel_month)) %>%
      mutate(Interacted_rel = str_extract(coef_names, "(?<=[:digit:]{1,3}:).*")) %>%
      mutate(notes = notes_in)

  }
  clean_coefs
}


# Plot coefficients from clean_reg_fct(), either as an event study (ES = TRUE)
# or as a static bar/point plot across sub-groups (ES = FALSE)
plot_coefs_function <- function(clean_coefs, interacted = FALSE, ES = TRUE) {

  if (ES) {  # Event Study
    ggplot(clean_coefs, aes(x = Rel_month)) +
      {if (!interacted) geom_point(aes(y = coef))} +
      {if (!interacted) geom_errorbar(aes(ymin = coef - 1.96 * se, ymax = coef + 1.96 * se), width = .5)} +
      {if (interacted) geom_point(aes(y = coef, color = Interacted_rel))} +
      {if (interacted) geom_errorbar(aes(ymin = coef - 1.96 * se, ymax = coef + 1.96 * se, color = Interacted_rel), width = .5)} +
      geom_hline(yintercept = 0, color = "grey70", linetype = "longdash") +
      geom_vline(xintercept = 0, color = "red4", linetype = "solid") +
      xlab("Month relative to disaster") +
      theme_minimal() +
      theme(legend.position = "bottom")
  } else {  # Static
    ggplot(clean_coefs) +
      {if (!interacted) geom_point(aes(y = coef, x = outcome))} +
      {if (!interacted) geom_errorbar(aes(ymin = coef - 1.96 * se, ymax = coef + 1.96 * se, x = outcome), width = .5)} +
      {if (interacted) geom_point(aes(y = coef, x = Interacted_rel, color = Interacted_rel))} +
      {if (interacted) geom_errorbar(aes(x = Interacted_rel, ymin = coef - 1.96 * se, ymax = coef + 1.96 * se, color = Interacted_rel), width = .5)} +
      geom_hline(yintercept = 0, color = "grey70", linetype = "longdash") +
      geom_vline(xintercept = 0, color = "red4", linetype = "solid") +
      xlab("") +
      theme_minimal() +
      theme(legend.position = "bottom")
  }

}
