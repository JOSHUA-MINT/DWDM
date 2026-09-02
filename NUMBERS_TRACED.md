# Basket Lens — Every Number on the Dashboard, Traced to Its Source

This file answers one question, exhaustively, for **every number, chart, and table shown in the
7-tab dashboard**: *where did this exact value come from, which file computed it, and which
lines of code produced it?* Formulas are explained in full in `THEORY.md`; general code
structure is explained in `CODE_EXPLAINED.md`. This file is purely a traceability map:
**on-screen element → source file → code lines → logic.**

All line numbers refer to `app.R` unless another file is named. `D()` always means "the shared,
already-loaded data bundle" (see `CODE_EXPLAINED.md` § `app.R` startup sequence).

---

## Tab 1 — Overview

### KPI box: "Baskets" (top-left)
- **UI:** `valueBoxOutput("ov_baskets", width = 3)` — `app.R:173`
- **Server:** `app.R:471-477`
```r
output$ov_baskets <- renderValueBox({
  d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
  valueBox(format(n_distinct(d$retail$InvoiceNo), big.mark = ","), "Baskets", ...)
})
```
- **Logic:** counts the number of *distinct* `InvoiceNo` values in `d$retail`, which is the
  in-memory object loaded from `data/processed/retail_clean.rds`.
- **Upstream origin:** `retail_clean.rds` is written by `R/01_load_clean.R:124`, after all
  cleaning filters (cancellations, bad quantity/price, admin codes, junk descriptions,
  single-item baskets — see `CODE_EXPLAINED.md`) have already been applied. **The number shown
  (18,273) is therefore the count of unique invoices in the *cleaned*, not raw, dataset** — the
  raw file has more invoices, many of which were cancellations or otherwise removed.

### KPI box: "Unique Products"
- **Server:** `app.R:478-484`
```r
valueBox(format(n_distinct(d$retail$Item), big.mark = ","), "Unique Products", ...)
```
- **Logic:** `n_distinct()` on the `Item` column — **not** `StockCode` or the raw `Description`.
  `Item` is the *canonical* product name assigned in `R/01_load_clean.R:88-97` (the single most
  common description text per `StockCode`), so this count (3,765) reflects deduplicated product
  identities, not the raw distinct-description count (which would be higher due to spelling
  drift).

### KPI box: "Significant Rules"
- **Server:** `app.R:485-491`
```r
valueBox(format(length(d$sig), big.mark = ","), "Significant Rules", ...)
```
- **Logic:** `d$sig` is the `arules` rule-set object loaded straight from
  `data/processed/rules_significant.rds` (`app.R:433-434`). `length()` on an `arules` rules
  object returns how many rules it contains.
- **Upstream origin:** that `.rds` file is written by `R/03_apriori.R:168`, and its contents are
  exactly the rules that survived **all four filters** described in `THEORY.md` §4.4: lift > 1,
  redundancy removal, Fisher's exact test, and Benjamini-Hochberg correction (p < 0.05). The
  number shown (2,215) is the final post-filter count — it is computed *once*, offline, by the
  pipeline; the dashboard never recomputes it, only counts the already-filtered object.

### KPI box: "Total Revenue"
- **Server:** `app.R:492-498`
```r
valueBox(paste0("GBP ", format(round(sum(d$retail$Revenue)), big.mark = ",")), "Total Revenue", ...)
```
- **Logic:** sums the `Revenue` column across every row of `d$retail`.
- **Upstream origin:** `Revenue` is a *derived* column, computed once per row as
  `Quantity * UnitPrice` in `R/01_load_clean.R:80` (`Revenue = Quantity * UnitPrice`), during the
  cleaning `mutate()` chain. It is **not** recomputed by the dashboard — it's already a column in
  `retail_clean.rds`, and `app.R` just sums it.

