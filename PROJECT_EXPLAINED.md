# Basket Lens — How This Project Actually Works (Plain-English Deep Dive)

This document explains the whole project in simple terms, file by file, formula by formula,
and then walks through the **Shiny dashboard** ("Basket Lens") tab by tab — what each number on
screen is, which file computed it, and the exact lines of code that put it on the page.

---

## 1. What This Project Is, In One Paragraph

Imagine an online gift shop. Every time someone checks out, they buy a handful of products
together — that's a "basket." This project looks at **541,909 rows** of real checkout data from
a UK giftware retailer (1 Dec 2010 – 9 Dec 2011), cleans it down to **515,784 usable rows**
across **18,273 baskets** and **3,765 products**, and then asks one question over and over:

> *"If a customer already has product A (and maybe B) in their basket, what else are they
> statistically likely to buy?"*

The answer comes from an algorithm called **Apriori**, which produces **"association rules"**
like `{HERB MARKER MINT, HERB MARKER PARSLEY} => {HERB MARKER CHIVES}`. Each rule is scored by
three numbers (support, confidence, lift — explained in detail in §4). After filtering out weak
and statistically-insignificant rules, **2,215 rules** survive. Those rules are then:

- Displayed as sortable tables and charts,
- Turned into a live "type your basket, get recommendations" tool, and
- Converted into a cash number: **≈ GBP 1.02 million** of missed cross-sell revenue.

All of this is packaged into a 7-tab web dashboard built with **R Shiny**, called **Basket Lens**.

---

## 2. File-by-File Guide

```
DWDM/
├── DWDM.Rproj                    RStudio project file (just sets the working directory)
├── run_all.R                     Runs all 5 pipeline scripts in order, end to end
├── app.R                         THE SHINY DASHBOARD — the entire frontend + server logic (953 lines, single file)
├── R/
│   ├── 00_setup.R                Installs packages, defines PARAMS (the tunable thresholds), paths, plot theme
│   ├── 01_load_clean.R           Downloads the Excel file, audits it, cleans it → retail_clean.rds
│   ├── 02_eda.R                  Exploratory charts & tables (top products, basket sizes, revenue over time...)
│   ├── 03_apriori.R              Runs the actual Apriori algorithm, statistical testing, exports the 2,215 rules
│   ├── 04_visualize_rules.R      Draws the rule-network graph, scatter plot, parallel coordinates, etc.
│   └── 05_segments_and_recommendations.R
│                                 UK vs International, festive vs rest-of-year, the recommender function,
│                                 and the GBP revenue-opportunity calculation
├── data/
│   ├── raw/Online Retail.xlsx    The original downloaded dataset (23 MB, not committed to git)
│   └── processed/                Cleaned data + R objects that app.R reads directly (.rds files)
├── output/
│   ├── figures/                  15 pre-rendered PNG charts that app.R displays as static images
│   └── tables/                   ~28 CSV files that app.R reads into interactive tables
└── report/MBA_Report.Rmd         A separate knittable R Markdown report (not the dashboard)
```

**Key idea:** `app.R` (the dashboard) never touches the raw data and never runs Apriori itself.
It only *reads* the finished `.rds` and `.csv` files that scripts `01`–`05` already produced.
That's why the dashboard opens in seconds instead of minutes — see §6 "Data Flow."

---

## 3. The Data Pipeline, Step by Step (with formulas as they appear)

### `R/00_setup.R` — the control panel
Every tunable number in the whole project lives in one list, so changing the analysis means
editing one place:

```r
PARAMS <- list(
  support     = 0.01,   # 1% of baskets -- ~200 baskets at ~19.8k transactions
  confidence  = 0.30,   # 30% conditional probability
  minlen      = 2,      # rules must have >= 1 item on each side
  maxlen      = 4,      # keep itemsets interpretable
  min_lift    = 1.0,    # only rules better than chance
  top_n       = 20      # how many rules/items to report in tables & plots
)
```
*(`R/00_setup.R:49-56`)*

### `R/01_load_clean.R` — turning messy checkout data into usable baskets
1. Downloads `Online Retail.xlsx` from the UCI Machine Learning Repository if it isn't cached
   locally (`R/01_load_clean.R:12-19`).
