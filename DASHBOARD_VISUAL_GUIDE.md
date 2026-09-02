# Basket Lens — Visual Guide to Every Feature

**What this document is.** A screen-by-screen tour of the running dashboard. For
every panel you see, it answers four questions:

1. **What am I looking at?** — the picture itself, embedded here.
2. **What code makes it?** — the exact line in `app.R` (and the pipeline script
   behind it).
3. **Where did the numbers come from?** — traced back through the CSV/RDS files
   to the raw dataset.
4. **What is it actually telling me?** — how to read the chart, and what the
   result means.

The screenshots in `docs/screenshots/` were captured from the live app
(`http://127.0.0.1:3838`) against the current contents of `data/processed/` and
`output/`, so every number on this page is the number the app renders today.

Related docs, and how this one differs:

| Document | Covers |
|---|---|
| `README.md` | How to install and run |
| `THEORY.md` | The maths (support, confidence, lift, Fisher's test) |
| `PROJECT_REPORT.md` | Formal academic write-up |
| `CODE_EXPLAINED.md` | Walkthrough of the pipeline scripts |
| `APP_R_VIVA_PREP.md` | `app.R` line-by-line + exam questions |
| `NUMBERS_TRACED.md` | Number provenance, in text form |
| **this file** | **The dashboard as you actually see it, with the pictures** |

---

## Table of contents

- [Part 0 — The machine behind the screen](#part-0--the-machine-behind-the-screen)
- [Tab 1 — Overview](#tab-1--overview)
- [Tab 2 — Exploratory](#tab-2--exploratory)
- [Tab 3 — Rules](#tab-3--rules)
- [Tab 4 — Explorer](#tab-4--explorer)
- [Tab 5 — Segments](#tab-5--segments)
- [Tab 6 — Recommender](#tab-6--recommender)
- [Tab 7 — Cross-Sell](#tab-7--cross-sell)
- [Part 8 — Formula reference](#part-8--formula-reference)
- [Part 9 — Things worth knowing](#part-9--things-worth-knowing-quirks-and-gotchas)

---

# Part 0 — The machine behind the screen

## 0.1 The pipeline, in order

The dashboard computes almost nothing itself. Five scripts run first and leave
their results on disk; `app.R` reads those results and draws them.

```
data/raw/Online Retail.xlsx          541,909 rows, straight from UCI
        |
        |  R/01_load_clean.R      audit -> filter -> canonical names -> drop 1-item baskets
        v
data/processed/retail_clean.rds      515,784 rows | 18,273 baskets | 3,765 products
        |
        +---- R/02_eda.R ---------> output/tables/02_*.csv      output/figures/01-06
        |
        +---- R/03_apriori.R -----> transactions.rds, rules.rds, rules_significant.rds
        |                           output/tables/03_*.csv      output/figures/07-08
        |
        +---- R/04_visualize_rules.R -------> output/figures/09-14
        |
        +---- R/05_segments_and_recommendations.R --> output/tables/05_*.csv, figure 15
        |
        v
     app.R      reads the .rds and .csv files and renders the 7 tabs
```

`run_all.R` executes 01 → 05 in sequence.

## 0.2 The two kinds of picture on this dashboard

This is the single most useful thing to understand about `app.R`, because it
explains why some panels react to your clicks and others do not.

| | **Live plots** | **Static images** |
|---|---|---|
| Built by | `renderPlot({ ... })` inside `app.R` | `ggsave()` / `png()` in the pipeline scripts |
| Stored as | nothing — redrawn per session | a `.png` in `output/figures/` |
| Placed by | `plotOutput("id")` | `show_fig("name.png")` (`app.R:55`) |
| Reacts to inputs | **yes** | **no** |
| Example | Monthly Revenue Trend | Threshold sensitivity curve |

`show_fig()` is a small helper at `app.R:55-70`. It checks the file exists,
and if not, draws a grey "run the pipeline first" placeholder instead of
erroring. The images are served over HTTP because line 24 registers the folder:

```r
shiny::addResourcePath("figures", DIR_FIG)
```

Here is every panel, classified:

| Tab | Panel | Type | Source |
|---|---|---|---|
| Overview | Monthly revenue, Top 10, Heatmap, Countries | live | `renderPlot` |
| Exploratory | Top-N frequency, Top-N revenue, Basket size | live | `renderPlot` |
| Exploratory | Relative Item Frequency | static | `07_item_frequency_relative.png` |
| Rules | Threshold sensitivity | static | `08_threshold_sensitivity.png` |
| Rules | Top 20 by lift | static | `14_top_rules_by_lift_bars.png` |
| Rules | Rule landscape scatter | static | `09_rules_scatter.png` |
| Explorer | Association network | static | `11_rules_graph_top25_lift.png` |
| Explorer | Parallel coordinates | static | `13_rules_paracoord.png` |
| Segments | Both bar charts | live | `renderPlot` |
| Cross-Sell | Top 15 opportunities | static | `15_cross_sell_opportunity_value.png` |

**Consequence:** the sliders on the Explorer tab change the *table* but never
the network diagram below it. The diagram is a fixed picture of the top 25
rules by lift, baked in when `04_visualize_rules.R` last ran.

## 0.3 How data reaches the server

Everything is loaded once, into one reactive list, at `app.R:420-455`:

```r
data_store <- reactiveVal(NULL)
observe({
  d <- list()
  d$retail <- readRDS(.../retail_clean.rds)          # the cleaned rows
  d$trans  <- readRDS(.../transactions.rds)          # arules transaction object
  d$sig    <- readRDS(.../rules_significant.rds)     # the 2,215 rules
  d$monthly <- load_csv("02_monthly_sales.csv")      # ... and 17 more CSVs
  data_store(d)
})
D <- reactive({ data_store() })
```

Each `readRDS` is wrapped in `tryCatch` so a missing file logs a message rather
than crashing the app, and `load_csv()` (`app.R:73`) returns a one-column
`data.frame(Note = "... not found.")` placeholder for a missing CSV. That is why
you see the repeated guard `if (is.null(d) || "Note" %in% names(d$x)) return(NULL)`
throughout the server — it is checking for that placeholder.

## 0.4 The cleaning that produced every number

From `R/01_load_clean.R`. The audit runs *before* any filtering
(`output/tables/01_data_quality_audit.csv`):

| Check on the raw file | Value |
|---|---|
| Total rows | 541,909 |
| Missing Description | 1,454 |
| Missing CustomerID | 135,080 |
| Cancelled invoices (`InvoiceNo` starts with `C`) | 9,288 |
| Quantity ≤ 0 | 10,624 |
| UnitPrice ≤ 0 | 2,517 |
| Duplicate rows | 5,268 |
| Distinct invoices | 25,900 |
| Distinct stock codes | 4,070 |
| Distinct countries | 38 |

Then eight filters run in order: drop missing descriptions → drop cancellations
→ require `Quantity > 0` and `UnitPrice > 0` → drop 16 admin stock codes
(`POST`, `DOT`, `M`, `BANK CHARGES`, `AMAZONFEE`, …) → uppercase and trim → drop
junk descriptions by regex (`damaged`, `lost`, `adjust`, `smashed`, …) → require
description longer than 2 characters → `distinct(InvoiceNo, StockCode)`.

Two steps after that matter for the analysis:

- **Canonical names.** The same `StockCode` appears with slightly different
  descriptions across rows. The most frequent description per code wins, and is
  joined back as the `Item` column. Every rule you see is built on `Item`.
- **Single-item baskets are dropped.** A basket of one product contains no
  co-occurrence information, so it cannot support a rule.

The result (`output/tables/01_cleaning_summary.csv`):

| Metric | Value |
|---|---|
| Rows after cleaning | 515,784 |
| Rows removed | 26,125 |
| % rows retained | 95.2% |
| Transactions (baskets) | **18,273** |
| Unique products | **3,765** |
| Countries | 38 |
| Date range | 2010-12-01 to 2011-12-09 |
| Mean basket size | 28.23 |
| Median basket size | 17 |
| Total revenue (GBP) | **9,658,813** |

Those four bold numbers are exactly the four KPI boxes on the Overview tab.

## 0.5 The parameters that control everything

One list, in `R/00_setup.R:48-55`:

```r
PARAMS <- list(
  support    = 0.01,   # 1% of baskets ~= 183 baskets
  confidence = 0.30,   # 30% conditional probability
  minlen     = 2,      # at least one item on each side
  maxlen     = 4,      # keep itemsets interpretable
  min_lift   = 1.0,    # only rules that beat chance
  top_n      = 20      # rows in the "top" tables and plots
)
```

Change `support` here and every rule count on the dashboard changes. The Rules
tab quantifies exactly how much.

---

# Tab 1 — Overview

![Overview tab](docs/screenshots/tab1_overview.png)

The landing page: four headline counts, then the shape of the business in four
charts. Layout defined at `app.R:171-192`.

## The four KPI boxes

| Box | Value | Server code | Computation | Traces to |
|---|---|---|---|---|
| Baskets | 18,273 | `app.R:471` | `n_distinct(d$retail$InvoiceNo)` | `retail_clean.rds` |
| Unique Products | 3,765 | `app.R:478` | `n_distinct(d$retail$Item)` | `retail_clean.rds` |
| Significant Rules | 2,215 | `app.R:485` | `length(d$sig)` | `rules_significant.rds` |
| Total Revenue | GBP 9,658,813 | `app.R:492` | `sum(d$retail$Revenue)` | `Revenue = Quantity × UnitPrice` |

All four are computed live from the loaded objects, not read from a CSV — which
is why they always agree with whatever is currently in `data/processed/`.

A note on **Total Revenue**: `Revenue` is created in `01_load_clean.R` as
`Quantity * UnitPrice`, *after* cancellations and non-positive quantities have
been removed. So GBP 9.66M is gross sales on retained, non-cancelled,
multi-item baskets — not the retailer's audited turnover.

## Monthly Revenue Trend

**Code:** `plotOutput` at `app.R:180`, `renderPlot` at `app.R:500-511`.
**Data:** `output/tables/02_monthly_sales.csv`, written by `R/02_eda.R` from
`group_by(Month) |> summarise(Revenue = sum(Revenue))`.

The exact bar heights:

| Month | Revenue (GBP) | Transactions |
|---|---:|---:|
| Dec 2010 | 743,644 | 1,386 |
| Jan 2011 | 579,439 | 999 |
| Feb 2011 | 490,179 | 1,014 |
| Mar 2011 | 672,982 | 1,343 |
| Apr 2011 | 497,564 | 1,138 |
| May 2011 | 713,477 | 1,523 |
| Jun 2011 | 672,480 | 1,394 |
| Jul 2011 | 672,545 | 1,349 |
| Aug 2011 | 707,742 | 1,230 |
| **Sep 2011** | **1,007,538** | 1,714 |
| **Oct 2011** | **1,068,787** | 1,858 |
| **Nov 2011** | **1,411,515** | 2,567 |
| Dec 2011 | 420,922 | 758 |

**What it says.** Revenue roughly doubles into the Christmas run-up: November
alone (1.41M) is 2.9× February (0.49M). This is a wholesale giftware business,
and Q4 is the whole game.

**The final bar is not a crash.** December 2011 looks like a collapse only
because the dataset stops on **9 December 2011** — it is nine days, not a month.
Reading it as a demand fall-off is the most common misreading of this chart.

The Sep–Nov bulge is what motivates the seasonal split on the Segments tab.

## Top 10 Products by Frequency

**Code:** `app.R:182` / `app.R:512-525`.
**Data:** first 10 rows of `output/tables/02_top50_items_by_frequency.csv`.

The count is *baskets containing the product*, not units sold — `count(Item)`
on a table already reduced to one row per item per basket.

| Rank | Product | Baskets | Support |
|---|---|---:|---:|
| 1 | WHITE HANGING HEART T-LIGHT HOLDER | 2,246 | 0.1229 |
| 2 | JUMBO BAG RED RETROSPOT | 2,073 | 0.1134 |
| 3 | REGENCY CAKESTAND 3 TIER | 1,965 | 0.1075 |
| 4 | PARTY BUNTING | 1,670 | 0.0914 |
| 5 | LUNCH BAG RED RETROSPOT | 1,564 | 0.0856 |
| 6 | ASSORTED COLOUR BIRD ORNAMENT | 1,453 | 0.0795 |
| 7 | SET OF 3 CAKE TINS PANTRY DESIGN | 1,376 | 0.0753 |
| 8 | POPCORN HOLDER | 1,369 | 0.0749 |
| 9 | PACK OF 72 RETROSPOT CAKE CASES | 1,320 | 0.0722 |
| 10 | LUNCH BAG SUKI DESIGN | 1,283 | 0.0702 |

Support is simply `Baskets / 18,273`. The top product appears in 12.3% of all
baskets — and note that **no single product reaches even 13%**. That long, flat
tail is why a 1% support threshold is not as permissive as it sounds.

## Trading Rhythm: Weekday × Hour

**Code:** `app.R:186` / `app.R:526-537`.
**Data:** computed live, not from a CSV:

```r
d$retail |> distinct(InvoiceNo, Weekday, Hour) |> count(Weekday, Hour)
```

`distinct()` first, so each *invoice* is counted once rather than once per line
item. `Weekday` and `Hour` were derived in `01_load_clean.R` with
`lubridate::wday()` and `lubridate::hour()`.

**What it says.** Trading is concentrated Monday–Friday, roughly 09:00–15:00,
peaking around midday Wednesday–Thursday. Two things to notice:

- **There is no Saturday row at all.** The axis runs Mon, Tue, Wed, Thu, Fri,
  Sun. The retailer simply never records a Saturday order in this dataset — the
  row is absent, not empty.
- Sunday trades, but thinly and over a shorter window.

This is B2B wholesale behaviour: buyers order from an office, during office
hours.

## Top Countries by Revenue

**Code:** `app.R:188` / `app.R:538-549`.
**Data:** `output/tables/02_by_country.csv`, sorted descending, first 10.

| Country | Transactions | Revenue (GBP) | Share |
|---|---:|---:|---:|
| United Kingdom | 16,506 | 8,169,434 | **84.6%** |
| Netherlands | 80 | 273,284 | 2.83% |
| EIRE | 266 | 269,712 | 2.79% |
| Germany | 426 | 204,099 | 2.11% |
| France | 366 | 182,378 | 1.89% |
| Australia | 47 | 134,466 | 1.39% |
| Spain | 86 | 55,533 | 0.57% |
| Switzerland | 47 | 52,609 | 0.54% |
| Belgium | 96 | 36,832 | 0.38% |
| Sweden | 29 | 35,196 | 0.36% |

**What it says.** One bar dominates and the other nine are slivers. The UK is
84.6% of revenue on 16,506 of 18,273 baskets.

Look at the *ratio* though: the Netherlands turns 80 baskets into GBP 273k —
about GBP 3,400 per basket, against roughly GBP 495 per UK basket. A handful of
very large export orders. This asymmetry is exactly why the Segments tab has to
mine the two markets separately with different support thresholds.

---

# Tab 2 — Exploratory

![Exploratory tab](docs/screenshots/tab2_eda.png)

Four views of the cleaned data before any rule mining. Layout at `app.R:195-213`.

## Top Products by Basket Frequency (interactive)

**Control:** `selectInput("eda_freq_n")` at `app.R:198` — choices 10, 15, 20,
25, 30, 50, default 20.
**Code:** `app.R:200` / `app.R:553-568`.
**Data:** `head(02_top50_items_by_frequency.csv, n)`.

This is the same data as the Overview's Top 10, extended. Ranks 11-20:

| Rank | Product | Baskets |
|---|---|---:|
| 11 | LUNCH BAG BLACK SKULL | 1,271 |
| 12 | NATURAL SLATE HEART CHALKBOARD | 1,248 |
| 13 | JUMBO BAG VINTAGE DOILY | 1,230 |
| 14 | JUMBO BAG PINK POLKADOT | 1,216 |
| 15 | HEART OF WICKER SMALL | 1,197 |
| 16 | JUMBO STORAGE BAG SUKI | 1,184 |
| 17 | JUMBO SHOPPER VINTAGE RED PAISLEY | 1,174 |
| 18 | LUNCH BAG SPACEBOY DESIGN | 1,157 |
| 19 | PAPER CHAIN KIT 50'S CHRISTMAS | 1,153 |
| 20 | JAM MAKING SET PRINTED | 1,152 |

**Why the dropdown stops at 50:** the CSV holds exactly 50 rows
(`save_tab(head(top_items, 50), ...)` in `R/02_eda.R`). Asking for more than
50 would show nothing extra, so the choice list is capped to match.

**What it says.** The curve is remarkably flat — rank 1 is 2,246 and rank 20 is
still 1,152. There is no runaway bestseller; the business is broad.

## Top Products by Revenue (interactive)

**Control:** `selectInput("eda_rev_n")` at `app.R:202`.
**Code:** `app.R:204` / `app.R:569-581`.
**Data:** `head(02_top50_items_by_revenue.csv, n)`, built with
`summarise(Revenue = sum(Revenue), Units = sum(Quantity))`.

**Read this chart against the one on its left — that is the whole point of the
pairing.** The ordering changes:

| Product | Rank by frequency | Rank by revenue |
|---|---:|---:|
| REGENCY CAKESTAND 3 TIER | 3 | **1** |
| WHITE HANGING HEART T-LIGHT HOLDER | 1 | 2 |
| PARTY BUNTING | 4 | 3 |
| JUMBO BAG RED RETROSPOT | 2 | 4 |
| RABBIT NIGHT LIGHT | outside top 20 | 7 |
| CHILLI LIGHTS | outside top 20 | 8 |

REGENCY CAKESTAND 3 TIER appears in fewer baskets than the t-light holder but
earns more, because it is an expensive item (average unit price GBP 13.98 —
see the Cross-Sell table). RABBIT NIGHT LIGHT and CHILLI LIGHTS make the
revenue top ten without being frequent at all.

**Why this matters for the rest of the dashboard:** Apriori ranks by
*frequency*, so the rules it finds are about the cheap, high-volume items.
Frequency and value are different questions, and the Cross-Sell tab exists to
bolt price back on.

## Basket Size Distribution

**Code:** `app.R:208` / `app.R:582-595`.
**Data:** computed live — `d$retail |> count(InvoiceNo, name = "BasketSize")`.
Subtitle statistics are computed in the same block.

Full statistics from `output/tables/02_basket_size_stats.csv`:

| Statistic | Distinct products in basket |
|---|---:|
| Min | 2 |
| Q1 | 8 |
| Median | 17 |
| Mean | 28.23 |
| Q3 | 30 |
| P95 | 78.4 |
| Max | **1,106** |

**What it says.** A textbook right-skewed distribution. Mean (28.2) sits well
above median (17) because a small number of enormous wholesale orders drag the
average up — the largest single basket holds 1,106 distinct products.

**Two things the chart hides.** The x-axis is capped at 100
(`scale_x_continuous(limits = c(0, 100))`), so roughly the top 2-3% of baskets
are silently dropped from the plot; ggplot removes them rather than compressing
the axis. And the minimum is 2, not 1, because single-item baskets were removed
during cleaning.

## Relative Item Frequency  *(static image)*

**Code:** `show_fig("07_item_frequency_relative.png")` at `app.R:210`.
**Produced by:** `R/03_apriori.R`, using `arules::itemFrequencyPlot()` — base R
graphics written straight to PNG, which is why it is a fixed image and looks
different from the ggplot panels around it.

![Relative item frequency](output/figures/07_item_frequency_relative.png)

**What it says.** The same top 20 items, but on the *support* scale that Apriori
actually uses — the y-axis reads 0.12 down to about 0.06. Put the horizontal
line of the 0.01 support threshold mentally at the very bottom of this chart:
every item shown is far above it. The threshold's real work is excluding the
other ~3,745 products, not these.

---

# Tab 3 — Rules

![Rules tab](docs/screenshots/tab3_rules.png)

Where the association rules themselves appear. Layout at `app.R:217-246`.

## How do rule counts react to threshold pairs?  *(static image)*

**Code:** `show_fig("08_threshold_sensitivity.png")` at `app.R:221`.
**Produced by:** `R/03_apriori.R`, which runs Apriori **25 separate times** over
a grid of 5 support × 5 confidence values and records `length(r)` each time.
Saved to `output/tables/03_threshold_sensitivity.csv`.

![Threshold sensitivity](output/figures/08_threshold_sensitivity.png)

The full grid, in numbers:

| min support ↓ / min confidence → | 0.2 | 0.3 | 0.4 | 0.5 | 0.6 |
|---|---:|---:|---:|---:|---:|
| **0.005** | 40,787 | 33,360 | 27,333 | 21,245 | 14,545 |
| **0.0075** | 8,155 | 6,272 | 4,982 | 3,784 | 2,638 |
| **0.010** | 3,003 | **2,229** | 1,734 | 1,239 | 814 |
| **0.015** | 740 | 577 | 429 | 277 | 145 |
| **0.020** | 247 | 217 | 158 | 78 | 37 |

**What it says — and this is the most important chart on the dashboard for
defending the method.** The y-axis is logarithmic, and the lines are steep and
near-parallel. Compare the two directions:

- Move **support** from 0.005 to 0.02 (4× stricter), holding confidence at 0.3:
  33,360 → 217 rules. A **154-fold** reduction.
- Move **confidence** from 0.2 to 0.6 (3× stricter), holding support at 0.01:
  3,003 → 814 rules. A **3.7-fold** reduction.

Support is the parameter that matters, by roughly two orders of magnitude. The
reason is the Apriori property itself: raising support prunes *itemsets* before
any rules are generated, so it cuts the combinatorial search space. Confidence
only filters rules that have already been generated.

The chosen operating point is support 0.01 / confidence 0.3 — the highlighted
cell, 2,229 raw rules. Choosing 0.005 instead would have produced 33,360, far
too many to inspect; choosing 0.02 would have produced 217, mostly obvious.

## Rule Statistics

**Code:** `verbatimTextOutput("rules_stats")` at `app.R:223`, `renderPrint` at
`app.R:599-615`.
**Data:** computed live from `quality(d$sig)`.

```
SIGNIFICANT ASSOCIATION RULES
=============================================
Total rules : 2215
Support     : 0.0100 – 0.0451
Confidence  : 0.300 – 0.968
Lift        : 2.47 – 75.47
Mean lift   : 12.97
=============================================
```

Read the bounds as confirmation that the filters did their job: minimum support
is exactly 0.0100 and minimum confidence exactly 0.300 — the thresholds — while
minimum **lift is 2.47**, comfortably above the `lift > 1` cut. Not one surviving
rule is merely marginally better than chance.

**How 2,229 became 2,215** (`R/03_apriori.R:88-113`):

| Stage | Rules | Code |
|---|---:|---|
| Raw Apriori at supp 0.01 / conf 0.3 | 2,229 | `apriori(...)` |
| After `lift > 1` | (unchanged in practice) | `subset(rules, lift > PARAMS$min_lift)` |
| After removing redundant rules | 2,215 | `rules[!is.redundant(rules)]` |
| After Fisher + BH, p < 0.05 | **2,215** | `subset(rules, pAdjusted < 0.05)` |

A rule is **redundant** when a more general rule — one whose antecedent is a
subset — already achieves at least the same confidence. The extra condition
earns nothing, so it is dropped.

**The statistical test removed exactly zero rules.** Each rule gets a Fisher's
exact test on its 2×2 contingency table, and the p-values are corrected for
multiple testing with Benjamini-Hochberg. All 2,215 survived at p < 0.05. That
is not a bug — with 18,273 baskets, a rule that already clears support 1% and
lift 2.47 has overwhelming evidence behind it. Worth stating plainly if you are
asked: the test is a guard that did not need to fire, not a filter doing work.

The three explanatory lines in the blue box to the right (`app.R:225-229`) are
static text describing exactly this.

## Top 20 Rules by Lift  *(static image)*

**Code:** `show_fig("14_top_rules_by_lift_bars.png")` at `app.R:231`.
**Produced by:** `R/04_visualize_rules.R`, bar length = lift, fill = confidence.

![Top 20 rules by lift](output/figures/14_top_rules_by_lift_bars.png)

**What it says.** Every one of the top 20 rules is a HERB MARKER rule. The set
is BASIL, CHIVES, MINT, PARSLEY, ROSEMARY, THYME, and the rules are combinations
like `{MINT, PARSLEY} => {CHIVES}` at lift 75.47.

This is the single most striking result on the dashboard, and it needs the right
interpretation. A lift of 75 means the consequent is 75× more likely than
baseline — but these are **six variants of one product sold as a set**. The
algorithm has rediscovered the product range, not a customer behaviour. It is a
genuine pattern and a correct result; it is simply not an actionable one, since
nobody needs an algorithm to suggest the sixth herb marker to someone buying
five.

This is why the Cross-Sell tab ranks by *money* rather than lift — and note that
not one herb marker appears in its top 15.

## Rule Landscape: Support vs Confidence  *(static image)*

**Code:** `show_fig("09_rules_scatter.png")` at `app.R:234`.
**Produced by:** `R/04_visualize_rules.R`, one point per rule, colour = lift.

![Rule landscape](output/figures/09_rules_scatter.png)

**How to read it.** All 2,215 rules plotted at once: x = support (1.0%-4.5%),
y = confidence (30%-97%), colour = lift (blue low, red high).

- The **left edge is a wall.** Nothing exists left of 1.0% support — that is the
  threshold, drawn by its own absence.
- The **upper-left cluster is red.** High confidence, low support, very high
  lift: the rare-but-reliable rules. That red cluster is the herb markers.
- The **right side is blue and low.** Rules with high support (4%+) sit at 40-60%
  confidence and lift under 10 — the popular-item rules like
  `{LUNCH BAG RED RETROSPOT} => {JUMBO BAG RED RETROSPOT}`.

The trade-off is visible as a shape: you can have a rule that fires often, or a
rule that is nearly always right, rarely both. Lift and support pull against
each other because lift divides by the consequent's own frequency.

## Rule Tables (four tabs)

**Code:** `tabBox` at `app.R:237-242`; the four `renderDT` blocks at
`app.R:616-641`.

| Tab | Output id | CSV | Rows |
|---|---|---|---:|
| By Lift | `tab_lift` | `03_top_rules_by_lift.csv` | 20 |
| By Confidence | `tab_conf` | `03_top_rules_by_confidence.csv` | 20 |
| By Support | `tab_supp` | `03_top_rules_by_support.csv` | 20 |
| All Rules | `tab_all` | `03_all_significant_rules.csv` | **2,215** |

The first three are pre-sorted top-20 extracts written by `R/03_apriori.R:120-127`;
only "All Rules" contains the complete set. All four are DataTables with
`filter = "top"` (the per-column search boxes) and `scrollX = TRUE`.

The columns are the standard `arules` quality measures plus the two added by the
significance step:

| Column | Meaning |
|---|---|
| `support` | P(LHS ∩ RHS) — fraction of all baskets holding both |
| `confidence` | P(RHS \| LHS) — how often the rule is right when it fires |
| `coverage` | P(LHS) — fraction of baskets the rule applies to at all |
| `lift` | confidence ÷ P(RHS) — times better than chance |
| `count` | absolute baskets = support × 18,273 |
| `fishersPValue` | raw p-value from the exact test |
| `pAdjusted` | Benjamini-Hochberg corrected p-value |

**The p-value columns show `0`, and that is a display artefact, not a bug.**
`R/03_apriori.R:134` rounds every numeric column to 5 decimal places
(`round(x, 5)`); the true p-values are far smaller than 1e-5, so they render as
zero. They are not literally zero.

Sanity check on the top row: support 0.01001 × 18,273 = 182.9 ≈ `count` 183. ✓

---

# Tab 4 — Explorer

![Explorer tab](docs/screenshots/tab4_explorer.png)

The one genuinely interactive analysis screen: filter all 2,215 rules yourself.
Layout at `app.R:249-274`.

## The filter panel

**Code:** `app.R:251-262`.

| Control | id | Range | Default | Line |
|---|---|---|---|---|
| Min Lift | `exp_min_lift` | 1 → 100, step 0.5 | 1 | `app.R:253` |
| Min Confidence | `exp_min_conf` | 0 → 1, step 0.01 | 0 | `app.R:254` |
| Min Support | `exp_min_supp` | 0 → 0.05, step 0.0005 | 0 | `app.R:255` |
| Max results | `exp_max` | 10 → 2215 | 300 | `app.R:256` |
| Item keyword | `exp_search` | free text | empty | `app.R:258` |
| Apply Filters | `exp_apply` | action button | — | `app.R:260` |

Note the slider *ranges* are chosen to match the data: Min Support tops out at
0.05 because the highest-support rule is 0.0451, and Max results tops out at
2,215 because that is the rule count.

## What happens when you press Apply

**Code:** `observeEvent(input$exp_apply, ...)` at `app.R:644-678`.

The filtering runs on the `arules` rule object directly — not on a data frame —
which is why it stays fast:

```r
q <- quality(d$sig)                                    # 1. pull the measures
keep <- q$lift >= min_lift & q$confidence >= min_conf &
        q$support >= min_supp                          # 2. logical mask
filtered <- d$sig[keep]                                # 3. subset the rules

if (length(filtered) > max_r)                          # 4. cap, sorted by lift
  filtered <- head(sort(filtered, by = "lift", decreasing = TRUE), max_r)

df <- arules::DATAFRAME(filtered, setStart = "", setEnd = "", itemSep = " + ")
names(df)[1:2] <- c("Antecedent", "Consequent")        # 5. convert & rename
df[num] <- lapply(df[num], function(x) round(x, 4))    # 6. round

if (nchar(search) > 0)                                 # 7. keyword filter
  df <- df[grepl(search, paste(df$Antecedent, df$Consequent), ignore.case = TRUE), ]
```

Two behaviours worth knowing:

- **`ignoreNULL = FALSE`** (`app.R:678`) makes the handler fire once at startup,
  which is why the table is already populated with the default 300 rules before
  you touch anything.
- **The cap is applied at step 4, but the keyword search at step 7.** So with
  Max results at its default 300, searching `HEART` searches only within the
  top 300 rules by lift — *not* across all 2,215. Since the top 300 by lift are
  dominated by herb markers, a keyword search can plausibly return nothing while
  matching rules do exist further down. **Raise Max results to 2215 before using
  the keyword box** if you want a true search.

`DATAFRAME(..., setStart = "", setEnd = "", itemSep = " + ")` is what strips the
`{ }` braces and turns `{A,B}` into `A + B` for display.

## Association Network (Top 25 by Lift)  *(static image)*

**Code:** `show_fig("11_rules_graph_top25_lift.png")` at `app.R:268`.
**Produced by:** `R/04_visualize_rules.R` via `arulesViz` with the `igraph` engine.

![Association network](output/figures/11_rules_graph_top25_lift.png)

**How to read it.** Two kinds of node. Labelled nodes are *products*; unlabelled
circles are *rules*. Arrows run product → rule → product, so each small circle
is one rule with its antecedents flowing in and its consequent flowing out.
Circle **size** = support, circle **colour** = lift (deeper red = higher).

**What it says.** A single dense clique of six herb markers, every one connected
to every other. Visually this is the clearest possible statement that the
top-lift rules are one product family rather than 25 independent discoveries.

**This picture does not respond to the sliders above it.** It is a fixed PNG of
the top 25 by lift, regenerated only when the pipeline runs.

## Parallel Coordinates (Top 20 by Confidence)  *(static image)*

**Code:** `show_fig("13_rules_paracoord.png")` at `app.R:272`.
**Produced by:** `R/04_visualize_rules.R`, `method = "paracoord"`.

![Parallel coordinates](output/figures/13_rules_paracoord.png)

**How to read it.** The x-axis is *position within the rule*, read right to
left: column `1` is the item nearest the arrow, `2` the next, `3` the furthest,
and `rhs` is the consequent. Each line traces one rule from its antecedents into
its consequent; arrow width reflects support.

**What it says.** The herb-marker cluster again, plus the REGENCY TEA PLATE
family (GREEN / PINK / ROSES) entering at position 2-3. Because these are the
top rules by *confidence* rather than lift, the tea plates appear here but not
in the lift-ranked network above — a useful reminder that the two rankings
select different rules.

---

# Tab 5 — Segments

![Segments tab](docs/screenshots/tab5_segments.png)

Does the pattern structure change between markets and between seasons? The
answer required re-running Apriori on subsets, in
`R/05_segments_and_recommendations.R`. Layout at `app.R:279-313`.

## The four KPI boxes

| Box | Value | Code | Computation |
|---|---|---|---|
| UK Baskets | 16,506 | `app.R:683` | `n_distinct(InvoiceNo[Country == "United Kingdom"])` |
| International Baskets | 1,767 | `app.R:689` | `n_distinct(InvoiceNo[Country != "United Kingdom"])` |
| UK Top Rules | 25 | `app.R:695` | `nrow(d$uk_rules)` |
| Intl Top Rules | 25 | `app.R:700` | `nrow(d$intl_rules)` |

16,506 + 1,767 = 18,273 ✓ — the segments partition the baskets exactly.

⚠️ **The two "Top Rules" boxes do not show rule counts.** They show the row
count of `05_top_rules_uk.csv` and `05_top_rules_international.csv`, and those
files are deliberately truncated to the top 25 by `to_df(r, n = 25)`
(`R/05_...R:27`). Both will read "25" regardless of what was actually mined. The
real counts are **2,661 (UK)** and **375 (International)**, and they are sitting
in the comparison table immediately to the right. Read that table, not these two
boxes.

## Segment Comparison Summary

**Code:** `tableOutput` at `app.R:290`, `renderTable` at `app.R:706-710`.
**Data:** `output/tables/05_segment_comparison.csv`.

| Segment | Baskets | Products | MinSupport | Rules | MeanLift | MaxLift |
|---|---:|---:|---:|---:|---:|---:|
| UK | 16,506 | 3,760 | 0.01 | 2,661 | 13.13 | 72.66 |
| International | 1,767 | 2,778 | **0.02** | 375 | 9.84 | 37.25 |

**Why International uses support 0.02 and the UK uses 0.01** — this is a
deliberate methodological choice at `R/05_...R:45`:

```r
sup <- if (s == "UK") PARAMS$support else 0.02
```

At 1% support, International would need only 18 baskets to call a pattern
"frequent" — low enough that noise passes as signal. Raising the bar to 2%
requires 35 baskets. The trade-off is that the two rule sets are no longer
strictly comparable, which is exactly why the `MinSupport` column is printed in
the table rather than hidden.

**What it says.** The UK produces 7× more rules from 9× more baskets, with
higher mean lift (13.13 vs 9.84) *despite* the stricter International threshold.
And the products differ: UK rules are herb markers and jumbo bags; International
rules are REGENCY TEA PLATE sets, DOLLY GIRL / SPACEBOY children's tableware,
and SKULL paper party goods — export buyers purchase complete matching sets.

## UK vs International: Baskets & Rules

**Code:** `plotOutput` at `app.R:288`, `renderPlot` at `app.R:711-723`.
**Data:** `05_segment_comparison.csv`, reshaped with `pivot_longer` on the
`Rules` and `Baskets` columns.

⚠️ **This chart is currently broken, and the same bug hits the seasonal chart
below it.** Both bars render grey and no legend appears, so there is no way to
tell which bar is Baskets and which is Rules. The cause is at `app.R:716-717`:

```r
scale_fill_manual(values = c(Rules   = mba_colors["primary"],
                             Baskets = mba_colors["orange"]))
```

`mba_colors` is a *named* vector (`app.R:41-50`), so `mba_colors["primary"]`
carries the name `primary` with it. Wrapping that in `c(Rules = ...)` produces
the compound name `Rules.primary`, not `Rules`:

```r
> names(c(Rules = mba_colors["primary"], Baskets = mba_colors["orange"]))
[1] "Rules.primary"  "Baskets.orange"
```

Those names never match the factor levels `Rules` / `Baskets`, so ggplot finds
no colour for either group and falls back to grey with the legend suppressed.
The one-line fix is to strip the names with `unname()`:

```r
scale_fill_manual(values = c(Rules   = unname(mba_colors["primary"]),
                             Baskets = unname(mba_colors["orange"])))
```

The same fix applies at `app.R:742-743` for `season_bar`.

Until then, read the values from the summary table rather than the bars. For the
record, the four bars are: International 375 rules / 1,767 baskets, UK 2,661
rules / 16,506 baskets — grouped alphabetically, so within each pair the left
bar is Baskets and the right is Rules.

## UK and International rule tables

**Code:** `app.R:294` and `app.R:296`; `renderDT` at `app.R:724-734`.
**Data:** `05_top_rules_uk.csv` and `05_top_rules_international.csv`, 25 rows
each, `pageLength = 8`.

The contrast is the point of the whole tab:

| | UK top rule | International top rule |
|---|---|---|
| Rule | `{HERB MARKER MINT, PARSLEY, THYME} => {HERB MARKER CHIVES}` | `{REGENCY TEA PLATE PINK} => {REGENCY TEA PLATE GREEN}` |
| Support | 0.01018 | 0.02094 |
| Confidence | 0.894 | 0.949 |
| Lift | 72.66 | 37.25 |
| Count | 168 baskets | 37 baskets |

Note the count column: an International rule at 2% support rests on **37
baskets**. It is statistically fine but commercially thin — worth saying out
loud rather than presenting 37.25 lift as equivalent evidence to the UK's 168.

## Seasonal Analysis

**Code:** `tabBox` at `app.R:299-311`; `season_bar` at `app.R:736-749`,
`season_table` at `app.R:750-758`.
**Data:** `05_season_comparison.csv` and `05_festive_only_rules.csv`.

The split is by calendar month (`R/05_...R:74-75`): months 9, 10 and 11 are
"Pre-Christmas (Sep-Nov)", everything else is "Rest of year".

| Season | Baskets | Rules | MeanLift |
|---|---:|---:|---:|
| Pre-Christmas (Sep-Nov) | 6,139 | **5,174** | 11.70 |
| Rest of year | 12,134 | 2,296 | 13.38 |

6,139 + 12,134 = 18,273 ✓

**What it says — and the counter-intuitive bit.** Three months hold 34% of the
baskets but generate **more than twice as many rules** as the other nine months
combined. Two forces produce this:

1. **Genuine seasonal density.** Christmas buyers purchase themed sets —
   decorations, paper chains, gift bags — so co-occurrence is naturally tighter.
2. **A threshold artefact you must not overlook.** Support is relative. 1% of
   6,139 festive baskets is only 61 baskets, while 1% of 12,134 is 121. The
   festive mining is running against a *lower absolute bar*, so patterns pass
   there that would fail in the larger pool. Part of the 5,174 is real
   seasonality and part is the smaller denominator.

Mean lift actually being *lower* in the festive quarter (11.70 vs 13.38) is
consistent with that reading: more rules got through, including weaker ones.

The **Festive-Only Rules** sub-tab lists the 25 exported rules whose labels
appear in the festive set but not in the rest-of-year set — computed by
`labels()` set difference at `R/05_...R:99`.

---

# Tab 6 — Recommender

The only tab where you supply the input. Layout at `app.R:317-372`.

## The empty state

![Recommender tab](docs/screenshots/tab6_recommender.png)

On arrival the results panel reads *"Select at least one item from your
basket."* — produced at `app.R:783-787`. The handler runs at startup because of
`ignoreNULL = FALSE` (`app.R:830`), finds an empty basket, and returns the
message rather than an error.

## With a basket loaded

Here is the same screen after five items from a real invoice are added:

![Recommender with results](docs/screenshots/tab6b_recommender_results.png)

Basket: `HANGING HEART JAR T-LIGHT HOLDER`, `FILIGRIS HEART WITH BUTTERFLY`,
`PAINTED METAL PEARS ASSORTED`, `IVORY HANGING DECORATION HEART`,
`HANGING CHICK GREEN DECORATION`.

| Rank | Recommendation | Lift | Confidence | Support |
|---|---|---:|---:|---:|
| 1 | ASSORTED COLOUR BIRD ORNAMENT | 8.80 | 0.700 | 0.0142 |
| 2 | WHITE HANGING HEART T-LIGHT HOLDER | 2.54 | 0.313 | 0.0124 |

Read row 1 as: *of all baskets containing this antecedent, 70% also contained
ASSORTED COLOUR BIRD ORNAMENT, which is 8.8× more often than baskets in general
contain it.* Both suggestions are hanging/ornamental decorations — the rule set
has correctly identified the theme of the basket.

## The controls

| Control | id | Code | Notes |
|---|---|---|---|
| Items in basket | `recom_items` | `app.R:321-326` | `selectizeInput`, multiple, max 20 items |
| Get Recommendations | `recom_go` | `app.R:327` | triggers `app.R:772` |
| Sample 1 / 2 / 3 | `recom_s1/2/3` | `app.R:332-337` | handlers at `app.R:832/844/856` |

The dropdown is populated **server-side** (`app.R:460-466`):

```r
choices <- sort(unique(d$retail$Item))
updateSelectizeInput(session, "recom_items", choices = choices, server = TRUE)
```

`server = TRUE` matters: with 3,765 product names, sending the whole list to the
browser would bloat the page, so selectize queries the server as you type.

The **Sample** buttons draw a real basket from `transactions.rds` rather than
inventing one. Each uses a fixed seed, so they are reproducible:

| Button | Seed | Basket size filter | Line |
|---|---|---|---|
| Sample 1 | `set.seed(7)` | 3-8 items | `app.R:832` |
| Sample 2 | `set.seed(42)` | 3-8 items | `app.R:844` |
| Sample 3 | `set.seed(99)` | 4-10 items | `app.R:856` |

Each takes the first 5 items of the sampled basket
(`basket[1:min(5, length(basket))]`).

## The recommendation algorithm

**Code:** `observeEvent(input$recom_go, ...)` at `app.R:772-830`. This is the
same logic as `recommend()` in `R/05_segments_and_recommendations.R:106-118`,
reimplemented in the app so it can run against live input.

```r
LHS_LIST <- as(lhs(sig), "list")            # antecedent of every rule, as a list
RHS_ITEM <- unlist(as(rhs(sig), "list"))    # consequent of every rule
QUAL     <- quality(sig)

fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
```

Step by step:

1. **Fire test** — a rule fires only if its *entire* antecedent is inside your
   basket (`all(l %in% basket)`). Partial matches do not count.
2. **Collect** the consequents of every firing rule with their confidence, lift
   and support.
3. **Drop items you already have** — `rec[!rec$Recommendation %in% basket, ]`.
   A recommender that suggests what is already in the trolley is useless.
4. **Rank by lift descending** — `rec[order(-rec$Lift), ]`.
5. **Deduplicate** — `rec[!duplicated(rec$Recommendation), ]`. Several rules can
   point at the same product; only its best-lift rule survives.
6. **Top 10**, then add a `Rank` column.

There are four distinct failure messages, and each is a different situation —
worth knowing which one you are looking at:

| Message | Line | Meaning |
|---|---|---|
| "Rules not loaded. Run the pipeline first." | `app.R:775` | `rules_significant.rds` missing |
| "Select at least one item from your basket." | `app.R:783` | empty basket |
| "No rules fired for this combination of items." | `app.R:796` | no rule's antecedent is fully contained |
| "All recommendations are already in your basket!" | `app.R:814` | rules fired, but step 3 emptied the list |

The third is common and is not a defect: with only 2,215 rules covering 3,765
products, most arbitrary baskets match nothing. Ranking by **lift** rather than
confidence is also a deliberate choice — confidence alone would keep suggesting
WHITE HANGING HEART T-LIGHT HOLDER to everybody, because it is in 12% of
baskets to begin with. Lift divides that popularity out.

## The "How the Recommender Works" panel

`app.R:344-370` — static explanatory content, not computed. The three coloured
boxes (Lift / Confidence / Support) are `renderValueBox` calls returning fixed
strings at `app.R:762-770`; they are labels, not readouts.

⚠️ The sentence "matches your basket against **2,215 significant association
rules**" at `app.R:346` is **hard-coded text**. Re-run the pipeline with a
different support threshold and this number will silently be wrong while the
Overview KPI beside it updates correctly. The same hard-coding appears at
`app.R:256` as the `max` of the Max-results input. Both should read
`length(d$sig)`.

---

# Tab 7 — Cross-Sell

![Cross-Sell tab](docs/screenshots/tab7_crosssell.png)

The tab that converts statistics into pounds. Layout at `app.R:375-412`; all
figures come from `output/tables/05_cross_sell_best_rule_per_product.csv`,
built in `R/05_segments_and_recommendations.R:150-200`.

## The four KPI boxes

| Box | Value | Code | Computation |
|---|---|---|---|
| Total Revenue Opportunity | GBP 1,017,501 | `app.R:872` | `sum(cs_best$PotentialRevenue)` |
| Best Single Opportunity | GBP 24,625 | `app.R:885` | `max(PotentialRevenue)` |
| Average Lift | 17.8x | `app.R:898` | `mean(cs_best$Lift)` |
| Products with Opportunity | 238 | `app.R:908` | `nrow(cs_best)` |

**Why Average Lift is 17.8x here but mean lift is 12.97 on the Rules tab.** Two
different populations, both correct. The Rules tab averages all 2,215 rules;
this box averages the 238 rules that survived best-per-product deduplication.
Keeping only each product's strongest rule selects for high lift, so the mean
rises. If you are asked about the discrepancy, that is the answer.

## The opportunity formula

The chain runs, per rule (`R/05_...R:158-175`):

```
MissedBaskets    = round( (coverage - support) x N )      N = 18,273
ExpectedUplift   = MissedBaskets x Confidence
PotentialRevenue = ExpectedUplift x AvgPrice x AvgQty
```

`coverage` is P(LHS) and `support` is P(LHS ∩ RHS), so `coverage - support` is
precisely the fraction of baskets that **took the antecedent but not the
consequent** — the missed opportunities. The script notes this explicitly and
avoids scanning every basket:

> *"No basket scan needed: coverage is supp(LHS) and support is supp(LHS ∪ RHS),
> so baskets holding the LHS but missing the RHS = (coverage − support) × N."*

`AvgPrice` and `AvgQty` come from a per-item summary of the cleaned data
(`mean(UnitPrice)` and `mean(Quantity)`), joined on the consequent.

**Worked example — the top row, GBP 24,625:**

Rule: `{ROSES REGENCY TEACUP AND SAUCER} => {REGENCY CAKESTAND 3 TIER}`

| Quantity | Value | Where from |
|---|---:|---|
| support | 0.02873 | rule quality |
| confidence | 0.494 | rule quality |
| coverage | 0.05815 | = support ÷ confidence |
| coverage − support | 0.02942 | |
| × N = 18,273 | **537** | `MissedBaskets` |
| × confidence 0.494 | **265** | `ExpectedUplift` |
| AvgPrice | GBP 13.98 | mean unit price of the cakestand |
| AvgQty | 6.64 | mean units per line |
| 265.28 × 13.98 × 6.64 | **GBP 24,625.28** | `PotentialRevenue` |

In plain terms: 537 baskets bought the teacup and saucer without the cakestand;
if the rule's 49.4% success rate held when prompted, 265 of them would convert,
and each conversion is worth about GBP 93.

## The double-counting problem, and how it was handled

This is the most defensible piece of reasoning in the project, and it is worth
knowing because the honest number is much smaller than the flattering one.

Summing `PotentialRevenue` over all 2,215 rules gives **GBP 7,553,161** — which
would be 78% of total annual revenue, obviously absurd. Rules overlap heavily:
dozens share a consequent and would fire on the same basket, so the same missed
sale is counted many times over.

The fix (`R/05_...R:188-194`) keeps, for each consequent product, only its
single best rule:

```r
best_per_consequent <- value_df |>
  group_by(Consequent) |>
  slice_max(PotentialRevenue, n = 1, with_ties = FALSE) |>
  ungroup()
```

| Estimate | Value | Status |
|---|---:|---|
| Naive sum over all 2,215 rules | GBP 7,553,161 | upper bound, double-counted |
| **Best rule per consequent (238 products)** | **GBP 1,017,501** | the figure shown |
| Top 20 of those products |  GBP 255,319 | 25.1% of the total |

GBP 1.02M is ~10.5% of the GBP 9.66M actual revenue — a plausible cross-sell
headroom rather than a fantasy.

**Still read it as a ceiling, not a forecast.** The model assumes every prompted
customer converts at exactly the rule's historical confidence, that prompting
adds sales rather than shifting them, and that average price and quantity hold.
None of those are guaranteed. It is the size of the prize if execution were
perfect.

## Top 15 Cross-Sell Opportunities  *(static image)*

**Code:** `show_fig("15_cross_sell_opportunity_value.png")` at `app.R:385`.
**Produced by:** `R/05_...R:203-216` — bar length = PotentialRevenue,
fill = Lift.

![Cross-sell opportunities](output/figures/15_cross_sell_opportunity_value.png)

**What it says, and why this is the tab that matters.** Compare this list with
the Top-20-by-lift chart on the Rules tab: **not a single herb marker appears
here.** Once you weight by money, the actionable opportunities are teacups and
cakestands, jumbo bags, bunting, and Christmas paper chains.

The colour scale carries the second lesson. The two darkest bars (highest lift,
~10.7) are the PAPER CHAIN KIT pair, yet they rank 8th and 14th by revenue. The
longest bar — the cakestand at GBP 24,625 — has a lift of only 4.6. **High lift
and high value are largely independent**, and ranking by lift alone would have
sent the merchandising team after the wrong products.

## All Cross-Sell Opportunities (table)

**Code:** controls at `app.R:392-406`, `renderDT` at `app.R:918-948`.

| Control | id | Options |
|---|---|---|
| Sort by | `cs_sort` | PotentialRevenue (default), Lift, Confidence, MissedBaskets |
| Min Lift | `cs_minlift` | Any (default), 1.5, 2, 3, 5, 10 |

The table shows all **238** rows of `cs_best` — the chart above is just its top
15. Long `Rule` strings are truncated to 75 characters and `Consequent` to 40
for display (`app.R:934-941`); the underlying values are untouched.

The first rows, exactly as rendered:

| Rule | Support | Conf | Lift | Missed | AvgPrice | AvgQty | Uplift | Revenue |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| {ROSES REGENCY TEACUP AND SAUCER} ⇒ {REGENCY CAKESTAND 3 TIER} | 0.02873 | 0.494 | 4.60 | 537 | 13.98 | 6.64 | 265 | 24,625.28 |
| {JUMBO BAG RED RETROSPOT} ⇒ {JUMBO BAG PINK POLKADOT} | 0.04515 | 0.398 | 5.98 | 1,248 | 2.61 | 17.27 | 497 | 22,351.25 |
| {LUNCH BAG RED RETROSPOT} ⇒ {JUMBO BAG RED RETROSPOT} | 0.03169 | 0.370 | 3.26 | 985 | 2.49 | 22.20 | 364 | 20,174.87 |
| {SPOTTY BUNTING} ⇒ {PARTY BUNTING} | 0.02643 | 0.423 | 4.63 | 659 | 5.81 | 10.13 | 279 | 16,405.80 |
| {JUMBO BAG RED RETROSPOT} ⇒ {JUMBO STORAGE BAG SUKI} | 0.03962 | 0.349 | 5.39 | 1,349 | 2.75 | 11.50 | 471 | 14,888.68 |

Rows 1 and 2 illustrate the two routes to the same outcome: the cakestand
converts *fewer* baskets (265 vs 497) but each is worth GBP 93 against GBP 45,
so it still wins. Volume and value both matter, and this table lets you sort by
either.

---

# Part 8 — Formula reference

Everything the dashboard computes, in one place. `N` = 18,273 baskets.

## The three association measures

| Measure | Formula | Range | Reading |
|---|---|---|---|
| **Support** | supp(X) = count(X) / N | 0-1 | how common the pattern is overall |
| **Confidence** | conf(X⇒Y) = supp(X ∪ Y) / supp(X) = P(Y\|X) | 0-1 | how often the rule is right when it fires |
| **Lift** | lift(X⇒Y) = conf(X⇒Y) / supp(Y) | 0-∞ | times better than chance; 1 = independent |
| **Coverage** | cov(X⇒Y) = supp(X) | 0-1 | how often the rule applies at all |
| **Count** | count = supp(X ∪ Y) × N | integer | absolute baskets |

Lift is symmetric — lift(X⇒Y) = lift(Y⇒X) — while confidence is not. That is why
you see mirrored pairs like the two PAPER CHAIN KIT rules with identical lift
(10.72) but different confidence (0.479 and 0.676).

## The Apriori property

> Every subset of a frequent itemset is itself frequent.

Equivalently: if an itemset is infrequent, every superset of it is infrequent
too, and can be pruned without testing. This is what makes the search tractable
— and, as the threshold-sensitivity chart shows, it is why support is a far
more powerful lever than confidence.

Frequent itemsets found at support ≥ 0.01
(`output/tables/03_frequent_itemset_counts.csv`):

| Itemset size | Count |
|---|---:|
| 1 | 898 |
| 2 | 1,192 |
| 3 | 389 |
| 4 | 45 |

The rise from size 1 to 2 and the collapse after is the pruning working. Of the
3,765 products, only 898 clear 1% support on their own; `maxlen = 4` caps the
search there.

Rules by total size (LHS + RHS): 909 of size 2, 1,126 of size 3, 180 of size 4.

## Statistical significance

For each rule, a 2×2 contingency table of LHS present/absent × RHS
present/absent, tested with **Fisher's exact test**, then corrected across all
rules with **Benjamini-Hochberg** to control the false discovery rate:

```r
quality(rules)$fishersPValue <- interestMeasure(rules, "fishersExactTest",
                                                transactions = trans)
quality(rules)$pAdjusted     <- p.adjust(quality(rules)$fishersPValue, "BH")
sig_rules <- subset(rules, pAdjusted < 0.05)
```

With 2,215 tests, an uncorrected 5% threshold would admit ~111 false positives
by chance alone; BH controls that. In this dataset all 2,215 rules passed.

## The cross-sell chain

```
MissedBaskets    = (coverage - support) x N
ExpectedUplift   = MissedBaskets x confidence
PotentialRevenue = ExpectedUplift x AvgPrice x AvgQty
Total            = sum over the best rule per consequent product
```

---

# Part 9 — Things worth knowing (quirks and gotchas)

Collected from reading the code and driving the running app. The first one will
cost you an hour if you hit it unaware.

### ⚠️ 1. Launching the app can silently re-run the entire pipeline

`app.R:6` sets `options(shiny.autoload.r = FALSE)`, but that line executes
*after* Shiny has already decided whether to auto-load `R/*.R`. Running
`shiny::runApp(".")` therefore sources all five pipeline scripts before the app
starts — re-reading the 46 MB Excel file and rewriting `output/`. Verified
directly:

| Invocation | Sources `R/*.R`? |
|---|---|
| `shiny::runApp(".")` | **yes** — full pipeline re-runs |
| `options(shiny.autoload.r = FALSE); shiny::runApp(".")` | no |

**Launch it this way:**

```r
options(shiny.autoload.r = FALSE)
shiny::runApp(".", port = 3838, launch.browser = FALSE)
```

A permanent fix is to move the option out of `app.R` into a `.Rprofile` at the
project root, where it is set before Shiny loads.

### ⚠️ 2. Two bar charts render grey with no legend

`seg_bar` (`app.R:711`) and `season_bar` (`app.R:736`) pass a named colour
vector into `scale_fill_manual()`, producing the names `Rules.primary` and
`Baskets.orange`, which never match the factor levels. Both charts lose their
colour coding and legend. Fix with `unname()` — see the Segments section for
the full explanation.

### ⚠️ 3. "UK Top Rules: 25" is not a rule count

Both Segments rule-count boxes show `nrow()` of a CSV that was deliberately
truncated to 25 rows. The real counts (2,661 and 375) are in the comparison
table beside them.

### ⚠️ 4. Explorer caps before it searches

Max results is applied to the lift-sorted rules *before* the keyword filter runs,
so a keyword search with the default cap of 300 only searches the top 300 rules.
Set Max results to 2215 first.

### ⚠️ 5. Two hard-coded rule counts

`app.R:256` (`max = 2215`) and `app.R:346` ("2,215 significant association
rules") are literals. Re-run the pipeline with different parameters and they go
stale while the Overview KPI updates. Both should be derived from `length(d$sig)`.

### 6. December 2011 is nine days, not a month

The data ends 2011-12-09. The short final bar on the monthly chart is a
truncated month, not a demand collapse.

### 7. The dataset has no Saturdays

The weekday × hour heatmap shows Mon-Fri and Sun. Saturday is absent from the
source data entirely.

### 8. p-value columns display as 0

Rounded to 5 decimals at `R/03_apriori.R:134`. The true values are far below
1e-5.

### 9. The top rules are a product family, not a behaviour

Every one of the top 20 rules by lift is a HERB MARKER combination — six
variants of one product sold as a set. Statistically valid, commercially inert.
This is precisely why the Cross-Sell tab ranks by revenue, and why no herb
marker appears in its top 15.

### 10. Static images ignore the controls next to them

Six panels are pre-rendered PNGs (see §0.2). Most notably, the Explorer's
network diagram and parallel-coordinates plot do not respond to its sliders.
They change only when `R/04_visualize_rules.R` is re-run.

### 11. The two segments were mined at different thresholds

UK at 1% support, International at 2% (`R/05_...R:45`). The rule counts are
therefore not directly comparable — the `MinSupport` column exists to keep that
visible.

### 12. Some International rules rest on ~37 baskets

At 2% support of 1,767 baskets, the minimum evidence behind a rule is about 35
transactions. Statistically admissible, commercially thin.

---

# Appendix A — Panel-to-code index

Every visible element, with the line that creates it.

| Tab | Panel / control | UI line | Server line | Data source |
|---|---|---|---|---|
| Overview | Baskets KPI | `app.R:173` | `app.R:471` | `retail_clean.rds` |
| Overview | Unique Products KPI | `app.R:174` | `app.R:478` | `retail_clean.rds` |
| Overview | Significant Rules KPI | `app.R:175` | `app.R:485` | `rules_significant.rds` |
| Overview | Total Revenue KPI | `app.R:176` | `app.R:492` | `retail_clean.rds` |
| Overview | Monthly Revenue Trend | `app.R:180` | `app.R:500` | `02_monthly_sales.csv` |
| Overview | Top 10 Products | `app.R:182` | `app.R:512` | `02_top50_items_by_frequency.csv` |
| Overview | Weekday × Hour heatmap | `app.R:186` | `app.R:526` | `retail_clean.rds` (live) |
| Overview | Top Countries | `app.R:188` | `app.R:538` | `02_by_country.csv` |
| Exploratory | Top-N frequency selector | `app.R:198` | — | — |
| Exploratory | Top-N frequency plot | `app.R:200` | `app.R:553` | `02_top50_items_by_frequency.csv` |
| Exploratory | Top-N revenue selector | `app.R:202` | — | — |
| Exploratory | Top-N revenue plot | `app.R:204` | `app.R:569` | `02_top50_items_by_revenue.csv` |
| Exploratory | Basket size histogram | `app.R:208` | `app.R:582` | `retail_clean.rds` (live) |
| Exploratory | Relative item frequency | `app.R:210` | static | `07_item_frequency_relative.png` |
| Rules | Threshold sensitivity | `app.R:221` | static | `08_threshold_sensitivity.png` |
| Rules | Rule Statistics | `app.R:223` | `app.R:599` | `rules_significant.rds` |
| Rules | Top 20 by lift | `app.R:231` | static | `14_top_rules_by_lift_bars.png` |
| Rules | Support vs confidence | `app.R:234` | static | `09_rules_scatter.png` |
| Rules | Table: By Lift | `app.R:238` | `app.R:616` | `03_top_rules_by_lift.csv` |
| Rules | Table: By Confidence | `app.R:239` | `app.R:623` | `03_top_rules_by_confidence.csv` |
| Rules | Table: By Support | `app.R:240` | `app.R:629` | `03_top_rules_by_support.csv` |
| Rules | Table: All Rules | `app.R:241` | `app.R:635` | `03_all_significant_rules.csv` |
| Explorer | Min Lift slider | `app.R:253` | `app.R:644` | — |
| Explorer | Min Confidence slider | `app.R:254` | `app.R:644` | — |
| Explorer | Min Support slider | `app.R:255` | `app.R:644` | — |
| Explorer | Max results | `app.R:256` | `app.R:644` | — |
| Explorer | Item keyword | `app.R:258` | `app.R:644` | — |
| Explorer | Apply Filters | `app.R:260` | `app.R:644` | — |
| Explorer | Filtered rules table | `app.R:264` | `app.R:670` | `rules_significant.rds` |
| Explorer | Association network | `app.R:268` | static | `11_rules_graph_top25_lift.png` |
| Explorer | Parallel coordinates | `app.R:272` | static | `13_rules_paracoord.png` |
| Segments | UK Baskets KPI | `app.R:281` | `app.R:683` | `retail_clean.rds` |
| Segments | Intl Baskets KPI | `app.R:282` | `app.R:689` | `retail_clean.rds` |
| Segments | UK Top Rules KPI | `app.R:283` | `app.R:695` | `05_top_rules_uk.csv` (row count) |
| Segments | Intl Top Rules KPI | `app.R:284` | `app.R:700` | `05_top_rules_international.csv` |
| Segments | Baskets & Rules bars | `app.R:288` | `app.R:711` | `05_segment_comparison.csv` |
| Segments | Comparison summary | `app.R:290` | `app.R:706` | `05_segment_comparison.csv` |
| Segments | UK rules table | `app.R:294` | `app.R:724` | `05_top_rules_uk.csv` |
| Segments | Intl rules table | `app.R:296` | `app.R:730` | `05_top_rules_international.csv` |
| Segments | Season bars | `app.R:303` | `app.R:736` | `05_season_comparison.csv` |
| Segments | Festive-only rules | `app.R:308` | `app.R:750` | `05_festive_only_rules.csv` |
| Recommender | Item selector | `app.R:321` | `app.R:460` | `retail_clean.rds` |
| Recommender | Get Recommendations | `app.R:327` | `app.R:772` | `rules_significant.rds` |
| Recommender | Sample 1 / 2 / 3 | `app.R:332-337` | `app.R:832/844/856` | `transactions.rds` |
| Recommender | Results table | `app.R:341` | `app.R:775-829` | computed live |
| Recommender | Lift/Conf/Supp boxes | `app.R:353-355` | `app.R:762-770` | static labels |
| Cross-Sell | Total Opportunity KPI | `app.R:377` | `app.R:872` | `05_cross_sell_best_rule_per_product.csv` |
| Cross-Sell | Best Single KPI | `app.R:378` | `app.R:885` | same |
| Cross-Sell | Average Lift KPI | `app.R:379` | `app.R:898` | same |
| Cross-Sell | Products KPI | `app.R:380` | `app.R:908` | same |
| Cross-Sell | Top 15 chart | `app.R:385` | static | `15_cross_sell_opportunity_value.png` |
| Cross-Sell | Sort by | `app.R:392` | `app.R:918` | — |
| Cross-Sell | Min Lift | `app.R:402` | `app.R:918` | — |
| Cross-Sell | Opportunities table | `app.R:408` | `app.R:918` | `05_cross_sell_best_rule_per_product.csv` |

# Appendix B — Which script writes which file

| Script | Figures | Tables | Objects |
|---|---|---|---|
| `R/01_load_clean.R` | — | `01_data_quality_audit`, `01_cleaning_summary` | `retail_clean.rds/.csv` |
| `R/02_eda.R` | `01`-`06` | `02_top50_items_by_frequency`, `02_top50_items_by_revenue`, `02_basket_size_stats`, `02_monthly_sales`, `02_by_country` | — |
| `R/03_apriori.R` | `07`, `08` | `03_frequent_itemset_counts`, `03_top30_frequent_itemsets`, `03_top_multi_item_itemsets`, `03_all_significant_rules`, `03_top_rules_by_{lift,confidence,support}`, `03_threshold_sensitivity`, `03_transactions_summary.txt` | `transactions.rds`, `rules.rds`, `rules_significant.rds`, `itemsets.rds` |
| `R/04_visualize_rules.R` | `09`-`14` | `04_rules_leading_to_top_item`, `04_rules_from_top_item` | — |
| `R/05_segments_and_recommendations.R` | `15` | `05_segment_comparison`, `05_top_rules_{uk,international,prechristmas,restofyear}`, `05_season_comparison`, `05_festive_only_rules`, `05_recommender_demo`, `05_cross_sell_opportunity_value`, `05_cross_sell_best_rule_per_product` | — |

Figures `10` (two-key plot) and `12` (grouped matrix) are generated by
`04_visualize_rules.R` but are **not displayed anywhere in the dashboard** — they
exist in `output/figures/` only.

---

*Screenshots captured from the live app; every figure and number verified
against the current contents of `data/processed/` and `output/`.*