### Chart: "Monthly Revenue Trend"
- **Server:** `app.R:500-510`
```r
d$monthly %>% mutate(Month = as.Date(Month)) %>%
  ggplot(aes(Month, Revenue)) + geom_col(fill = "#D94801", width = 18) + ...
```
- **Data source:** `d$monthly` is loaded via `load_csv("02_monthly_sales.csv")` (`app.R:437`).
- **Upstream origin:** that CSV is written by `R/02_eda.R:73-77`:
  ```r
  monthly <- retail |> dplyr::group_by(Month) |>
    dplyr::summarise(Revenue = sum(Revenue), Transactions = dplyr::n_distinct(InvoiceNo))
  ```
  i.e., `Revenue` per bar = sum of the same per-row `Revenue` column, grouped by `Month`
  (itself derived via `lubridate::floor_date(Date, "month")` back in `01_load_clean.R:82`). The
  chart is drawn live by `ggplot2` inside the Shiny session, but the underlying numbers are a
  pre-aggregated CSV, not a live recomputation from raw rows.

### Chart: "Top 10 Products by Frequency"
- **Server:** `app.R:512-524`
```r
head(d$top_freq, 10) %>% mutate(Item = reorder(Item, Baskets)) %>%
  ggplot(aes(Item, Baskets)) + geom_col(fill = "#2C7FB8") + ...
```
- **Data source:** `d$top_freq` ← `load_csv("02_top50_items_by_frequency.csv")` (`app.R:439`).
- **Upstream origin:** `R/02_eda.R:11-14`:
  ```r
  top_items <- retail |> dplyr::count(Item, name = "Baskets") |>
    dplyr::mutate(Support = Baskets / dplyr::n_distinct(retail$InvoiceNo)) |>
    dplyr::arrange(dplyr::desc(Baskets))
  ```
  `Baskets` per product = a plain `count()` of how many rows (baskets) contain that `Item` (since
  duplicate item-per-basket rows were already collapsed to one in cleaning). The chart takes
  only the top 10 of the already-sorted top-50 CSV.

### Chart: "Trading Rhythm: Weekday x Hour" (heatmap)
- **Server:** `app.R:526-536` — **the one Overview chart computed entirely live, not from a CSV:**
```r
d$retail %>% distinct(InvoiceNo, Weekday, Hour) %>%
  count(Weekday, Hour, name = "Transactions") %>%
  ggplot(aes(x = Hour, y = Weekday, fill = Transactions)) + geom_tile(...) + ...
```
- **Logic:** `distinct(InvoiceNo, Weekday, Hour)` collapses each basket to a single row (one
  basket might otherwise contribute one row per item, which would inflate the hour/weekday
  counts); `count(Weekday, Hour)` then counts how many *baskets* (not line-items) were created in
  each weekday/hour cell. `Weekday` and `Hour` themselves are derived columns computed once in
  `R/01_load_clean.R:83-84` from `InvoiceDate`. Although this specific chart re-aggregates `d$retail`
  live inside the Shiny server (rather than reading a pre-made CSV), it is the *same underlying
  data* as `output/figures/05_weekday_hour_heatmap.png` (produced identically by
  `R/02_eda.R:91-102`) — the two are computed with the same logic, just one is baked to PNG
  offline and the other is redrawn live.

### Chart: "Top Countries by Revenue"
- **Server:** `app.R:538-548`
```r
head(arrange(d$by_country, desc(Revenue)), 10) %>% mutate(Country = reorder(Country, Revenue)) %>%
  ggplot(aes(Country, Revenue)) + geom_col(fill = "#7A0177") + coord_flip() + ...
```
- **Data source:** `d$by_country` ← `load_csv("02_by_country.csv")` (`app.R:438`).
- **Upstream origin:** `R/02_eda.R:105-111`:
  ```r
  by_country <- retail |> dplyr::group_by(Country) |>
    dplyr::summarise(Transactions = dplyr::n_distinct(InvoiceNo), Revenue = sum(Revenue)) |>
    dplyr::arrange(dplyr::desc(Revenue)) |> dplyr::mutate(RevenueShare = Revenue / sum(Revenue))
  ```
  `Revenue` per country = sum of the per-row `Revenue` column grouped by `Country` (a raw
  dataset column, untouched by cleaning except for row removal).

---

## Tab 2 — Exploratory (EDA)

