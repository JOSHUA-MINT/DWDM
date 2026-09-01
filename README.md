# Market Basket Analysis of Online Retail Transactions

Apriori and association rule mining on the **UCI Online Retail** dataset
([UCI ML Repository #352](https://archive.ics.uci.edu/dataset/352/online+retail)),
implemented in R with `arules` and `arulesViz`.

The dataset holds every transaction of a UK-based online giftware retailer
between **1 Dec 2010 and 9 Dec 2011** — 541,909 rows, 4,070 stock codes,
38 countries.

---

## Quick start

1. Open **`DWDM.Rproj`** in RStudio (this sets the working directory correctly).
2. Install the packages once:
   ```r
   source("R/00_setup.R")
   ```
3. Run everything:
   ```r
   source("run_all.R")
   ```

The first run downloads `Online Retail.xlsx` (23 MB) from UCI automatically and
caches it in `data/raw/`. After that the whole pipeline takes **under a minute**
(measured: 01 = 23 s reading the Excel file, 02 = 3 s, 03 = 9 s, 04 = 3 s,
05 = 11 s). Add a few minutes on the very first run for the download and package
installation.

To produce the written report, open `report/MBA_Report.Rmd` in RStudio and press
**Knit** (RStudio ships the pandoc that rendering needs). It reads the saved
`.rds` objects and CSVs, so run the pipeline first. From a plain `Rscript` you
need pandoc on `PATH`:

```r
rmarkdown::render("report/MBA_Report.Rmd")
```

**From a terminal instead of RStudio:**

```bash
Rscript run_all.R
```

---

## Project layout

```
DWDM/
├── DWDM.Rproj                  RStudio project
├── run_all.R                   Runs the whole pipeline end to end
├── R/
│   ├── 00_setup.R              Packages, paths, PARAMS, plot theme
│   ├── 01_load_clean.R         Download, quality audit, cleaning
│   ├── 02_eda.R                Exploratory analysis and 6 figures
│   ├── 03_apriori.R            Frequent itemsets + rules + significance tests
│   ├── 04_visualize_rules.R    Rule visualisation, targeted rule mining
│   └── 05_segments_and_recommendations.R
│                               Segment/season comparison, recommender, ROI
├── data/
│   ├── raw/                    Online Retail.xlsx (downloaded, gitignored)
│   └── processed/              retail_clean.rds, transactions.rds, rules.rds
├── output/
│   ├── figures/                15 PNGs
│   └── tables/                 ~25 CSVs
└── report/
    └── MBA_Report.Rmd          Full written report (knits to HTML)
```

Each script is self-contained: it `source()`s `00_setup.R` and reads its input
from `data/processed/`, so you can re-run any single stage without the others
(after `01` has run at least once).

---

## Tuning the analysis

Every threshold lives in one place — `PARAMS` in [`R/00_setup.R`](R/00_setup.R):

```r
PARAMS <- list(
  support    = 0.01,   # minimum support   (1% of baskets)
  confidence = 0.30,   # minimum confidence
  minlen     = 2,      # at least one item on each side
  maxlen     = 4,      # keep itemsets interpretable
  min_lift   = 1.0,    # only rules better than chance
  top_n      = 20      # rows in the top-N tables and plots
)
```

Support is the parameter that matters. `output/tables/03_threshold_sensitivity.csv`
shows how the rule count reacts across a 5×5 grid of support and confidence —
rule count falls roughly geometrically as support rises, while confidence merely
trims an already-determined pool.

---

## Method

### Cleaning

| Removed | Why |
|---|---|
| `InvoiceNo` starting with `C` | Cancellations — returns, not purchases |
| `Quantity <= 0`, `UnitPrice <= 0` | Returns, adjustments, free samples |
| `POST`, `DOT`, `M`, `BANK CHARGES`, `AMAZONFEE`, … | Postage and admin lines, not products |
| `?`, `damaged`, `check`, `found`, `lost`, … | Warehouse free-text notes |
| Missing `Description` | Unusable as an item label |
| Duplicate item lines within an invoice | One row per product per basket |
| Single-item baskets | Carry no co-occurrence information |

Each `StockCode` is also pinned to one canonical description, since descriptions
drift across rows for the same product.

**Result:** 515,784 rows retained (95.2%) → **18,273 baskets × 3,765 products**,
mean basket size 28.2, median 17.

### Mining

Apriori at 1% support / 30% confidence, then four filters:

1. `lift > 1` — discard rules no better than chance
2. `is.redundant()` — drop rules whose antecedent adds nothing over a more
   general rule with equal or better confidence
3. Fisher's exact test on each rule's 2×2 contingency table
4. Benjamini–Hochberg correction, keeping `p < 0.05`

**2,215 rules survive.**

### The three measures

| Measure | Formula | Reads as |
|---|---|---|
| Support | `P(X ∪ Y)` | How common the pattern is |
| Confidence | `P(Y \| X)` | How reliable it is |
| Lift | `P(X ∪ Y) / (P(X)·P(Y))` | How much better than chance |

Lift is the primary ranking measure throughout. Confidence alone is misleading
here: any rule pointing at `WHITE HANGING HEART T-LIGHT HOLDER` scores well
simply because that product sits in over 12% of all baskets.

---

## Headline findings

**Products sell as families, not individuals.** The highest-lift rules cluster
inside product sets — herb markers, the regency tea range, the retrospot bag
colourways, the woodland/spaceboy children's line. Lift values reach 75×: a
customer holding two herb markers is overwhelmingly likely to be completing the
set.

**Colourway substitution is predictable.** Rules link the same product across
colours (red / pink / blue retrospot). Stock-outs on one variant depress the
whole cluster.

**Association structure is seasonal.** The Sep–Nov festive quarter produces more
rules from *fewer* baskets than the rest of the year combined, with thousands
that exist only in that window. The rule set needs re-mining quarterly.

**Segments differ.** UK and international baskets have measurably different
association structures and need separate rule sets.

**The commercial read.** The largest cross-sell gaps are *not* the highest-lift
rules. Ranking every rule by the revenue it leaves on the table gives about
**GBP 1.02M of headroom** (best rule per product, ~10% of realised revenue), and
it is led by mid-lift, high-support rules on expensive items -- `ROSES / GREEN
REGENCY TEACUP AND SAUCER` => `REGENCY CAKESTAND 3 TIER` has a lift of only 4.6
but fires on hundreds of baskets against a high-ticket product. Lift finds the
pattern; support and price decide whether it is worth acting on.


Full discussion, limitations, and proposed extensions are in
[`report/MBA_Report.Rmd`](report/MBA_Report.Rmd).

---

## Outputs

**Figures** (`output/figures/`)

| File | Content |
|---|---|
| `01`–`02` | Top products by basket frequency and by revenue |
| `03` | Basket size distribution |
| `04`–`05` | Monthly revenue; weekday × hour trading heatmap |
| `06` | Top 10 countries by revenue |
| `07` | Relative item frequency (`arules`) |
| `08` | Rule count across the support × confidence grid |
| `09`–`10` | Rule scatter (support / confidence / lift); two-key plot |
| `11` | Association network of the top 25 rules by lift |
| `12`–`13` | Grouped matrix; parallel coordinates |
| `14` | Top 20 rules by lift |
| `15` | Top 15 cross-sell opportunities by estimated revenue |

**Key tables** (`output/tables/`)

| File | Content |
|---|---|
| `01_data_quality_audit.csv` | Raw-data problem counts |
| `01_cleaning_summary.csv` | Before/after cleaning metrics |
| `03_all_significant_rules.csv` | All 2,215 surviving rules |
| `03_top_rules_by_{lift,confidence,support}.csv` | Top 20 under each measure |
| `03_threshold_sensitivity.csv` | Rule count across the parameter grid |
| `05_segment_comparison.csv` | UK vs international |
| `05_season_comparison.csv`, `05_festive_only_rules.csv` | Seasonal shift |
| `05_recommender_demo.csv` | Recommender output on three real baskets |
| `05_cross_sell_opportunity_value.csv` | Every rule priced as an opportunity |
| `05_cross_sell_best_rule_per_product.csv` | Deduplicated headroom estimate |

---

## Requirements

R ≥ 4.1 (the native `|>` pipe is used throughout). Packages, installed
automatically by `R/00_setup.R`:

`readxl`, `dplyr`, `tidyr`, `lubridate`, `ggplot2`, `scales`, `RColorBrewer`,
`arules`, `arulesViz`

---

## References

Agrawal, R. & Srikant, R. (1994). *Fast Algorithms for Mining Association Rules*. VLDB.

Hahsler, M., Grün, B. & Hornik, K. (2005). *arules — A Computational Environment
for Mining Association Rules and Frequent Item Sets*. JSS 14(15).

Chen, D., Sain, S. L. & Guo, K. (2012). *Data mining for the online retail
industry*. Journal of Database Marketing & Customer Strategy Management 19(3).
# DWDM
