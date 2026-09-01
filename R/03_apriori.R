# =============================================================================
# 03_apriori.R -- Market Basket Analysis with the Apriori algorithm
#
# Concepts used here:
#   support(X)      = P(X)                  how often the itemset appears
#   confidence(X=>Y)= P(Y|X) = supp(XuY)/supp(X)
#   lift(X=>Y)      = conf / supp(Y)        > 1 means positively associated
#   Apriori property: every subset of a frequent itemset is itself frequent,
#                     which is what lets the algorithm prune the search space.
# =============================================================================

source(file.path(getwd(), "R", "00_setup.R"))

retail <- readRDS(file.path(DIR_PROC, "retail_clean.rds"))

# ---- 1. Build the transaction ("basket") object ----------------------------
# arules wants a list: one character vector of item labels per transaction.
basket_list <- split(retail$Item, retail$InvoiceNo)
basket_list <- lapply(basket_list, unique)

trans <- as(basket_list, "transactions")

message("Transaction object:")
print(trans)
cat("\n")
print(summary(trans))

sink(file.path(DIR_TAB, "03_transactions_summary.txt"))
print(summary(trans))
sink()

# ---- 2. Item frequency ------------------------------------------------------
png(file.path(DIR_FIG, "07_item_frequency_relative.png"),
    width = 1400, height = 900, res = 150)
arules::itemFrequencyPlot(trans, topN = PARAMS$top_n, type = "relative",
                          col = brewer.pal(8, "Blues")[5],
                          main = paste("Top", PARAMS$top_n, "items by support"),
                          cex.names = 0.7)
dev.off()
message("  saved figure -> 07_item_frequency_relative.png")

# ---- 3. Frequent itemsets (the first half of Apriori) ----------------------
itemsets <- arules::apriori(
  trans,
  parameter = list(support = PARAMS$support,
                   minlen  = 1,
                   maxlen  = PARAMS$maxlen,
                   target  = "frequent itemsets"),
  control   = list(verbose = FALSE)
)

itemset_sizes <- table(size(itemsets))
message("\nFrequent itemsets found at support >= ", PARAMS$support, ":")
print(itemset_sizes)

save_tab(
  data.frame(ItemsetSize = as.integer(names(itemset_sizes)),
             Count = as.integer(itemset_sizes)),
  "03_frequent_itemset_counts")

top_itemsets <- head(sort(itemsets, by = "support", decreasing = TRUE), 30)
itemsets_df <- data.frame(
  Itemset = labels(top_itemsets),
  Size    = size(top_itemsets),
  Support = round(quality(top_itemsets)$support, 5),
  Count   = quality(top_itemsets)$count
)
save_tab(itemsets_df, "03_top30_frequent_itemsets")

# Frequent itemsets of size >= 2 are the interesting ones for cross-sell
multi <- itemsets[size(itemsets) >= 2]
multi <- head(sort(multi, by = "support", decreasing = TRUE), PARAMS$top_n)
save_tab(data.frame(Itemset = labels(multi),
                    Size    = size(multi),
                    Support = round(quality(multi)$support, 5),
                    Count   = quality(multi)$count),
         "03_top_multi_item_itemsets")

# ---- 4. Association rules (the second half of Apriori) ---------------------
rules <- arules::apriori(
  trans,
  parameter = list(support    = PARAMS$support,
                   confidence = PARAMS$confidence,
                   minlen     = PARAMS$minlen,
                   maxlen     = PARAMS$maxlen,
                   target     = "rules"),
  control   = list(verbose = FALSE)
)

message("\nRules generated: ", length(rules))

# Keep only rules that beat chance, then drop redundant ones.
# A rule is redundant if a more general rule (subset of the LHS) has
# at least the same confidence -- the extra condition adds nothing.
rules <- subset(rules, lift > PARAMS$min_lift)
message("Rules with lift > ", PARAMS$min_lift, ": ", length(rules))

