# =============================================================================
# 05_segments_and_recommendations.R
#   a) Compare rule structure across market segments (UK vs International)
#   b) Compare seasons (festive quarter vs rest of year)
#   c) Turn rules into a simple recommender + quantified business value
# =============================================================================

source(file.path(getwd(), "R", "00_setup.R"))

retail <- readRDS(file.path(DIR_PROC, "retail_clean.rds"))

make_trans <- function(df) {
  bl <- lapply(split(df$Item, df$InvoiceNo), unique)
  bl <- bl[lengths(bl) >= 2]
  as(bl, "transactions")
}

mine <- function(tr, support = PARAMS$support, confidence = PARAMS$confidence) {
  r <- arules::apriori(tr,
        parameter = list(support = support, confidence = confidence,
                         minlen = 2, maxlen = PARAMS$maxlen),
        control = list(verbose = FALSE))
  r <- subset(r, lift > 1)
  r[!arules::is.redundant(r)]
}

to_df <- function(r, n = 25) {
  df <- arules::DATAFRAME(head(sort(r, by = "lift", decreasing = TRUE), n),
                          setStart = "", setEnd = "", itemSep = " + ")
  names(df)[1:2] <- c("Antecedent_LHS", "Consequent_RHS")
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], function(x) round(x, 5))
  df
}

# ---- 1. Geographic segments -------------------------------------------------
retail$Segment <- ifelse(retail$Country == "United Kingdom", "UK", "International")

seg_results <- list()
for (s in c("UK", "International")) {
  d  <- dplyr::filter(retail, Segment == s)
  tr <- make_trans(d)
  # International has far fewer baskets, so relax support to keep it comparable
  sup <- if (s == "UK") PARAMS$support else 0.02
  r  <- mine(tr, support = sup)
  seg_results[[s]] <- list(trans = tr, rules = r, support = sup)

  message(sprintf("%-14s baskets=%5d items=%5d  support=%.3f  rules=%d",
                  s, length(tr), ncol(tr), sup, length(r)))

  if (length(r) > 0) {
    save_tab(to_df(r), paste0("05_top_rules_", tolower(s)))
  }
}

seg_summary <- data.frame(
  Segment    = names(seg_results),
  Baskets    = sapply(seg_results, function(x) length(x$trans)),
  Products   = sapply(seg_results, function(x) ncol(x$trans)),
  MinSupport = sapply(seg_results, function(x) x$support),
  Rules      = sapply(seg_results, function(x) length(x$rules)),
  MeanLift   = sapply(seg_results, function(x)
                  if (length(x$rules)) round(mean(quality(x$rules)$lift), 2) else NA),
  MaxLift    = sapply(seg_results, function(x)
                  if (length(x$rules)) round(max(quality(x$rules)$lift), 2) else NA),
  row.names = NULL
)
print(seg_summary)
save_tab(seg_summary, "05_segment_comparison")

# ---- 2. Seasonal segments: festive quarter vs the rest ----------------------
retail$Season <- ifelse(lubridate::month(retail$Date) %in% c(9, 10, 11),
                        "Pre-Christmas (Sep-Nov)", "Rest of year")

rules_fest <- NULL
rules_rest <- NULL
season_rows <- list()

for (s in c("Pre-Christmas (Sep-Nov)", "Rest of year")) {
  d  <- dplyr::filter(retail, Season == s)
  tr <- make_trans(d)
  r  <- mine(tr)
  message(sprintf("%-26s baskets=%5d rules=%d", s, length(tr), length(r)))

  tag <- if (grepl("Pre", s)) "prechristmas" else "restofyear"
  if (length(r) > 0) save_tab(to_df(r), paste0("05_top_rules_", tag))
  if (tag == "prechristmas") rules_fest <- r else rules_rest <- r

  season_rows[[s]] <- data.frame(
    Season = s, Baskets = length(tr), Rules = length(r),
    MeanLift = if (length(r)) round(mean(quality(r)$lift), 2) else NA)
}
season_df <- do.call(rbind, season_rows)
rownames(season_df) <- NULL
print(season_df)
save_tab(season_df, "05_season_comparison")

# ---- 3. Rules unique to the festive quarter --------------------------------
if (length(rules_fest) > 0 && length(rules_rest) > 0) {
  only_fest <- rules_fest[!(labels(rules_fest) %in% labels(rules_rest))]
  message("Rules that appear only in the festive quarter: ", length(only_fest))
  if (length(only_fest) > 0) save_tab(to_df(only_fest), "05_festive_only_rules")
}

# ---- 4. A rule-based recommender -------------------------------------------
# Given a partial basket, return the highest-lift consequents whose antecedent
# is fully contained in that basket and which the customer has not yet taken.
rules_all <- readRDS(file.path(DIR_PROC, "rules_significant.rds"))
LHS_LIST  <- as(lhs(rules_all), "list")
RHS_ITEM  <- unlist(as(rhs(rules_all), "list"))
QUAL      <- quality(rules_all)

recommend <- function(basket, n = 5) {
  fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
  if (!any(fires)) return(data.frame())
  out <- data.frame(Recommendation = RHS_ITEM[fires],
                    Confidence = round(QUAL$confidence[fires], 3),
                    Lift       = round(QUAL$lift[fires], 2),
                    Support    = round(QUAL$support[fires], 4))
  out <- out[!out$Recommendation %in% basket, , drop = FALSE]
  if (nrow(out) == 0) return(out)
  out <- out[order(-out$Lift), ]
  out <- out[!duplicated(out$Recommendation), ]
  head(out, n)
}