### Chart: "Top Products by Basket Frequency" (with the "Show top N items" dropdown)
- **UI:** `selectInput("eda_freq_n", "Show top N items", choices = c(10,15,20,25,30,50), selected = 20)` — `app.R:198-199`
- **Server:** `app.R:553-567`
```r
n <- as.integer(input$eda_freq_n) %||% 20
head(d$top_freq, n) %>% mutate(Item = reorder(Item, Baskets)) %>%
  ggplot(aes(Item, Baskets)) + geom_col(fill = "#2C7FB8") + ...
```
- **Logic:** re-slices the *same* `02_top50_items_by_frequency.csv` used on the Overview tab
  (already sorted descending by `Baskets`), but to however many rows the user picked in the
  dropdown (`input$eda_freq_n`). Because this is a `reactive` `input$` read inside `renderPlot`,
  Shiny automatically redraws the chart the instant the dropdown changes — no button click
  needed. The `%||%` operator (`app.R:53`, `if (is.null(a)) b else a`) supplies a fallback of 20
  if the input is ever `NULL`.

### Chart: "Top Products by Revenue" (with its own N dropdown)
- **Server:** `app.R:569-580` — identical pattern, reading `d$top_rev` (from
  `02_top50_items_by_revenue.csv`, produced by `R/02_eda.R:31-35`:
  `top_revenue <- retail |> group_by(Item) |> summarise(Revenue = sum(Revenue), Units = sum(Quantity))`),
  sliced to `input$eda_rev_n` rows.