rules <- rules[!arules::is.redundant(rules)]
message("Rules after removing redundant ones: ", length(rules))

# Fisher's exact test on the 2x2 contingency table, Benjamini-Hochberg
# adjusted -- guards against rules that look strong purely by chance.
if (length(rules) > 0) {
  quality(rules)$fishersPValue <- arules::interestMeasure(
    rules, measure = "fishersExactTest", transactions = trans)
  quality(rules)$pAdjusted <- p.adjust(quality(rules)$fishersPValue, method = "BH")
  sig_rules <- subset(rules, pAdjusted < 0.05)
  message("Statistically significant rules (BH-adjusted p < 0.05): ", length(sig_rules))
} else {
  sig_rules <- rules
}

# ---- 5. Export rule tables --------------------------------------------------
rules_to_df <- function(r) {
  if (length(r) == 0) return(data.frame())
  df <- arules::DATAFRAME(r, setStart = "", setEnd = "", itemSep = " + ")
  names(df)[1:2] <- c("Antecedent_LHS", "Consequent_RHS")
  df$Antecedent_LHS <- as.character(df$Antecedent_LHS)
  df$Consequent_RHS <- as.character(df$Consequent_RHS)
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], function(x) round(x, 5))
  df
}

all_rules_df <- rules_to_df(sort(sig_rules, by = "lift", decreasing = TRUE))
save_tab(all_rules_df, "03_all_significant_rules")

save_tab(head(rules_to_df(sort(sig_rules, by = "lift",       decreasing = TRUE)), PARAMS$top_n),
         "03_top_rules_by_lift")
save_tab(head(rules_to_df(sort(sig_rules, by = "confidence", decreasing = TRUE)), PARAMS$top_n),
         "03_top_rules_by_confidence")
save_tab(head(rules_to_df(sort(sig_rules, by = "support",    decreasing = TRUE)), PARAMS$top_n),
         "03_top_rules_by_support")

message("\n--- TOP 10 RULES BY LIFT ---")
arules::inspect(head(sort(sig_rules, by = "lift", decreasing = TRUE), 10))

message("\n--- TOP 10 RULES BY CONFIDENCE ---")
arules::inspect(head(sort(sig_rules, by = "confidence", decreasing = TRUE), 10))

# ---- 6. Sensitivity: how does the rule count react to the thresholds? ------
grid <- expand.grid(support    = c(0.005, 0.0075, 0.01, 0.015, 0.02),
                    confidence = c(0.2, 0.3, 0.4, 0.5, 0.6))
grid$n_rules <- mapply(function(s, c_) {
  r <- suppressWarnings(arules::apriori(
    trans,
    parameter = list(support = s, confidence = c_,
                     minlen = 2, maxlen = PARAMS$maxlen),
    control = list(verbose = FALSE)))
  length(r)
}, grid$support, grid$confidence)
save_tab(grid, "03_threshold_sensitivity")

p_sens <- ggplot(grid, aes(factor(support), n_rules,
                           colour = factor(confidence), group = confidence)) +
  geom_line(linewidth = 0.9) + geom_point(size = 2) +
  scale_y_log10(labels = comma) +
  scale_colour_brewer(palette = "Set1", name = "min confidence") +
  labs(title = "How many rules survive each threshold pair?",
       subtitle = "Rule count is extremely sensitive to minimum support (log scale)",
       x = "Minimum support", y = "Number of rules") +
  theme_mba()
save_fig(p_sens, "08_threshold_sensitivity")

# ---- 7. Persist objects for the visualisation script -----------------------
saveRDS(trans,     file.path(DIR_PROC, "transactions.rds"))
saveRDS(rules,     file.path(DIR_PROC, "rules.rds"))
saveRDS(sig_rules, file.path(DIR_PROC, "rules_significant.rds"))
saveRDS(itemsets,  file.path(DIR_PROC, "itemsets.rds"))

message("\nApriori stage complete.")