2. Runs a **data-quality audit** — counts missing descriptions, cancelled invoices, non-positive
   quantities/prices, duplicates, etc. (`R/01_load_clean.R:31-54`), saved to
   `output/tables/01_data_quality_audit.csv`.
3. **Cleans** the data with a chain of filters (`R/01_load_clean.R:67-85`):
   - Drop rows with no product description.
   - Drop cancelled invoices (`InvoiceNo` starting with `"C"`).
   - Drop `Quantity <= 0` or `UnitPrice <= 0` (returns/free items/errors).
   - Drop admin/fee stock codes (`POST`, `DOT`, `BANK CHARGES`, `AMAZONFEE`, gift-card codes...).
   - Drop junk warehouse notes ("damaged", "found", "test", "wrongly"...) using a regex.
   - Keep one row per product per basket (`dplyr::distinct`).
   - Compute `Revenue = Quantity * UnitPrice`, plus `Date`, `Month`, `Hour`, `Weekday`.
4. **Canonicalises product names** — the same `StockCode` can have several spellings of its
   description across rows, so it picks the single most common description per code
   (`R/01_load_clean.R:88-97`).
5. **Drops single-item baskets** — a basket with 1 item can't teach the algorithm anything about
   co-occurrence, so it's removed (`R/01_load_clean.R:99-102`).
6. Saves the result to `data/processed/retail_clean.rds` — **this is the single most-used file
   in the whole project**; almost every number in the dashboard traces back to it.

### `R/02_eda.R` — exploratory analysis
Computes and saves (as CSV + PNG) the things you see on the **Overview** and **Exploratory**
tabs: top products by basket frequency, top products by revenue, basket-size distribution,
monthly revenue, the weekday×hour trading heatmap, and revenue by country.

### `R/03_apriori.R` — the actual data-mining step
This is where Apriori runs. Walked through in full in §4 below.

### `R/04_visualize_rules.R` — turning rules into pictures
Generates the rule-quality scatter plot, the association network graph (via `arulesViz`,
`igraph` engine), the grouped matrix, and the parallel-coordinates plot. Also runs two
"targeted" Apriori queries restricted to the single most frequent product (what leads
customers *to* it, and what they buy *after* it).

### `R/05_segments_and_recommendations.R` — turns rules into business answers
Three things happen here:
1. **Segment mining** — re-runs Apriori separately on UK-only and International-only baskets.
2. **Season mining** — re-runs Apriori separately on the Sep–Nov "festive quarter" vs the rest
   of the year, and finds rules that exist *only* in the festive quarter.
3. **The recommender function** and the **cross-sell revenue formula** (§4.4 below) — these are
   literally copy-pasted logic that also appears live inside `app.R`'s server code.

---

## 4. The Formulas

### 4.1 Support, Confidence, Lift — the three core measures

| Measure | Formula | Meaning in plain terms |
|---|---|---|
| **Support** | `support(X) = P(X)` — fraction of all baskets containing itemset X | How common the pattern is. Support of 0.01 = the itemset appears in 1% of all 18,273 baskets (~183 baskets). |
| **Confidence** | `confidence(X⇒Y) = support(X ∪ Y) / support(X)` = `P(Y\|X)` | Of all the baskets that had X, what fraction also had Y? If confidence = 0.86, 86% of baskets with X also had Y. |
| **Lift** | `lift(X⇒Y) = confidence(X⇒Y) / support(Y)` | How many times more likely Y is, *given* X, compared to Y appearing at random. Lift = 1 → no relationship. Lift = 75 → 75× more likely than chance. |

These are documented in the code comments at the very top of `R/03_apriori.R:5-9`:
```r
#   support(X)      = P(X)                  how often the itemset appears
#   confidence(X=>Y)= P(Y|X) = supp(XuY)/supp(X)
#   lift(X=>Y)      = conf / supp(Y)        > 1 means positively associated
#   Apriori property: every subset of a frequent itemset is itself frequent,
#                     which is what lets the algorithm prune the search space.
```

**Why lift matters most:** confidence alone is misleading because any rule that points at a
very popular product (like the top-seller, in ~12% of all baskets) will score high on confidence
just by coincidence. Lift corrects for that by comparing against how often the item shows up
*on its own*.

### 4.2 How Apriori actually runs (`R/03_apriori.R:17-99`)