### Chart: "Basket Size Distribution"
- **Server:** `app.R:582-594` — computed **live**, not from a CSV:
```r
bs <- d$retail %>% count(InvoiceNo, name = "BasketSize")
mn <- round(mean(bs$BasketSize), 1); md <- median(bs$BasketSize)
ggplot(bs, aes(BasketSize)) + geom_histogram(binwidth = 2, ...) +
  labs(subtitle = sprintf("Mean = %s items | Median = %d items | X-axis capped at 100", mn, md), ...)
```
- **Logic:** `count(InvoiceNo)` gives one row per basket with how many distinct products it has
  (`BasketSize`). The subtitle's "Mean = ... | Median = ..." numbers are computed on the spot
  with base R `mean()`/`median()` over that same live-counted vector — these are **not** read
  from `output/tables/02_basket_size_stats.csv` (that CSV, produced by `R/02_eda.R:61-70`,
  exists for the written report but isn't loaded by `app.R` at all).

### Image: "Relative Item Frequency"
- **UI:** `show_fig("07_item_frequency_relative.png", "100%")` — `app.R:209-210`
- **Upstream origin:** a **static PNG**, not a live chart. Produced by
  `R/03_apriori.R:33-39` using `arules::itemFrequencyPlot(trans, topN = PARAMS$top_n, type = "relative")`
  — this plots each item's **support** (fraction of baskets containing it), computed by `arules`
  directly off the `transactions` object, not off `retail_clean.rds`'s row counts. It is shown
  via `show_fig()` (`app.R:55-71`), which just serves the pre-rendered file over HTTP.

---

## Tab 3 — Rules

### Text block: "Rule Statistics"
- **Server:** `app.R:599-614` — **the only place in the whole app where summary numbers are
  computed live, at render time, directly off the loaded `arules` rule object** (rather than
  read from a pre-saved CSV):
```r
q <- quality(d$sig)
cat(sprintf("Total rules : %d\n", length(d$sig)))
cat(sprintf("Support     : %.4f – %.4f\n", min(q$support), max(q$support)))
cat(sprintf("Confidence  : %.3f – %.3f\n", min(q$confidence), max(q$confidence)))
cat(sprintf("Lift        : %.2f – %.2f\n", min(q$lift), max(q$lift)))
cat(sprintf("Mean lift   : %.2f\n", mean(q$lift)))
```
- **Logic:** `quality(d$sig)` extracts the support/confidence/lift vectors that `arules` stores
  alongside every rule in `rules_significant.rds`. `min()`/`max()`/`mean()` on those vectors give
  the ranges and mean lift shown. Since `d$sig` was loaded once at app startup and never changes,
  these numbers are constant for the life of the running app session, but they are *technically*
  recalculated (cheaply) every time this output re-renders.

### Static PNG: "How do rule counts react to threshold pairs?"
- **UI:** `show_fig("08_threshold_sensitivity.png", "100%")` — `app.R:221`
- **Upstream origin:** `R/03_apriori.R:142-163` — the 5×5 support×confidence grid search
  described in `THEORY.md` §5. Each of the 25 points on this chart is the `n_rules` result of an
  independent, full re-run of `arules::apriori()` at that support/confidence pair
  (`R/03_apriori.R:144-151`).

### Static PNG: "Top 20 Rules by Lift" (bar chart)
- **UI:** `show_fig("14_top_rules_by_lift_bars.png", "100%")` — `app.R:231`
- **Upstream origin:** `R/04_visualize_rules.R:66-83` — `head(sort(sig_rules, by="lift", decreasing=TRUE), PARAMS$top_n)`,
  i.e., the top 20 of the same 2,215-rule significant set, sorted by lift descending.

### Static PNG: "Rule Landscape: Support vs Confidence" (scatter)
- **UI:** `show_fig("09_rules_scatter.png", "100%")` — `app.R:234`
- **Upstream origin:** `R/04_visualize_rules.R:15-28` — one point per significant rule, x =
  `q$support`, y = `q$confidence`, colour = `q$lift`, where `q <- quality(sig_rules)`.

### Tables: "By Lift" / "By Confidence" / "By Support" / "All Rules"
- **Server:** `app.R:616-639`
```r
output$tab_lift <- renderDT({ datatable(d$rules_lift, ...) })   # 03_top_rules_by_lift.csv
output$tab_conf <- renderDT({ datatable(d$rules_conf, ...) })   # 03_top_rules_by_confidence.csv
output$tab_supp <- renderDT({ datatable(d$rules_supp, ...) })   # 03_top_rules_by_support.csv
output$tab_all  <- renderDT({ datatable(d$all_rules, ...) })    # 03_all_significant_rules.csv
```
- **Upstream origin:** all four CSVs are written by `R/03_apriori.R:125-133`, each one just the
  significant rule set converted to a data frame via `arules::DATAFRAME()` and sorted/sliced
  differently. **Every number in every cell of these four tables (support, confidence, lift,
  count) is computed by `arules::apriori()` itself and its `quality()` accessor** — the
  dashboard performs no arithmetic on them at all, only display formatting (column filters,
  pagination via `DT::datatable(..., filter = "top")`).

---

## Tab 4 — Explorer

### Filtered rules table
- **UI:** sliders/inputs `exp_min_lift`, `exp_min_conf`, `exp_min_supp`, `exp_max`,
  `exp_search`, button `exp_apply` — `app.R:253-261`
- **Server:** `app.R:644-678`
```r
observeEvent(input$exp_apply, {
  q <- quality(d$sig)
  keep <- q$lift >= min_lift & q$confidence >= min_conf & q$support >= min_supp
  filtered <- d$sig[keep]
  if (length(filtered) > max_r) filtered <- head(sort(filtered, by="lift", decreasing=TRUE), max_r)
  df <- arules::DATAFRAME(filtered, ...)
  if (nchar(search) > 0) {
    combined <- paste(df$Antecedent, df$Consequent)
    df <- df[grepl(search, combined, ignore.case = TRUE), ]
  }
  output$exp_table <- renderDT({ datatable(df, ...) })
}, ignoreNULL = FALSE)
```
- **Logic, exactly:** starts from the **full in-memory 2,215-rule object** (`d$sig`, the same
  object every other tab uses — no separate copy or file). Builds a logical `keep` vector by
  comparing each rule's own `lift`/`confidence`/`support` (from `quality()`) against the three
  slider values. Subsets the rule object down to just the kept rules (`d$sig[keep]`). If more
  than `max_r` (the "Max results" numeric input, default 300) remain, keeps only the top-lift
  ones up to that cap. Converts to a data frame, then (if a keyword was typed) keeps only rows
  where the combined Antecedent+Consequent text contains that keyword (case-insensitive). This
  entire block only executes when the **"Apply Filters" button is clicked** (`observeEvent` on
  `input$exp_apply`) — dragging a slider alone does not trigger recomputation, avoiding
  server load from continuous slider drag events.

### Static PNGs: "Association Network (Top 25 by Lift)" / "Parallel Coordinates (Top 20 by Confidence)"
- **UI:** `show_fig("11_rules_graph_top25_lift.png", ...)` (`app.R:268`), `show_fig("13_rules_paracoord.png", ...)` (`app.R:272`)
- **Upstream origin:** `R/04_visualize_rules.R:39-46` (`igraph`-engine network of
  `head(sort(sig_rules, by="lift", decreasing=TRUE), 25)`) and `R/04_visualize_rules.R:55-61`
  (`arulesViz` parallel-coordinates of `head(sort(sig_rules, by="confidence", decreasing=TRUE), 20)`)
  — both static, both pre-rendered offline, both fixed regardless of what the user does on the
  Explorer tab (the live filter above only affects the table, not these two images).

---

## Tab 5 — Segments

### KPI box: "UK Baskets"
- **Server:** `app.R:683-688`
```r
n_uk <- n_distinct(d$retail$InvoiceNo[d$retail$Country == "United Kingdom"])
valueBox(format(n_uk, big.mark = ","), "UK Baskets", ...)
```
- **Logic:** computed **live**, filtering `d$retail` (the full cleaned dataset) down to rows
  where `Country == "United Kingdom"`, then counting distinct invoices — not read from any
  segment CSV.

### KPI box: "International Baskets"
- **Server:** `app.R:689-694` — same pattern with `Country != "United Kingdom"`.

### KPI box: "UK Top Rules" / "Intl Top Rules"
- **Server:** `app.R:695-704`
```r
n <- if (nrow(d$uk_rules) > 0 && !"Note" %in% names(d$uk_rules)) nrow(d$uk_rules) else 0
valueBox(n, "UK Top Rules", ...)
```
- **Data source:** `d$uk_rules` / `d$intl_rules` ← `05_top_rules_uk.csv` /
  `05_top_rules_international.csv` (`app.R:447-448`).
- **Upstream origin:** these CSVs are written by `R/05_segments_and_recommendations.R:36-53` —
  Apriori re-mined **separately** on UK-only vs International-only baskets (UK at 1% support,
  International at a relaxed 2% support — see `THEORY.md` §7 for why), each capped to the top 25
  rules by lift via the local `to_df(r, n=25)` helper (`R/05_segments_and_recommendations.R:27-34`).
  The KPI number is simply `nrow()` of that already-capped CSV — i.e. it shows "how many top
  rules are in this table" (≤25), **not** the segment's total rule count (which is a different,
  larger number shown only in the summary table below).

