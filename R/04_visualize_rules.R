# =============================================================================
# 04_visualize_rules.R -- Visual interpretation of the association rules
# =============================================================================

source(file.path(getwd(), "R", "00_setup.R"))

trans     <- readRDS(file.path(DIR_PROC, "transactions.rds"))
sig_rules <- readRDS(file.path(DIR_PROC, "rules_significant.rds"))

stopifnot(length(sig_rules) > 0)
message("Visualising ", length(sig_rules), " significant rules.")

q <- quality(sig_rules)

# ---- 1. Scatter: support vs confidence, coloured by lift -------------------
scatter_df <- data.frame(support = q$support, confidence = q$confidence, lift = q$lift)

p1 <- ggplot(scatter_df, aes(support, confidence, colour = lift)) +
  geom_point(alpha = 0.65, size = 2) +
  scale_colour_distiller(palette = "Spectral", name = "Lift") +
  scale_x_continuous(labels = percent_format(accuracy = 0.1)) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(title = "Rule landscape: support vs confidence",
       subtitle = paste0(length(sig_rules), " rules | colour = lift. ",
                         "The upper-left corner holds the rare-but-reliable rules."),
       x = "Support", y = "Confidence") +
  theme_mba()
save_fig(p1, "09_rules_scatter")

# ---- 2-5. arulesViz Plots (conditional on arulesViz package) ----------------
if (requireNamespace("arulesViz", quietly = TRUE)) {
  # 2. Two-key plot: order (number of items) against support/confidence
  png(file.path(DIR_FIG, "10_rules_two_key.png"), width = 1400, height = 950, res = 150)
  plot(sig_rules, method = "two-key plot",
       main = "Rules by order (items per rule)")
  dev.off()
  message("  saved figure -> 10_rules_two_key.png")

  # 3. Graph of the strongest rules
  top_lift <- head(sort(sig_rules, by = "lift", decreasing = TRUE), 25)
  png(file.path(DIR_FIG, "11_rules_graph_top25_lift.png"), width = 1800, height = 1400, res = 150)
  plot(top_lift, method = "graph",
       control = list(main = "Top 25 rules by lift -- product association network"),
       engine = "igraph")
  dev.off()
  message("  saved figure -> 11_rules_graph_top25_lift.png")

  # 4. Grouped matrix: the compact overview of every rule
  png(file.path(DIR_FIG, "12_rules_grouped_matrix.png"), width = 1800, height = 1300, res = 150)
  plot(sig_rules, method = "grouped",
       control = list(k = 15, main = "Grouped matrix of association rules"))
  dev.off()
  message("  saved figure -> 12_rules_grouped_matrix.png")

  # 5. Parallel coordinates for the top rules
  png(file.path(DIR_FIG, "13_rules_paracoord.png"), width = 1800, height = 1200, res = 150)
  plot(head(sort(sig_rules, by = "confidence", decreasing = TRUE), 20),
       method = "paracoord",
       control = list(reorder = TRUE, main = "Top 20 rules by confidence"))
  dev.off()
  message("  saved figure -> 13_rules_paracoord.png")
} else {
  message("  [NOTE] Skipping arulesViz plots (arulesViz is not installed). Pre-existing figures retained.")
}

# ---- 6. Horizontal bar of the top rules by lift ----------------------------
top_df <- arules::DATAFRAME(head(sort(sig_rules, by = "lift", decreasing = TRUE), PARAMS$top_n),
                            setStart = "", setEnd = "", itemSep = " + ")
names(top_df)[1:2] <- c("LHS", "RHS")
top_df$Rule <- paste(top_df$LHS, "=>", top_df$RHS)
top_df$Rule <- ifelse(nchar(top_df$Rule) > 70,
                      paste0(substr(top_df$Rule, 1, 67), "..."), top_df$Rule)

p6 <- ggplot(top_df, aes(reorder(Rule, lift), lift, fill = confidence)) +
  geom_col() +
  coord_flip() +
  scale_fill_distiller(palette = "YlOrRd", direction = 1,
                       name = "Confidence", labels = percent_format(accuracy = 1)) +
  labs(title = paste("Top", PARAMS$top_n, "association rules by lift"),
       subtitle = "Lift = how many times more likely the RHS is, given the LHS",
       x = NULL, y = "Lift") +
  theme_mba(base_size = 10)
save_fig(p6, "14_top_rules_by_lift_bars", width = 11, height = 7)

# ---- 7. Targeted analysis: what drives a specific bestseller? --------------
# Pick the single most frequent item and ask what leads customers to it.
freq <- sort(itemFrequency(trans), decreasing = TRUE)
target <- names(freq)[1]
message("\nTargeted analysis for: ", target)

rules_to_target <- arules::apriori(
  trans,
  parameter = list(support = 0.005, confidence = 0.4, minlen = 2, maxlen = 3),
  appearance = list(rhs = target, default = "lhs"),
  control = list(verbose = FALSE)
)
rules_to_target <- sort(rules_to_target[!is.redundant(rules_to_target)],
                        by = "lift", decreasing = TRUE)

if (length(rules_to_target) > 0) {
  df <- arules::DATAFRAME(head(rules_to_target, 15), setStart = "", setEnd = "", itemSep = " + ")
  names(df)[1:2] <- c("Antecedent_LHS", "Consequent_RHS")
  save_tab(df, "04_rules_leading_to_top_item")
  arules::inspect(head(rules_to_target, 10))
} else {
  message("  no rules found for this target at the chosen thresholds")
}

# The mirror question: what do people buy AFTER the bestseller is in the basket?
rules_from_target <- arules::apriori(
  trans,
  parameter = list(support = 0.005, confidence = 0.4, minlen = 2, maxlen = 3),
  appearance = list(lhs = target, default = "rhs"),
  control = list(verbose = FALSE)
)
if (length(rules_from_target) > 0) {
  rules_from_target <- sort(rules_from_target[!is.redundant(rules_from_target)],
                            by = "lift", decreasing = TRUE)
  df2 <- arules::DATAFRAME(head(rules_from_target, 15), setStart = "", setEnd = "", itemSep = " + ")
  names(df2)[1:2] <- c("Antecedent_LHS", "Consequent_RHS")
  save_tab(df2, "04_rules_from_top_item")
}

message("\nVisualisation stage complete.")