1. **Build the transaction object.** Each basket (`InvoiceNo`) becomes one list of unique
   product names:
   ```r
   basket_list <- split(retail$Item, retail$InvoiceNo)
   basket_list <- lapply(basket_list, unique)
   trans <- as(basket_list, "transactions")
   ```
2. **Phase 1 — frequent itemsets.** `arules::apriori(..., target = "frequent itemsets")` finds
   every combination of items that appears in ≥1% of baskets (`support = PARAMS$support`).
   The **Apriori property** (every subset of a frequent itemset is itself frequent) is what lets
   the algorithm skip checking huge numbers of impossible combinations — this is what makes it
   fast even with 3,765 distinct products.
3. **Phase 2 — rules.** `arules::apriori(..., target = "rules")` re-runs with a confidence
   threshold (30%) added, producing `{A,B} => {C}`-style rules, keeping between 2 and 4 items
   total per rule (`minlen`/`maxlen`).
4. **Filter 1 — lift.** `rules <- subset(rules, lift > PARAMS$min_lift)` throws out anything at
   or below random chance.
5. **Filter 2 — redundancy.** `rules[!arules::is.redundant(rules)]` — if a simpler, more general
   rule already explains the pattern just as well, the more complicated version is dropped.
6. **Filter 3 — statistical significance.** For every rule, a **Fisher's Exact Test** is run on
   its 2×2 contingency table (does X really co-occur with Y more than chance would predict), then
   a **Benjamini–Hochberg (BH) correction** adjusts every rule's p-value to control the false
   discovery rate across thousands of simultaneous tests:
   ```r
   quality(rules)$fishersPValue <- arules::interestMeasure(
     rules, measure = "fishersExactTest", transactions = trans)
   quality(rules)$pAdjusted <- p.adjust(quality(rules)$fishersPValue, method = "BH")
   sig_rules <- subset(rules, pAdjusted < 0.05)
   ```
   *(`R/03_apriori.R:104-107`)* — only rules with adjusted p < 0.05 survive. This drops the count
   from ~3,500 redundancy-filtered rules down to the final **2,215**.

The funnel, from the project report: **~25,000+ raw rules → ~5,000+ after lift filter →
~3,500+ after redundancy removal → 2,215 final significant rules.**

### 4.3 Threshold sensitivity (`R/03_apriori.R:142-152`)
A 5×5 grid of `support × confidence` values is tested, re-running `apriori()` 25 times and
counting how many rules survive each combination. This produces `output/tables/03_threshold_sensitivity.csv`,
which feeds the "Rules" tab's sensitivity chart. It shows rule count falls off almost
geometrically as support increases — support is by far the most sensitive parameter.

### 4.4 The recommender-matching logic
Given a partial basket (a list of items the user picked), a rule "fires" if **every item in its
antecedent (LHS) is already in the basket**:
```r
fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
```
Every rule that fires contributes its consequent (RHS) as a candidate recommendation. Candidates
that are already in the basket are removed, duplicates are collapsed (keeping the
highest-lift version), and the list is sorted by lift, descending. This exact logic exists in
**two places**: the original research script (`R/05_segments_and_recommendations.R:113-125`,
function `recommend()`) and live inside the dashboard's server code
(`app.R:772-830`, the `recom_go` handler) — see §6, Tab 6.

### 4.5 The cross-sell revenue formula (`R/05_segments_and_recommendations.R:148-193`)

For every rule `X ⇒ Y`, the question is: *how much money is left on the table because baskets
that had X did not also get Y?* No new basket scan is needed — it falls straight out of two
numbers arules already computed:

```
MissedBaskets     = (coverage(X) − support(X∪Y)) × TotalBaskets
                     # coverage(X) = support(X), i.e. how many baskets had X at all;
                     # subtracting support(X∪Y) leaves baskets that had X but NOT Y.

ExpectedUplift    = MissedBaskets × Confidence(X⇒Y)
                     # if we assume prompting the rule converts at the rule's own confidence rate

PotentialRevenue  = ExpectedUplift × AvgPrice(Y) × AvgQty(Y)
                     # priced using product Y's historical average unit price and quantity per line
```