### Table: "Segment Comparison Summary" + Chart: "UK vs International: Baskets & Rules"
- **Server:** `app.R:706-722`, reading `d$seg_comp` ← `05_segment_comparison.csv`
- **Upstream origin:** `R/05_segments_and_recommendations.R:56-69`:
  ```r
  seg_summary <- data.frame(
    Segment = names(seg_results), Baskets = sapply(..., function(x) length(x$trans)),
    Products = sapply(..., function(x) ncol(x$trans)), MinSupport = sapply(..., function(x) x$support),
    Rules = sapply(..., function(x) length(x$rules)),
    MeanLift = sapply(..., function(x) round(mean(quality(x$rules)$lift), 2)),
    MaxLift  = sapply(..., function(x) round(max(quality(x$rules)$lift), 2)))
  ```
  Every column here (`Baskets`, `Products`, `Rules`, `MeanLift`, `MaxLift`) is computed once per
  segment during that script's own independent Apriori re-mine — **this is the table with each
  segment's true total rule count**, unlike the KPI boxes above which only reflect the top-25 cap.
  The bar chart (`app.R:711-722`) just pivots this same table longer (`Rules`, `Baskets` columns
  → one `Metric`/`Value` pair per row) and plots it with `ggplot2`.

### Tables: "UK: Top Rules by Lift" / "International: Top Rules by Lift"
- **Server:** `app.R:724-734` — direct `datatable()` wraps of `d$uk_rules` / `d$intl_rules`, no
  further computation.

