# Basket Lens — Code Walkthrough (What Runs, What It Produces)

This file walks through **every script in the project, in run order**, explaining what the code
does in plain English, and — for each one — **exactly what you get if you run it**: which
messages print to the console, and which files land on disk. Formulas are only touched briefly
here (they're explained in full in `THEORY.md`); this file is about the *code*, not the math.
Where each on-screen dashboard number comes from is covered separately in `NUMBERS_TRACED.md`.

Run order (also encoded in `run_all.R`):
```
R/00_setup.R → R/01_load_clean.R → R/02_eda.R → R/03_apriori.R
   → R/04_visualize_rules.R → R/05_segments_and_recommendations.R → app.R (the dashboard, run separately)
```

---

## `run_all.R` — the one-button pipeline runner

```r
source("R/00_setup.R")
source("R/01_load_clean.R")
source("R/02_eda.R")
source("R/03_apriori.R")
source("R/04_visualize_rules.R")
source("R/05_segments_and_recommendations.R")
```
Running `Rscript run_all.R` (or `source("run_all.R")` in RStudio) executes the five stage
scripts back to back, each one reading the outputs the previous one saved. Measured runtime
(README): 01 ≈ 23s (mostly reading the Excel file), 02 ≈ 3s, 03 ≈ 9s, 04 ≈ 3s, 05 ≈ 11s — under
a minute total after the first run (the first run also downloads the 23MB dataset).

**If you run it, you get:** every file listed under `data/processed/` and `output/` in the
project layout, ready for `app.R` to read.

---

## `R/00_setup.R` — packages, paths, and the one shared config object

### What the code does
```r
required_packages <- c("readxl","dplyr","tidyr","lubridate","ggplot2","scales",
                        "RColorBrewer","arules","shiny","shinydashboard","shinyjs","DT","plotly")
missing <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing) > 0) install.packages(missing)
invisible(lapply(required_packages, library, character.only = TRUE))
```
Checks which of the 13 required packages are missing and installs only those, then loads all of
them. This means the *first* time anyone runs the project it may take a few minutes (package
compilation); every run after that is instant since nothing is missing.

```r
PROJ_ROOT <- getwd()
if (basename(PROJ_ROOT) == "R") PROJ_ROOT <- dirname(PROJ_ROOT)
DIR_RAW <- file.path(PROJ_ROOT, "data", "raw")
DIR_PROC <- file.path(PROJ_ROOT, "data", "processed")
DIR_FIG <- file.path(PROJ_ROOT, "output", "figures")
DIR_TAB <- file.path(PROJ_ROOT, "output", "tables")
for (d in c(DIR_RAW, DIR_PROC, DIR_FIG, DIR_TAB)) if (!dir.exists(d)) dir.create(d, recursive = TRUE)
```
Figures out the project root regardless of whether you're running from the project folder or
from inside `R/`, then creates the four working folders if they don't already exist — so the
pipeline never fails with a "directory not found" error on a fresh checkout.

```r
PARAMS <- list(support = 0.01, confidence = 0.30, minlen = 2, maxlen = 4,
               min_lift = 1.0, top_n = 20)
```
This is the single control panel for the entire analysis — every other script reads `PARAMS$...`
instead of hardcoding a number, so changing the whole study's strictness means editing this one
list.

Two small reusable helper functions are also defined here and used everywhere downstream:
```r
save_fig <- function(plot, name, width=9, height=6, dpi=150) {
  path <- file.path(DIR_FIG, paste0(name, ".png"))
  ggsave(path, plot, width=width, height=height, dpi=dpi, bg="white")
}
save_tab <- function(df, name) {
  path <- file.path(DIR_TAB, paste0(name, ".csv"))
  write.csv(df, path, row.names = FALSE)
}
```
Every chart in the project is written with `save_fig()` and every table with `save_tab()` — this
is why filenames are consistent (`output/figures/NAME.png`, `output/tables/NAME.csv`) across all
five scripts.

`set.seed(42)` at the very end makes anything "random" later in the pipeline (like the segment
sampling) reproducible.

### If you run it
No files are produced by this script alone (it just prepares the environment) — but every later
script starts with `source("R/00_setup.R")`, so its effects (packages loaded, `PARAMS`, folders,
`save_fig`/`save_tab`) are always in scope. Console output: a line per missing package being
installed (only on first run), and `"Setup complete. Project root: <path>"`.

---

## `R/01_load_clean.R` — download, audit, clean

### Step 1: Download (only if not already cached)
```r
if (!file.exists(xlsx_path)) {
  if (!file.exists(zip_path)) {
    download.file("https://archive.ics.uci.edu/static/public/352/online+retail.zip",
                  destfile = zip_path, mode = "wb")
  }
  unzip(zip_path, exdir = DIR_RAW)
}
raw <- readxl::read_excel(xlsx_path, sheet = 1,
                          col_types = c("text","text","text","numeric","date","numeric","text","text"))
names(raw) <- c("InvoiceNo","StockCode","Description","Quantity",
                "InvoiceDate","UnitPrice","CustomerID","Country")
```
Downloads the zip (skipped if already present), unzips it, then reads the Excel sheet, forcing
each column to the right type (`Quantity`/`UnitPrice` numeric, `InvoiceDate` a real date) so
nothing downstream trips over a column read as text.

### Step 2: Data quality audit
```r
audit <- data.frame(
  Check = c("Total rows","Missing Description","Missing CustomerID",
            "Cancelled invoices (InvoiceNo starts with 'C')","Quantity <= 0","UnitPrice <= 0",
            "Duplicate rows","Distinct invoices","Distinct stock codes","Distinct countries"),
  Value = c(nrow(raw), sum(is.na(raw$Description)), sum(is.na(raw$CustomerID)),
            sum(grepl("^C", raw$InvoiceNo)), sum(raw$Quantity <= 0, na.rm=TRUE),
            sum(raw$UnitPrice <= 0, na.rm=TRUE), sum(duplicated(raw)),
            dplyr::n_distinct(raw$InvoiceNo), dplyr::n_distinct(raw$StockCode),
            dplyr::n_distinct(raw$Country))
)
save_tab(audit, "01_data_quality_audit")
```
This is purely diagnostic — it just *counts* problems before fixing any of them, and saves that
count table so there's a documented "before" picture.

### Step 3: The cleaning chain
```r
retail <- raw |>
  dplyr::filter(!is.na(Description)) |>
  dplyr::filter(!grepl("^C", InvoiceNo)) |>
  dplyr::filter(Quantity > 0, UnitPrice > 0) |>
  dplyr::filter(!toupper(trimws(StockCode)) %in% toupper(admin_codes)) |>
  dplyr::mutate(Description = trimws(toupper(Description)), StockCode = trimws(toupper(StockCode))) |>
  dplyr::filter(!grepl(junk_desc, Description, perl = TRUE)) |>
  dplyr::filter(nchar(Description) > 2) |>
  dplyr::distinct(InvoiceNo, StockCode, .keep_all = TRUE) |>
  dplyr::mutate(
    Revenue = Quantity * UnitPrice,
    Date    = as.Date(InvoiceDate),
    Month   = lubridate::floor_date(Date, "month"),
    Hour    = lubridate::hour(InvoiceDate),
    Weekday = lubridate::wday(Date, label = TRUE, abbr = TRUE, week_start = 1)
  )
```
Each `filter()` in this R "pipe" (`|>`) chain removes one category of bad row, in order:
no-description rows, cancellations (`InvoiceNo` starting with `"C"`), non-positive
quantity/price, known admin/fee stock codes, then junk free-text descriptions matched by a
single regex (`junk_desc`, built from words like `damaged`, `found`, `test`, `wrongly`...), then
anything left with a 1-2 character description. `distinct(InvoiceNo, StockCode)` collapses
duplicate lines of the same product in the same basket down to one row. The final `mutate()`
computes `Revenue`, and pulls `Date`/`Month`/`Hour`/`Weekday` out of the raw timestamp — these
four derived columns are what the Overview/EDA tabs' time-based charts run on.

### Step 4: Canonical product names
```r
canonical <- retail |>
  dplyr::count(StockCode, Description, name = "n") |>
  dplyr::group_by(StockCode) |>
  dplyr::slice_max(n, n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::select(StockCode, Item = Description)

retail <- retail |> dplyr::left_join(canonical, by = "StockCode") |> dplyr::filter(!is.na(Item))
```
Counts, per `StockCode`, how many times each spelling of its `Description` occurs, keeps only
the single most-frequent spelling per code, then joins that canonical label back in as a new
column called `Item`. **`Item` — not `Description` — is the column used everywhere downstream**
(baskets, rules, the dashboard's product dropdown), because it guarantees one consistent name
per product.

### Step 5: Drop single-item baskets
```r
basket_sizes <- retail |> dplyr::count(InvoiceNo, name = "BasketSize")
retail <- retail |> dplyr::inner_join(dplyr::filter(basket_sizes, BasketSize >= 2), by = "InvoiceNo")
```
Counts how many distinct products are in each basket, then keeps only baskets with 2 or more —
a 1-item basket has nothing to "associate" with, so it would be dead weight for Apriori.

### Step 6: Report + save
```r
summary_tbl <- data.frame(Metric = c(...), Value = c(...))
save_tab(summary_tbl, "01_cleaning_summary")
saveRDS(retail, file.path(DIR_PROC, "retail_clean.rds"))
write.csv(retail[, c("InvoiceNo","StockCode","Item","Quantity","InvoiceDate",
                     "UnitPrice","CustomerID","Country","Revenue")],
          file.path(DIR_PROC, "retail_clean.csv"), row.names = FALSE)
```

### If you run it
- **Console:** prints the raw row/column count, the `audit` data frame, and the `summary_tbl`
  (rows retained, % retained, transaction/product/country counts, date range, mean/median basket
  size, total revenue).
- **Files written:** `output/tables/01_data_quality_audit.csv`, `output/tables/01_cleaning_summary.csv`,
  `data/processed/retail_clean.rds` (the R object almost everything else reads), and
  `data/processed/retail_clean.csv` (a plain-text copy of the same data).

---

## `R/02_eda.R` — exploring the cleaned data

Six independent blocks, each following the same pattern: **summarise `retail` → save a CSV →
build a `ggplot2` chart → save a PNG.**

1. **Top items by frequency** — `count(Item)` then divide by total baskets to get support,
   saved as `02_top50_items_by_frequency.csv`; top 20 plotted as `01_top_items_frequency.png`.
2. **Top items by revenue** — `group_by(Item) |> summarise(Revenue = sum(Revenue), Units = sum(Quantity))`,
   saved as `02_top50_items_by_revenue.csv`; top 20 plotted as `02_top_items_revenue.png`.
3. **Basket size distribution** — `count(InvoiceNo)` gives one row per basket with its size;
   a histogram capped at 100 items on the x-axis is saved as `03_basket_size_distribution.png`,
   and min/Q1/median/mean/Q3/P95/max are saved as `02_basket_size_stats.csv`.
4. **Monthly revenue** — `group_by(Month) |> summarise(Revenue = sum(Revenue), Transactions = n_distinct(InvoiceNo))`,
   saved as `02_monthly_sales.csv` and plotted as `04_monthly_revenue.png`.
5. **Trading rhythm** — `distinct(InvoiceNo, Weekday, Hour) |> count(Weekday, Hour)` (each basket
   counted once, at the hour its invoice was created) → heatmap PNG `05_weekday_hour_heatmap.png`.
6. **Geography** — `group_by(Country) |> summarise(Transactions, Revenue) |> mutate(RevenueShare = Revenue/sum(Revenue))`,
   saved as `02_by_country.csv`, top 10 plotted as `06_top_countries.png`.

### If you run it
- **Console:** just `"EDA complete."` at the end (no printed tables — everything goes straight
  to disk).
- **Files written:** 6 PNGs (`01`–`06` in `output/figures/`) and 4 CSVs
  (`02_top50_items_by_frequency.csv`, `02_top50_items_by_revenue.csv`, `02_basket_size_stats.csv`,
  `02_monthly_sales.csv`, `02_by_country.csv`).

---

## `R/03_apriori.R` — the actual data-mining stage

### Building the transaction object
```r
basket_list <- split(retail$Item, retail$InvoiceNo)
basket_list <- lapply(basket_list, unique)
trans <- as(basket_list, "transactions")
```
`split()` groups every row's `Item` by its `InvoiceNo`, giving one character vector per basket
(e.g. `c("MUG","PLATE","TEAPOT")`). `unique()` removes any leftover duplicate item names inside
a basket. `as(..., "transactions")` converts this plain R list into `arules`' special sparse
matrix format that the Apriori implementation actually operates on.

### Mining frequent itemsets, then rules
```r
itemsets <- arules::apriori(trans, parameter = list(support = PARAMS$support, minlen = 1,
                             maxlen = PARAMS$maxlen, target = "frequent itemsets"))
rules <- arules::apriori(trans, parameter = list(support = PARAMS$support,
                          confidence = PARAMS$confidence, minlen = PARAMS$minlen,
                          maxlen = PARAMS$maxlen, target = "rules"))
```
Two separate calls to the same `apriori()` function, distinguished only by `target`: the first
just finds *itemsets* (groups of items that co-occur often, no direction implied); the second
finds *rules* (`X ⇒ Y` with a direction and a confidence score). The itemsets run is mostly for
the Explorer/reporting side; the rules run is what everything downstream actually uses.

### Filtering the rules down
```r
rules <- subset(rules, lift > PARAMS$min_lift)
rules <- rules[!arules::is.redundant(rules)]
quality(rules)$fishersPValue <- arules::interestMeasure(rules, measure = "fishersExactTest", transactions = trans)
quality(rules)$pAdjusted <- p.adjust(quality(rules)$fishersPValue, method = "BH")
sig_rules <- subset(rules, pAdjusted < 0.05)
```
Four sequential filters, each shrinking the rule set: `lift > 1` (better than random), then
`!is.redundant()` (drop rules a simpler rule already explains just as well), then attach a
Fisher's-exact-test p-value to every single rule via `interestMeasure()`, adjust all those
p-values together with the Benjamini-Hochberg method (`p.adjust(..., method="BH")`), and finally
keep only rules whose adjusted p-value is below 0.05. What survives is saved as `sig_rules`.

### Exporting tables
```r
all_rules_df <- rules_to_df(sort(sig_rules, by = "lift", decreasing = TRUE))
save_tab(all_rules_df, "03_all_significant_rules")
save_tab(head(rules_to_df(sort(sig_rules, by="lift", decreasing=TRUE)), PARAMS$top_n), "03_top_rules_by_lift")
save_tab(head(rules_to_df(sort(sig_rules, by="confidence", decreasing=TRUE)), PARAMS$top_n), "03_top_rules_by_confidence")
save_tab(head(rules_to_df(sort(sig_rules, by="support", decreasing=TRUE)), PARAMS$top_n), "03_top_rules_by_support")
```
`rules_to_df()` is a small local helper (defined just above) that converts an `arules` rule
object into a normal data frame with columns `Antecedent_LHS`, `Consequent_RHS`, `support`,
`confidence`, `lift`, etc., rounded to 5 decimal places, so it can be written to CSV. The same
full significant-rule set is exported once in full, then three more times as "top 20" slices
sorted by each of the three measures.

### Threshold sensitivity grid
```r
grid <- expand.grid(support = c(0.005,0.0075,0.01,0.015,0.02), confidence = c(0.2,0.3,0.4,0.5,0.6))
grid$n_rules <- mapply(function(s, c_) {
  r <- suppressWarnings(arules::apriori(trans, parameter = list(support=s, confidence=c_, minlen=2, maxlen=PARAMS$maxlen)))
  length(r)
}, grid$support, grid$confidence)
save_tab(grid, "03_threshold_sensitivity")
```
`expand.grid()` builds all 25 combinations of 5 support values × 5 confidence values.
`mapply()` re-runs `apriori()` once per combination (25 full re-mines!) and just records how
many rules came out each time — this is what powers the "how sensitive are the results to the
thresholds" chart.

### If you run it
- **Console:** the transaction object summary (number of transactions, item labels, density),
  the frequent-itemset size table, rule counts at each filtering stage ("Rules generated: ...",
  "Rules with lift > 1: ...", "Rules after removing redundant ones: ...", "Statistically
  significant rules (BH-adjusted p < 0.05): ..."), and the top-10 rules by lift and by
  confidence printed via `arules::inspect()`.
- **Files written:** `output/tables/03_transactions_summary.txt`,
  `output/figures/07_item_frequency_relative.png`,
  `output/tables/03_frequent_itemset_counts.csv`, `03_top30_frequent_itemsets.csv`,
  `03_top_multi_item_itemsets.csv`, `03_all_significant_rules.csv`,
  `03_top_rules_by_lift.csv`, `03_top_rules_by_confidence.csv`, `03_top_rules_by_support.csv`,
  `03_threshold_sensitivity.csv`, `output/figures/08_threshold_sensitivity.png`, and the four
  R objects `data/processed/transactions.rds`, `rules.rds`, `rules_significant.rds`,
  `itemsets.rds` — **the last three of these are what `app.R` loads directly.**

---

## `R/04_visualize_rules.R` — turning rules into pictures

### Scatter plot (support vs confidence, coloured by lift)
```r
scatter_df <- data.frame(support = q$support, confidence = q$confidence, lift = q$lift)
p1 <- ggplot(scatter_df, aes(support, confidence, colour = lift)) + geom_point(alpha=0.65, size=2) + ...
save_fig(p1, "09_rules_scatter")
```
Plain `ggplot2` — one dot per significant rule, positioned by its own support/confidence, tinted
by its lift on a Spectral colour scale.

### arulesViz plots (guarded by a package check)
```r
if (requireNamespace("arulesViz", quietly = TRUE)) {
  plot(sig_rules, method = "two-key plot", ...)                              # 10_rules_two_key.png
  top_lift <- head(sort(sig_rules, by="lift", decreasing=TRUE), 25)
  plot(top_lift, method = "graph", control = list(...), engine = "igraph")   # 11_rules_graph_top25_lift.png
  plot(sig_rules, method = "grouped", control = list(k = 15, ...))           # 12_rules_grouped_matrix.png
  plot(head(sort(sig_rules, by="confidence", decreasing=TRUE), 20),
       method = "paracoord", control = list(reorder = TRUE, ...))            # 13_rules_paracoord.png
}
```
Four different `arulesViz` plot "methods" applied to the rule object, each wrapped in
`png(...); plot(...); dev.off()` to write directly to a PNG file rather than showing on screen.
If `arulesViz` isn't installed, this whole block is skipped with a message and any previously
generated PNGs are simply left untouched — the pipeline doesn't hard-fail.

### Bar chart of top rules by lift
```r
top_df <- arules::DATAFRAME(head(sort(sig_rules, by="lift", decreasing=TRUE), PARAMS$top_n), ...)
top_df$Rule <- paste(top_df$LHS, "=>", top_df$RHS)
p6 <- ggplot(top_df, aes(reorder(Rule, lift), lift, fill = confidence)) + geom_col() + coord_flip() + ...
save_fig(p6, "14_top_rules_by_lift_bars", width = 11, height = 7)
```

### Targeted mining around the single bestselling product
```r
freq <- sort(itemFrequency(trans), decreasing = TRUE)
target <- names(freq)[1]
rules_to_target <- arules::apriori(trans, parameter = list(support=0.005, confidence=0.4, minlen=2, maxlen=3),
                                    appearance = list(rhs = target, default = "lhs"))
rules_from_target <- arules::apriori(trans, parameter = list(support=0.005, confidence=0.4, minlen=2, maxlen=3),
                                      appearance = list(lhs = target, default = "rhs"))
```
`itemFrequency()` gives the support of every single item; the highest one is the bestseller
(`"WHITE HANGING HEART T-LIGHT HOLDER"`). Two *fresh* Apriori runs are done with the
`appearance` argument constrained: the first forces the target item to always be on the RHS
("what leads customers *to* buy it"), the second forces it onto the LHS ("what do they buy
*after* it"). These are separate, looser-threshold mini-analyses — not filtered from
`sig_rules` — because the general 1%-support rule set may not contain enough rules specific to
one single product.

### If you run it
- **Console:** `"Visualising N significant rules."`, then (if a target-item rule exists)
  `arules::inspect()` printouts of the top rules leading to and from the bestselling item.
- **Files written:** `09_rules_scatter.png`, `10_rules_two_key.png`,
  `11_rules_graph_top25_lift.png`, `12_rules_grouped_matrix.png`, `13_rules_paracoord.png`,
  `14_top_rules_by_lift_bars.png`, and `output/tables/04_rules_leading_to_top_item.csv` (+
  `04_rules_from_top_item.csv` if any such rules were found).

---

## `R/05_segments_and_recommendations.R` — business layer

### Reusable local functions
```r
make_trans <- function(df) {
  bl <- lapply(split(df$Item, df$InvoiceNo), unique)
  bl <- bl[lengths(bl) >= 2]
  as(bl, "transactions")
}
mine <- function(tr, support = PARAMS$support, confidence = PARAMS$confidence) {
  r <- arules::apriori(tr, parameter = list(support=support, confidence=confidence, minlen=2, maxlen=PARAMS$maxlen))
  r <- subset(r, lift > 1)
  r[!arules::is.redundant(r)]
}
```
`make_trans()` repeats the same basket-building + "drop single-item baskets" logic from
`01_load_clean.R`/`03_apriori.R`, but scoped to whatever subset of `retail` is passed in.
`mine()` repeats the lift-filter + redundancy-removal steps from `03_apriori.R` (minus the
Fisher/BH significance testing — this script only reruns those two basic filters for speed,
since it's re-mining the algorithm multiple times on different slices of data).

### Geographic segments
```r
retail$Segment <- ifelse(retail$Country == "United Kingdom", "UK", "International")
for (s in c("UK", "International")) {
  d <- dplyr::filter(retail, Segment == s)
  tr <- make_trans(d)
  sup <- if (s == "UK") PARAMS$support else 0.02
  r <- mine(tr, support = sup)
  seg_results[[s]] <- list(trans = tr, rules = r, support = sup)
  if (length(r) > 0) save_tab(to_df(r), paste0("05_top_rules_", tolower(s)))
}
```
Splits the whole cleaned dataset into UK vs everything-else, rebuilds a *separate* transaction
object for each, and re-mines Apriori independently on each — International uses a relaxed 2%
support threshold (`sup <- 0.02`) because with far fewer baskets, 1% support would be too strict
to find anything. `seg_summary` (saved as `05_segment_comparison.csv`) then tabulates basket
count, product count, the support threshold actually used, rule count, mean lift, and max lift
per segment.

### Seasonal segments
```r
retail$Season <- ifelse(lubridate::month(retail$Date) %in% c(9,10,11), "Pre-Christmas (Sep-Nov)", "Rest of year")
for (s in c("Pre-Christmas (Sep-Nov)", "Rest of year")) {
  d <- dplyr::filter(retail, Season == s)
  tr <- make_trans(d); r <- mine(tr)
  ...
}
only_fest <- rules_fest[!(labels(rules_fest) %in% labels(rules_rest))]
```
Same pattern, split by calendar month instead of country. `only_fest` uses `labels()` (the
rule's text representation, e.g. `"{A,B} => {C}"`) to find rules that exist in the festive rule
set but whose exact label never appears in the rest-of-year rule set — i.e., genuinely
seasonal, not just "also present but weaker."

### The recommender function (research-script version)
```r
recommend <- function(basket, n = 5) {
  fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
  if (!any(fires)) return(data.frame())
  out <- data.frame(Recommendation = RHS_ITEM[fires], Confidence = round(QUAL$confidence[fires],3),
                    Lift = round(QUAL$lift[fires],2), Support = round(QUAL$support[fires],4))
  out <- out[!out$Recommendation %in% basket, , drop = FALSE]
  out <- out[order(-out$Lift), ]
  out <- out[!duplicated(out$Recommendation), ]
  head(out, n)
}
```
This is identical logic to what's baked into `app.R`'s Recommender tab (see `CODE_EXPLAINED.md`
→ dashboard section below, or `NUMBERS_TRACED.md`). Here it's demoed on 3 randomly-picked real
baskets (`set.seed(7)`, baskets with 3–8 items), and the demo output is saved as
`05_recommender_demo.csv`.

### The cross-sell revenue calculation
```r
price <- retail |> dplyr::group_by(Item) |> dplyr::summarise(AvgPrice = mean(UnitPrice), AvgQty = mean(Quantity))
N <- length(trans); q <- quality(rules_all)
value_df <- data.frame(
  Rule = labels(rules_all), Consequent = unlist(as(rhs(rules_all), "list")),
  Support = round(q$support,5), Confidence = round(q$confidence,3), Lift = round(q$lift,2),
  MissedBaskets = round((q$coverage - q$support) * N)
) |>
  dplyr::left_join(price, by = c("Consequent" = "Item")) |>
  dplyr::mutate(
    ExpectedUplift = MissedBaskets * Confidence,
    PotentialRevenue = round(ExpectedUplift * AvgPrice * AvgQty, 2),
    ExpectedUplift = round(ExpectedUplift)
  ) |>
  dplyr::arrange(dplyr::desc(PotentialRevenue))
save_tab(value_df, "05_cross_sell_opportunity_value")

best_per_consequent <- value_df |> dplyr::group_by(Consequent) |>
  dplyr::slice_max(PotentialRevenue, n = 1, with_ties = FALSE) |> dplyr::ungroup() |>
  dplyr::arrange(dplyr::desc(PotentialRevenue))
save_tab(best_per_consequent, "05_cross_sell_best_rule_per_product")
```
`price` computes each product's average unit price and average line quantity across the whole
cleaned dataset. `q$coverage` (a quantity `arules` computes automatically) is the antecedent's
own support — `q$coverage - q$support` isolates "baskets that had the LHS but not the RHS."
Multiplying by `N` (total basket count) converts that fraction into an actual basket count
(`MissedBaskets`). The rest is the formula from `THEORY.md` §5 applied row-by-row across every
significant rule. `best_per_consequent` then deduplicates by keeping only the single
highest-revenue rule per distinct consequent product, to avoid double-counting the same missed
basket across multiple overlapping rules.

### If you run it
- **Console:** per-segment and per-season basket/rule/support printouts, the printed
  `seg_summary`/`season_df` tables, `"Rules that appear only in the festive quarter: N"`, three
  demo-basket recommendation printouts, the top-10 cross-sell opportunities table, and three
  summary lines comparing the naive (double-counted) sum, the defensible best-per-product sum,
  and what fraction of that the top 20 products represent.
- **Files written:** `05_top_rules_uk.csv`, `05_top_rules_international.csv`,
  `05_segment_comparison.csv`, `05_top_rules_prechristmas.csv`, `05_top_rules_restofyear.csv`,
  `05_season_comparison.csv`, `05_festive_only_rules.csv`, `05_recommender_demo.csv`,
  `05_cross_sell_opportunity_value.csv`, `05_cross_sell_best_rule_per_product.csv`, and
  `output/figures/15_cross_sell_opportunity_value.png`.

---

## `app.R` — the dashboard (what running `shiny::runApp()` gives you)

`app.R` is not part of the `01`→`05` pipeline — you run it *after* the pipeline, with
`shiny::runApp("app.R")` (or the "Run App" button in RStudio). Running it does **not** touch the
raw data or re-run Apriori; it only reads the files the pipeline already produced. The full
tab-by-tab code breakdown (which output block computes which number, with line numbers) lives in
`NUMBERS_TRACED.md` — this section only explains the app's *own* internal machinery.

### Startup sequence
```r
options(shiny.autoload.r = FALSE)
library(shiny); library(shinydashboard); library(DT); library(dplyr); library(ggplot2)
library(scales); library(tidyr); library(arules)
PROJ_ROOT <- ifelse(basename(getwd()) == "R", dirname(getwd()), getwd())
DIR_PROC <- file.path(PROJ_ROOT, "data", "processed")
DIR_FIG <- file.path(PROJ_ROOT, "output", "figures")
DIR_TAB <- file.path(PROJ_ROOT, "output", "tables")
shiny::addResourcePath("figures", DIR_FIG)
```
Loads the packages the *app itself* needs (a subset of the pipeline's package list, plus `DT`),
resolves the project root the same way `00_setup.R` does, and registers `DIR_FIG` as an HTTP
resource path called `"figures"` — this is what lets `<img src="figures/xyz.png">` tags in the
UI actually resolve to files on disk when Shiny serves the page.

### The two safety helpers
```r
show_fig <- function(name, width = "100%") {
  img_path <- file.path(DIR_FIG, name)
  if (file.exists(img_path)) tags$div(..., tags$img(src = paste0("figures/", name), ...))
  else div(..., paste("Figure", name, "not found. Run the pipeline first."))
}
load_csv <- function(name) {
  path <- file.path(DIR_TAB, name)
  if (file.exists(path)) read.csv(path, stringsAsFactors = FALSE)
  else data.frame(Note = paste(name, "not found."))
}
```
Every single figure and table on every tab goes through one of these two functions. If you open
the dashboard *before* running the pipeline, nothing crashes — you just see "Figure ... not
found" placeholders and "not found" notes in the tables instead of a red error screen.

### Loading everything once, into one shared object
```r
data_store <- reactiveVal(NULL)
observe({
  d <- list()
  d$retail <- readRDS(file.path(DIR_PROC, "retail_clean.rds"))
  d$trans  <- readRDS(file.path(DIR_PROC, "transactions.rds"))
  d$sig    <- readRDS(file.path(DIR_PROC, "rules_significant.rds"))
  d$all_rules <- load_csv("03_all_significant_rules.csv")
  ... # ~17 more load_csv() calls
  data_store(d)
})
D <- reactive({ data_store() })
```
This `observe()` block runs exactly once, when the app starts, and loads every `.rds`/`.csv`
file the dashboard needs into one list `d`, stored in the reactive value `data_store`. Every
`output$...` block elsewhere in the server just calls `d <- D()` to grab this already-loaded
bundle instead of re-reading files from disk on every render — this is the main reason the app
feels instant once it's open.

### Populating the Recommender's item dropdown
```r
observe({
  d <- D()
  if (!is.null(d$retail) && ncol(d$retail) > 0) {
    choices <- sort(unique(d$retail$Item))
    updateSelectizeInput(session, "recom_items", choices = choices, server = TRUE)
  }
})
```
`server = TRUE` tells `selectize.js` to search server-side rather than shipping all 3,765
product names to the browser upfront — as the user types, R filters and sends back matches.

### The reactive rendering pattern (used ~30 times)
Nearly every `output$xyz <- renderPlot({...})` / `renderDT({...})` / `renderValueBox({...})`
block follows the same three-line shape:
```r
output$ov_baskets <- renderValueBox({
  d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
  valueBox(format(n_distinct(d$retail$InvoiceNo), big.mark=","), "Baskets", icon=icon("shopping-basket"), color="blue")
})
```
Grab the shared data (`d <- D()`), bail out safely with `NULL` if it's missing, then compute and
return the thing to display. Because `D()` is reactive, Shiny automatically knows every one of
these ~30 outputs depends on `data_store`, and will re-render them all if it ever changes (in
practice it's set once at startup and never changes again in this app).

### If you run it
Opens a local web server (default `http://127.0.0.1:PORT`) serving the 7-tab dashboard described
tab-by-tab in `NUMBERS_TRACED.md`. Nothing is written to disk by running the app — it is purely
a read + display layer, except for the transient in-memory filtering done by the Explorer,
Recommender, and Cross-Sell tabs' interactive controls.