In code:
```r
MissedBaskets = round((q$coverage - q$support) * N)
...
ExpectedUplift   = MissedBaskets * Confidence,
PotentialRevenue = round(ExpectedUplift * AvgPrice * AvgQty, 2),
```
*(`R/05_segments_and_recommendations.R:168,173-175`)*

Because thousands of rules share the same consequent and fire on overlapping baskets, **simply
summing `PotentialRevenue` across every rule double-counts** the same missed basket many times
over. To fix this, the script keeps only **the single best (highest-revenue) rule per
consequent product**:
```r
best_per_consequent <- value_df |>
  dplyr::group_by(Consequent) |>
  dplyr::slice_max(PotentialRevenue, n = 1, with_ties = FALSE) |>
  ...
```
*(`R/05_segments_and_recommendations.R:188-192`)*, saved as
`output/tables/05_cross_sell_best_rule_per_product.csv`. **This deduplicated file — not the raw
2,215-rule file — is what the dashboard's "Cross-Sell" tab actually loads and sums**, which is
why the total on-screen (GBP 1.02M) is the *defensible* number, not the inflated double-counted
one.

---

## 5. How the R Shiny Frontend Was Built

### 5.1 Why Shiny / shinydashboard
`app.R` (`app.R:8-15`) loads `shiny`, `shinydashboard`, `DT` (interactive tables), `dplyr`,
`ggplot2`, `scales`, `tidyr`, and `arules` (needed live, because the recommender queries the
rule objects directly at runtime). `shinydashboard` gives a ready-made admin-panel layout —
dark sidebar, header, boxes — without hand-writing HTML/CSS from scratch.

### 5.2 Structure of the single file
`app.R` has exactly two top-level objects, as is standard for a single-file Shiny app:

```r
ui <- dashboardPage( dashboardHeader(...), dashboardSidebar(...), dashboardBody(...) )
server <- function(input, output, session) { ... }
shinyApp(ui = ui, server = server)   # app.R:952
```

**UI** (`app.R:86-414`) is pure declarative layout — it describes *what boxes, plots, tables,
and inputs exist* but contains no data logic.

**Server** (`app.R:419-949`) is where every `output$...` is actually computed. Shiny's reactive
model means each `output$xyz <- renderXxx({...})` block re-runs automatically whenever an input
or reactive value it depends on changes — nobody manually calls "refresh."

### 5.3 Loading data once, sharing it everywhere
Rather than every output reading files from disk itself, `app.R` loads everything **once** into
a single reactive value called `data_store`, on app startup:

```r
data_store <- reactiveVal(NULL)
observe({
  d <- list()
  d$retail <- readRDS(file.path(DIR_PROC, "retail_clean.rds"))
  d$trans  <- readRDS(file.path(DIR_PROC, "transactions.rds"))
  d$sig    <- readRDS(file.path(DIR_PROC, "rules_significant.rds"))
  d$all_rules  <- load_csv("03_all_significant_rules.csv")
  ... # ~18 more load_csv() calls, one per CSV the dashboard needs
  data_store(d)
})
D <- reactive({ data_store() })
```
*(`app.R:422-457`)*

Every `output$...` block below then starts with `d <- D()` to grab this shared bundle. Two
small helper functions make this robust:

- `load_csv(name)` (`app.R:74-81`) — reads a CSV from `output/tables/`, or returns a
  one-row `data.frame(Note = "... not found.")` if the pipeline hasn't been run yet, so the
  app never crashes on missing files, it just shows a friendly note.
- `show_fig(name, width)` (`app.R:55-71`) — renders a pre-made PNG from `output/figures/` as an
  `<img>` tag via `shiny::addResourcePath("figures", DIR_FIG)` (`app.R:24`), or a "Figure not
  found" placeholder. This is how tabs like Rules/Explorer/Cross-Sell embed the arulesViz plots
  (network graph, parallel coordinates, grouped matrix) **without regenerating them** — those
  plots are expensive (`igraph` layout) and were rendered once, offline, by `04_visualize_rules.R`.