### Chart: "Festive vs Rest of Year" (bar)
- **Server:** `app.R:736-748`, reading `d$season_comp` ← `05_season_comparison.csv`
- **Upstream origin:** `R/05_segments_and_recommendations.R:71-96` — the same
  independent-re-mine pattern as the geographic segments, but splitting `retail` by
  `lubridate::month(Date) %in% c(9,10,11)` (Sep/Oct/Nov = "Pre-Christmas") vs everything else.

### Table: "Rules That Exist Only in the Festive Quarter"
- **Server:** `app.R:750-757`, reading `d$festive` ← `05_festive_only_rules.csv`
- **Upstream origin:** `R/05_segments_and_recommendations.R:99-103`:
  ```r
  only_fest <- rules_fest[!(labels(rules_fest) %in% labels(rules_rest))]
  ```
  A rule from the festive-quarter mining run is kept here only if its exact textual label
  (`{A,B} => {C}`) **never appears at all** in the rest-of-year rule set — i.e., these are rules
  that are not merely *stronger* in the festive quarter, but structurally **absent** the rest of
  the year.

---

## Tab 6 — Recommender

### The dropdown of items (`selectizeInput`)
- **Server:** `app.R:460-466`
```r
choices <- sort(unique(d$retail$Item))
updateSelectizeInput(session, "recom_items", choices = choices, server = TRUE)
```
- **Logic:** every distinct canonical product `Item` from `retail_clean.rds`, sorted
  alphabetically, searched server-side as the user types (so the browser never has to hold all
  3,765 names at once).

### The recommendation table (after clicking "Get Recommendations")
- **Server:** `app.R:772-830`, triggered by `observeEvent(input$recom_go, {...})`
```r
sig <- d$sig
LHS_LIST <- as(lhs(sig), "list")            # every rule's antecedent item-set, as a plain list
RHS_ITEM <- unlist(as(rhs(sig), "list"))    # every rule's single consequent item name
QUAL     <- quality(sig)                     # aligned support/confidence/lift vectors

basket <- input$recom_items                  # whatever the user picked in the dropdown

fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
rec <- data.frame(Recommendation = RHS_ITEM[fires],
                   Confidence = round(QUAL$confidence[fires], 3),
                   Lift       = round(QUAL$lift[fires], 2),
                   Support    = round(QUAL$support[fires], 4))
rec <- rec[!rec$Recommendation %in% basket, ]      # app.R:812 -- strip items already in the basket
rec <- rec[order(-rec$Lift), ]                      # app.R:819 -- sort by lift, highest first
rec <- rec[!duplicated(rec$Recommendation), ]       # app.R:820 -- keep only the best-lift rule per product
rec <- head(rec, 10)                                # app.R:821 -- cap at 10 rows
rec$Rank <- seq_len(nrow(rec))
```
- **Logic, in order:**
  1. `fires` is `TRUE` for every rule whose **entire antecedent** is a subset of the user's
     current basket (`all(l %in% basket)`) — a rule with antecedent `{A,B}` only fires if
     *both* A and B are already selected, not just one.
  2. Every firing rule contributes one candidate row: its consequent item, and that specific
     rule's own confidence/lift/support (read straight from `QUAL`, the same `quality()` vectors
     used everywhere else — no new computation, just indexing by `fires`).
  3. Candidates already in the basket are removed (recommending something the user already has
     would be useless).
  4. Sorted by `Lift` descending, then deduplicated by product name keeping only the
     **first** (= highest-lift, thanks to the prior sort) occurrence — so if five different
     rules all point at the same consequent, only that consequent's single best rule shows.
  5. Capped to the top 10 distinct recommended products.
- **Upstream origin of `d$sig` itself:** `data/processed/rules_significant.rds`, i.e. the same
  2,215-rule object from `R/03_apriori.R` used on every other tab — the Recommender does not use
  a separate or specially-trained rule set.