# Demo on three real baskets drawn from the data
set.seed(7)
sizes <- table(retail$InvoiceNo)
candidates <- names(sizes)[sizes >= 3 & sizes <= 8]
demo_invoices <- sample(candidates, 3)

demo_out <- list()
for (inv in demo_invoices) {
  bk  <- unique(retail$Item[retail$InvoiceNo == inv])
  rec <- recommend(bk, n = 5)
  message("\nBasket ", inv, ":\n  ", paste(bk, collapse = "\n  "))
  if (nrow(rec) > 0) {
    print(rec, row.names = FALSE)
    demo_out[[inv]] <- data.frame(Invoice = inv,
                                  Basket = paste(bk, collapse = " | "), rec)
  } else {
    message("  (no rule fires for this basket)")
  }
}
if (length(demo_out)) save_tab(do.call(rbind, demo_out), "05_recommender_demo")

# ---- 5. Business value of the top rules ------------------------------------
# For each top rule: how many baskets contain the LHS but NOT the RHS?
# Those are the concrete cross-sell opportunities, priced at the RHS unit price.
price <- retail |>
  dplyr::group_by(Item) |>
  dplyr::summarise(AvgPrice = mean(UnitPrice),
                   AvgQty   = mean(Quantity), .groups = "drop")

trans <- readRDS(file.path(DIR_PROC, "transactions.rds"))
N     <- length(trans)
q     <- quality(rules_all)

# No basket scan needed: coverage is supp(LHS) and support is supp(LHS u RHS),
# so baskets holding the LHS but missing the RHS = (coverage - support) * N.
value_df <- data.frame(
  Rule          = labels(rules_all),
  Consequent    = unlist(as(rhs(rules_all), "list")),
  Support       = round(q$support, 5),
  Confidence    = round(q$confidence, 3),
  Lift          = round(q$lift, 2),
  MissedBaskets = round((q$coverage - q$support) * N)
) |>
  dplyr::left_join(price, by = c("Consequent" = "Item")) |>
  dplyr::mutate(
    # Baskets we would expect to convert if the rule were surfaced as a prompt.
    ExpectedUplift   = MissedBaskets * Confidence,
    PotentialRevenue = round(ExpectedUplift * AvgPrice * AvgQty, 2),
    ExpectedUplift   = round(ExpectedUplift)
  ) |>
  dplyr::arrange(dplyr::desc(PotentialRevenue))

message("\n--- TOP 10 CROSS-SELL OPPORTUNITIES BY POTENTIAL REVENUE ---")
print(head(value_df[, c("Rule", "Confidence", "Lift",
                        "MissedBaskets", "PotentialRevenue")], 10),
      row.names = FALSE)
save_tab(value_df, "05_cross_sell_opportunity_value")

# Rules overlap heavily -- many share a consequent and fire on the same basket --
# so summing across all of them double counts. Deduplicating by consequent, and
# keeping only that consequent's single best rule, gives a defensible figure.
best_per_consequent <- value_df |>
  dplyr::group_by(Consequent) |>
  dplyr::slice_max(PotentialRevenue, n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::arrange(dplyr::desc(PotentialRevenue))
save_tab(best_per_consequent, "05_cross_sell_best_rule_per_product")

message(sprintf("\nRules scored: %d, covering %d distinct consequent products",
                nrow(value_df), nrow(best_per_consequent)))
message(sprintf("Naive sum over all rules       : GBP %s  (double counts -- upper bound only)",
                format(round(sum(value_df$PotentialRevenue, na.rm = TRUE)), big.mark = ",")))
message(sprintf("Best rule per consequent       : GBP %s  (defensible headroom estimate)",
                format(round(sum(best_per_consequent$PotentialRevenue, na.rm = TRUE)), big.mark = ",")))
message(sprintf("Top 20 products of those       : GBP %s  (%.0f%% of it)",
                format(round(sum(head(best_per_consequent, 20)$PotentialRevenue, na.rm = TRUE)), big.mark = ","),
                100 * sum(head(best_per_consequent, 20)$PotentialRevenue, na.rm = TRUE) /
                      sum(best_per_consequent$PotentialRevenue, na.rm = TRUE)))

p_val <- head(best_per_consequent, 15) |>
  dplyr::mutate(Label = ifelse(nchar(Rule) > 62, paste0(substr(Rule, 1, 59), "..."), Rule)) |>
  ggplot(aes(reorder(Label, PotentialRevenue), PotentialRevenue, fill = Lift)) +
  geom_col() +
  coord_flip() +
  scale_fill_distiller(palette = "GnBu", direction = 1, name = "Lift") +
  scale_y_continuous(labels = label_number(prefix = "GBP ", big.mark = ",")) +
  labs(title = "Top 15 cross-sell opportunities by estimated revenue",
       subtitle = "Baskets holding the antecedent but missing the consequent, priced at average line value",
       x = NULL, y = "Estimated 12-month revenue opportunity") +
  theme_mba(base_size = 10)
save_fig(p_val, "15_cross_sell_opportunity_value", width = 11, height = 7)

message("\nSegment and recommendation stage complete.")