### 5.4 Visual design / CSS
The dashboard is skinned with the Google Font "Inter" and a custom dark-navy sidebar, injected
as raw CSS inside `tags$head(tags$style(HTML("...")))` (`app.R:118-163`). It restyles
`shinydashboard`'s default Bootstrap "skin-blue" classes: rounded box corners, colored left
borders per box status (`box-primary`, `box-danger`, etc.), custom active-menu-item highlighting,
and DataTables font sizing. A small color palette is defined once and reused across `ggplot2`
charts:
```r
mba_colors <- c(primary="#1565C0", accent="#00ACC1", danger="#E53935",
                success="#2E7D32", purple="#7E57C2", orange="#FB8C00", ...)
```
*(`app.R:41-50`)*, and a shared ggplot theme `mba_theme()` (`app.R:27-39`) keeps every chart's
typography and gridlines consistent.

---

## 6. Data Flow — Where Every Number Actually Comes From

```
Excel file (541,909 rows)
   │  R/01_load_clean.R
   ▼
retail_clean.rds  (515,784 rows, 18,273 baskets, 3,765 products)  ─────────────┐
   │  R/02_eda.R                                                               │
   ▼                                                                            │
CSV/PNG: top items, revenue, basket sizes, monthly, heatmap, countries         │
   │  R/03_apriori.R (reads retail_clean.rds directly)                        │
   ▼                                                                            │
transactions.rds, rules.rds, rules_significant.rds (2,215 rules), itemsets.rds │
   │  R/04_visualize_rules.R              R/05_segments_and_recommendations.R  │
   ▼                                        ▼                                  │
Rule charts (PNG)          Segment/season CSVs, recommender demo, cross-sell   │
                            CSVs (uses retail_clean.rds too) ───────────────────┘
   │
   ▼
app.R  ── reads ONLY the .rds/.csv/.png files above, on startup (app.R:424-455)
   │
   ▼
Browser dashboard (7 tabs)
```

**The dashboard never re-runs Apriori, never re-cleans the data, and never re-renders the heavy
plots.** It is a read-only viewer over pre-computed artifacts — which is why the report notes it
launches in seconds. The only *live* computation happening inside the running Shiny session is:
- The Explorer tab's filter (§6.4) — filters the already-loaded `rules_significant.rds` object.
- The Recommender tab's rule-matching (§6.6) — matches the same object against user-picked items.
- The Cross-Sell tab's sort/filter (§6.7) — filters/sorts the already-loaded CSV.
Everything else is a value or chart pulled straight out of a file computed by scripts `01`–`05`.

---

## 7. Tab-by-Tab Breakdown

### Tab 1 — Overview (`app.R:171-190` UI, `app.R:471-548` server)
The "at a glance" landing page.

| On-screen element | Value comes from | Code |
|---|---|---|
| **Baskets** KPI box | `n_distinct(d$retail$InvoiceNo)` — count of unique invoice numbers in `retail_clean.rds` | `app.R:471-477` |
| **Unique Products** KPI box | `n_distinct(d$retail$Item)` | `app.R:478-484` |
| **Significant Rules** KPI box | `length(d$sig)` — size of the `rules_significant.rds` rule set (2,215) | `app.R:485-491` |
| **Total Revenue** KPI box | `sum(d$retail$Revenue)` — Revenue was computed per-row as `Quantity * UnitPrice` back in `01_load_clean.R:80` | `app.R:492-498` |
| Monthly Revenue chart | `02_monthly_sales.csv` (grouped sum of Revenue by month, from `02_eda.R:73-77`) plotted with `geom_col` | `app.R:500-510` |
| Top 10 Products by Frequency | first 10 rows of `02_top50_items_by_frequency.csv` | `app.R:512-524` |
| Weekday × Hour heatmap | recomputed live from `d$retail` (`distinct` + `count` by Weekday/Hour), not from a CSV | `app.R:526-536` |
| Top Countries by Revenue | `02_by_country.csv`, top 10 by Revenue descending | `app.R:538-548` |

Note the heatmap is the one Overview chart computed on-the-fly from raw `retail_clean.rds`
inside the Shiny session rather than a pre-saved table — everything else here is a straight CSV
read.

### Tab 2 — Exploratory / EDA (`app.R:195-212` UI, `app.R:553-594` server)
Lets the user pick how many top items to show via `selectInput` dropdowns bound to
`input$eda_freq_n` / `input$eda_rev_n` (choices 10/15/20/25/30/50, default 20).