### "Sample Basket" buttons 1 / 2 / 3
- **Server:** `app.R:832-867`, e.g. Sample 1:
```r
observeEvent(input$recom_s1, {
  set.seed(7)
  ts <- d$trans; sz <- size(ts)
  cands <- names(ts)[sz >= 3 & sz <= 8]
  basket <- as(ts[[sample(cands, 1)]], "list")[[1]]
  updateSelectizeInput(session, "recom_items", selected = basket[1:min(5, length(basket))])
})
```
- **Logic:** `d$trans` is the `transactions` object from `transactions.rds`; `size(ts)` gives
  each basket's item count. `cands` restricts to real baskets with 3–8 items (small enough to be
  a sensible demo, big enough to fire some rules). `set.seed(7)` (Sample 1), `set.seed(42)`
  (Sample 2, `app.R:847`), `set.seed(99)` (Sample 3, `app.R:859`, using a 4–10 item size range
  instead) each fix R's random number generator to a specific starting point **before** calling
  `sample()`, so the "random" basket picked is actually the *same* one every single time that
  button is clicked, in any session — deterministic despite looking random. Only the basket's
  first 5 items are pre-filled into the dropdown.

### The three small info boxes ("Lift" / "Confidence" / "Support") and the formula table
- **Server:** `app.R:762-770` — static text, no computation:
```r
output$recom_metric_lift <- renderValueBox({ valueBox("Lift", "Measures rule strength", ...) })
output$recom_metric_conf <- renderValueBox({ valueBox("Confidence", "P(RHS | LHS)", ...) })
output$recom_metric_supp <- renderValueBox({ valueBox("Support", "P(LHS & RHS)", ...) })
```
- **UI table** (`app.R:359-367`) is also hard-coded HTML restating the three formulas — this is
  documentation embedded in the page, not a rendered output.

---

## Tab 7 — Cross-Sell

### KPI box: "Total Revenue Opportunity"
- **Server:** `app.R:872-883`
```r
total <- sum(d$cs_best$PotentialRevenue, na.rm = TRUE)
valueBox(paste0("GBP ", format(round(total), big.mark = ",")), "Total Revenue Opportunity", ...)
```
- **Data source:** `d$cs_best` ← `05_cross_sell_best_rule_per_product.csv` (`app.R:451`) —
  **the deduplicated file**, i.e. only the single best (highest-`PotentialRevenue`) rule kept per
  distinct consequent product.
- **Upstream origin:** `R/05_segments_and_recommendations.R:188-193` (the `slice_max` dedup
  described in `THEORY.md` §6). This is exactly why summing this particular file gives the
  ~GBP 1.02M figure quoted throughout the project's reports — the app is summing the same
  deduplicated column the pipeline itself flags as "the defensible headroom estimate" (compare
  the console message at `R/05_segments_and_recommendations.R:199-200`).

### KPI box: "Best Single Opportunity"
- **Server:** `app.R:885-896`
```r
top <- head(arrange(d$cs_best, desc(PotentialRevenue)), 1)
valueBox(paste0("GBP ", format(round(top$PotentialRevenue), big.mark = ",")), "Best Single Opportunity", ...)
```
- **Logic:** the single highest `PotentialRevenue` row in the deduplicated file — this is the
  `ROSES REGENCY TEACUP AND SAUCER ⇒ REGENCY CAKESTAND 3 TIER` rule discussed in `THEORY.md` §6
  (~GBP 24,625), traced there back to `MissedBaskets × Confidence × AvgPrice × AvgQty`.

### KPI box: "Average Lift"
- **Server:** `app.R:898-906`
```r
avg <- round(mean(d$cs_best$Lift, na.rm = TRUE), 1)
valueBox(paste0(avg, "x"), "Average Lift", ...)
```
- **Logic:** mean of the `Lift` column across every row of the deduplicated cross-sell file —
  **note this is a different population than the "Mean lift" shown on the Rules tab** (that one
  averages across all 2,215 significant rules; this one averages across only the ~one-per-product
  deduplicated subset that made the cross-sell file), so the two numbers are not expected to
  match.