- **Top Products by Basket Frequency** chart re-slices `02_top50_items_by_frequency.csv` to
  `head(d$top_freq, n)` where `n = input$eda_freq_n` (`app.R:553-567`) — this is why changing the
  dropdown instantly redraws the bar chart: Shiny re-runs the `renderPlot` block because it reads
  a reactive `input$` value.
- **Top Products by Revenue** — same pattern against `02_top50_items_by_revenue.csv`
  (`app.R:569-580`).
- **Basket Size Distribution** — a histogram computed live from `d$retail`
  (`count(InvoiceNo)` → `BasketSize`), with the mean/median printed in the subtitle
  (`app.R:582-594`).
- **Relative Item Frequency** — this one is *not* a live ggplot; it's the static PNG
  `07_item_frequency_relative.png` produced by `arules::itemFrequencyPlot()` back in
  `03_apriori.R:33-39`, shown via `show_fig()` (`app.R:209-210`).

### Tab 3 — Rules (`app.R:217-244` UI, `app.R:599-639` server)
The core statistics dashboard for the rule-mining stage.

- **Threshold sensitivity chart** — static PNG `08_threshold_sensitivity.png`, generated by the
  5×5 support/confidence grid search in `03_apriori.R:142-163`.
- **Rule Statistics** box — plain text built with `cat()`/`sprintf()` straight from the loaded
  rule object's quality slots:
  ```r
  q <- quality(d$sig)
  cat(sprintf("Support     : %.4f – %.4f\n", min(q$support), max(q$support)))
  cat(sprintf("Confidence  : %.3f – %.3f\n", min(q$confidence), max(q$confidence)))
  cat(sprintf("Lift        : %.2f – %.2f\n", min(q$lift), max(q$lift)))
  cat(sprintf("Mean lift   : %.2f\n", mean(q$lift)))
  ```
  *(`app.R:599-614`)* — every number here is computed **live**, at render time, directly off
  the 2,215-rule `arules` object loaded into memory (not off a pre-saved CSV).
- **Top 20 Rules by Lift** bar chart — static PNG `14_top_rules_by_lift_bars.png`
  (`04_visualize_rules.R:66-83`).
- **Support vs Confidence scatter** — static PNG `09_rules_scatter.png`
  (`04_visualize_rules.R:15-28`), colour-mapped by lift.
- **Four searchable/sortable tables** — `tab_lift`, `tab_conf`, `tab_supp`, `tab_all`
  (`app.R:616-639`), each just wraps a CSV (`03_top_rules_by_lift.csv`, `_confidence.csv`,
  `_support.csv`, and the full `03_all_significant_rules.csv`) in `DT::datatable()` with
  `filter = "top"` (per-column search boxes) and pagination.

### Tab 4 — Explorer (`app.R:249-274` UI, `app.R:644-678` server)
An **interactive live filter** over the in-memory rule object — the first tab where the user's
input actually re-computes something rather than just re-slicing a pre-made table.

Inputs: `sliderInput`s for min lift / min confidence / min support, a `numericInput` for max
rows, a `textInput` keyword search, and an `actionButton("exp_apply", "Apply Filters")`.

```r
observeEvent(input$exp_apply, {
  q <- quality(d$sig)
  keep <- q$lift >= min_lift & q$confidence >= min_conf & q$support >= min_supp
  filtered <- d$sig[keep]
  if (length(filtered) > max_r) {
    filtered <- head(sort(filtered, by = "lift", decreasing = TRUE), max_r)
  }
  df <- arules::DATAFRAME(filtered, setStart = "", setEnd = "", itemSep = " + ")
  ...
  if (nchar(search) > 0) {
    combined <- paste(df$Antecedent, df$Consequent)
    df <- df[grepl(search, combined, ignore.case = TRUE), ]
  }
  output$exp_table <- renderDT({ datatable(df, ...) })
}, ignoreNULL = FALSE)
```
*(`app.R:644-678`)* — this only runs when the button is clicked (`observeEvent` on
`input$exp_apply`), not on every slider tick, so dragging a slider doesn't hammer the server;
the user must click "Apply Filters" to re-filter. Below the table, two static PNGs are shown:
the top-25-by-lift association network graph (`11_rules_graph_top25_lift.png`) and the
top-20-by-confidence parallel coordinates plot (`13_rules_paracoord.png`), both pre-rendered by
`04_visualize_rules.R`.

### Tab 5 — Segments (`app.R:279-312` UI, `app.R:683-757` server)
Compares UK vs International, and festive quarter vs rest of year.

| Element | Source |
|---|---|
| UK Baskets / Intl Baskets KPI boxes | live count from `d$retail`, filtered on `Country == "United Kingdom"` (`app.R:683-694`) |
| UK Top Rules / Intl Top Rules KPI boxes | `nrow()` of `05_top_rules_uk.csv` / `05_top_rules_international.csv` (`app.R:695-704`) |
| Segment comparison bar chart & table | `05_segment_comparison.csv`, produced by re-running Apriori separately per segment in `05_segments_and_recommendations.R:36-69` — International uses a relaxed 2% support threshold because it has far fewer baskets (`R/05_segments_and_recommendations.R:44`) |
| UK / Intl rule tables | `05_top_rules_uk.csv` / `05_top_rules_international.csv`, each the top 25 rules by lift within that segment |
| Festive vs Rest-of-Year bar chart | `05_season_comparison.csv`, from re-mining Apriori on Sep–Nov baskets vs the rest (`R/05_segments_and_recommendations.R:71-96`) |
| Festive-Only Rules table | `05_festive_only_rules.csv` — rules present in the festive rule set whose exact item combination never appears in the rest-of-year rule set (`R/05_segments_and_recommendations.R:99-103`) |

### Tab 6 — Recommender (`app.R:317-370` UI, `app.R:762-867` server)
The interactive "build a basket, get suggestions" tool — the only tab that lets a user run a
live query against all 2,215 rules with arbitrary input.

1. A `selectizeInput("recom_items", ...)` is populated server-side with every distinct product
   name from `retail_clean.rds` (`app.R:460-466`), so typing filters 3,765 products without
   sending them all to the browser upfront.
2. Clicking **"Get Recommendations"** triggers `observeEvent(input$recom_go, {...})`
   (`app.R:772-830`):
   ```r
   LHS_LIST <- as(lhs(sig), "list")       # every rule's antecedent, as item-name lists
   RHS_ITEM <- unlist(as(rhs(sig), "list"))  # every rule's single consequent item
   QUAL     <- quality(sig)                  # support/confidence/lift vectors, same order

   fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
   rec <- data.frame(Recommendation = RHS_ITEM[fires],
                      Confidence = round(QUAL$confidence[fires], 3),
                      Lift       = round(QUAL$lift[fires], 2),
                      Support    = round(QUAL$support[fires], 4))
   rec <- rec[!rec$Recommendation %in% basket, ]      # don't recommend what's already picked
   rec <- rec[order(-rec$Lift), ]
   rec <- rec[!duplicated(rec$Recommendation), ]       # keep only the best rule per product
   rec <- head(rec, 10)
   ```
   This is the exact same matching rule described in §4.4 — "every antecedent item must be in
   the basket" — implemented live against the loaded `arules` rule set. It returns up to the
   top 10 distinct recommended products, ranked by lift.
3. **Sample Basket** buttons 1/2/3 (`app.R:832-867`) each pull a random real basket of a given
   size range from `transactions.rds` (using a fixed `set.seed()` per button, so the "random"
   pick is actually reproducible/deterministic every time you click it) and pre-fill the
   selectize input with its first few items.
4. The three small info boxes ("Lift" / "Confidence" / "Support") below the explanation text
   are static labels (`app.R:762-770`) — they don't compute anything, they just restate the
   formulas for the user.

### Tab 7 — Cross-Sell (`app.R:375-411` UI, `app.R:872-948` server)
Turns the rules into a money figure.