### KPI box: "Products with Opportunity"
- **Server:** `app.R:908-916`
```r
valueBox(nrow(d$cs_best), "Products with Opportunity", ...)
```
- **Logic:** simply the row count of the deduplicated file — one row per distinct consequent
  product that has at least one qualifying rule pointing at it.

### Static PNG: "Top 15 Cross-Sell Opportunities by Estimated Revenue"
- **UI:** `show_fig("15_cross_sell_opportunity_value.png", "100%")` — `app.R:385`
- **Upstream origin:** `R/05_segments_and_recommendations.R:206-217` — `head(best_per_consequent, 15)`,
  i.e. the top 15 rows of the same deduplicated file, plotted as a horizontal bar chart coloured
  by `Lift`.

### Table: "All Cross-Sell Opportunities" (sortable, filterable)
- **UI:** `selectInput("cs_sort", ...)` (choices: PotentialRevenue/Lift/Confidence/MissedBaskets,
  `app.R:392-399`), `selectInput("cs_minlift", ...)` (choices: Any/1.5/2/3/5/10, `app.R:402-405`)
- **Server:** `app.R:918-948`
```r
df <- d$cs_best
if (min_lift_val > 0) df <- df[df$Lift >= min_lift_val, ]
if (sort_col %in% names(df)) df <- arrange(df, desc(.data[[sort_col]]))
if ("Rule" %in% names(df)) df$Rule <- ifelse(nchar(df$Rule) > 75, paste0(substr(df$Rule,1,72), "..."), df$Rule)
if ("Consequent" %in% names(df)) df$Consequent <- ifelse(nchar(df$Consequent) > 40, paste0(substr(df$Consequent,1,37), "..."), df$Consequent)
datatable(df, options = list(pageLength = 20, scrollX = TRUE), filter = "top", ...)
```
- **Logic:** starts from the deduplicated `d$cs_best`, optionally drops rows below the chosen
  minimum lift, sorts descending by whichever column the user picked, then truncates any
  overly-long `Rule`/`Consequent` text purely for table readability (this truncation is cosmetic
  only — it does not affect the underlying numeric columns `Support`, `Confidence`, `Lift`,
  `MissedBaskets`, `PotentialRevenue`, which are exactly as computed in
  `R/05_segments_and_recommendations.R:162-177`, see `THEORY.md` §6 for the full formula
  derivation of each).

---

## Cross-Cutting Notes

- **Two different rule "sizes" appear across the app and must not be confused:** `d$sig` (the
  full 2,215-rule `arules` object, used live on Rules/Explorer/Recommender) vs. the various
  pre-capped CSVs (`03_top_rules_by_lift.csv` etc., capped to `PARAMS$top_n = 20`;
  `05_top_rules_uk.csv` etc., capped to 25 via `to_df(r, n=25)`). A KPI reading `nrow()` of a
  capped file will never exceed that cap, even if the segment's true rule count is larger — the
  Segment Comparison Summary table (`05_segment_comparison.csv`) is the only place the *true*
  uncapped per-segment rule count is shown.
- **Every number that looks "live" in the Shiny session is still ultimately built from files the
  offline pipeline (`R/01`–`R/05`) already computed** — even the handful of truly-live
  computations (the Overview heatmap, the EDA basket-size histogram + its mean/median subtitle,
  the Rules-tab statistics text, the Explorer filter, and the Recommender matching) only ever
  operate on `d$retail`, `d$trans`, or `d$sig`, all three of which are `.rds` files read once at
  app startup (`app.R:427-434`) — no number on any tab is ever computed from the *raw* Excel
  file at dashboard runtime.
- **`Revenue`, `Item`, `Month`, `Hour`, `Weekday`** are the four columns that do the most work
  across the whole app — none of them exist in the raw dataset; all four are derived exactly
  once, during cleaning, in `R/01_load_clean.R` (`Revenue`/`Date`/`Month`/`Hour`/`Weekday` at
  lines 79-85; `Item` at lines 88-97). Every chart or KPI that mentions revenue, a product name,
  or a time period is ultimately reading one of these five derived columns from
  `retail_clean.rds`.