| Element | Source |
|---|---|
| Total Revenue Opportunity KPI | `sum(d$cs_best$PotentialRevenue)` — sum over `05_cross_sell_best_rule_per_product.csv`, i.e. the *deduplicated, best-rule-per-product* file from §4.5, not the raw per-rule file (`app.R:872-883`) |
| Best Single Opportunity KPI | the single largest `PotentialRevenue` row in that same file (`app.R:885-896`) |
| Average Lift KPI | `mean(d$cs_best$Lift)` (`app.R:898-906`) |
| Products with Opportunity KPI | `nrow(d$cs_best)` — how many distinct consequent products have a positive opportunity (`app.R:908-916`) |
| Top 15 chart | static PNG `15_cross_sell_opportunity_value.png` (`R/05_segments_and_recommendations.R:206-217`) |
| All Cross-Sell Opportunities table | `05_cross_sell_best_rule_per_product.csv`, with live sort (`selectInput("cs_sort", ...)`: by revenue / lift / confidence / missed baskets) and a min-lift filter dropdown, both applied in `output$cs_table` (`app.R:918-948`); long rule/consequent text is truncated to keep the table readable |

---

## 8. Limitations (from `PROJECT_REPORT.md §12`, cross-checked against the code)

1. **No customer-level personalization.** Rules are mined from aggregate basket co-occurrence
   across all 18,273 baskets — two different customers who pick the same items get identical
   recommendations from the Recommender tab, because the matching logic (§6, Tab 6) only looks
   at the current basket's contents, never at customer history.
2. **Static rules.** `rules_significant.rds` is mined once from the full 12 months. The
   Segments tab's own festive-vs-rest comparison shows the rule structure shifts substantially
   by season (5,174 festive-quarter rules vs 2,296 rest-of-year rules), so the shipped rule set
   is a compromise, not a per-period fit — it would need to be re-mined quarterly for the
   Recommender/Cross-Sell numbers to stay accurate through the year.
3. **No price sensitivity.** The cross-sell formula (§4.5) uses a single average price/quantity
   per product (`AvgPrice`, `AvgQty`), ignoring the fact that prices and typical order size can
   drift over the year or differ between segments.
4. **Single retailer, single vertical.** All numbers come from one UK giftware retailer;
   findings (herb-marker set-completion, colourway substitution, etc.) are specific to that kind
   of catalog and may not transfer to groceries, electronics, or fashion retail.
5. **No temporal weighting.** Every transaction in the 12-month window is treated as equally
   informative — a purchase from December 2010 counts the same as one from November 2011, even
   though buying patterns may have shifted.
6. **Correlation, not causation.** A rule `A ⇒ B` means A and B co-occur more than chance would
   predict — it does not mean buying A *causes* someone to buy B. Both could simply be driven by
   a third factor (e.g., "it's Christmas," or "these are the same herb-marker gift set").
7. **Recommender has no cold-start / no-match handling beyond a message.** If a selected basket
   matches zero rule antecedents, the UI just shows "No rules fired for this combination of
   items" (`app.R:795-803`) — there's no fallback to, say, generic best-sellers.

### Future scope (also from the report, not yet implemented in code)
Sequence mining (order of purchase, not just co-occurrence), collaborative-filtering /
deep-learning recommenders as a comparison point, a real-time re-mining pipeline, RFM-based
customer segmentation with per-cluster rule sets, an A/B-testing framework to validate the
revenue-uplift assumption in §4.5 against real conversions, benchmarking Apriori against
FP-Growth, and a mobile-responsive layout (`shinyMobile` / `bslib`).

---

## 9. Quick Reference: Every Package Actually Used

| Package | Used for | Where |
|---|---|---|
| `readxl` | Reading the raw `.xlsx` | `01_load_clean.R` |
| `dplyr`, `tidyr` | Filtering, grouping, reshaping | all scripts + live in `app.R` server |
| `lubridate` | Date/month/hour/weekday extraction | `01_load_clean.R` |
| `ggplot2`, `scales`, `RColorBrewer` | All static charts (both pre-rendered PNGs and the live Overview/EDA plots) | `02_eda.R`, `03_apriori.R`, `04_visualize_rules.R`, `05_...R`, `app.R` |
| `arules` | The Apriori algorithm, rule objects, `quality()`, `interestMeasure()`, `is.redundant()` | `03_apriori.R`, `05_...R`, live in `app.R`'s Rules/Explorer/Recommender tabs |
| `arulesViz` | Network graph, grouped matrix, parallel coordinates, two-key plot (rendered offline to PNG, not live) | `04_visualize_rules.R` |
| `shiny`, `shinydashboard` | The dashboard framework and admin-panel layout | `app.R` |
| `DT` | Interactive, searchable, paginated tables | every `DTOutput`/`renderDT` in `app.R` |
