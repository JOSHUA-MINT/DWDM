# Basket Lens — Market Basket Analysis Project Report

## 1. Project Title

**Basket Lens: Market Basket Analysis of Online Retail Transactions Using Association Rule Mining**

---

## 2. Problem Statement & Objectives

### What Problem Are We Solving?

When you shop online — think of a store like a gift shop or a supermarket — you often buy multiple items in one order (one "basket" or "cart"). The store wants to know:

- **Which products are frequently bought together?** If someone buys product A, what else are they likely to buy?
- **How can we use this knowledge to increase sales?** For example, placing related items near each other, suggesting products during checkout, or creating targeted promotions.
- **How does customer behavior differ across regions or seasons?** Do UK customers buy different product combinations than international customers? Do people buy different things before Christmas?

### Objectives

1. Clean and prepare a large, real-world retail transaction dataset
2. Explore the data to find patterns in sales, customer behavior, and popular products
3. Mine **association rules** — the "if you buy X, you will also buy Y" patterns
4. Quantify the **revenue opportunity** hidden in these patterns
5. Build an **interactive dashboard** (GUI) that lets anyone explore the rules, run a recommender, and see business insights — no coding needed

### Expected Outcome

- A set of statistically significant association rules (2,215 rules)
- An estimate of GBP 1.02 million in untapped cross-sell revenue
- A working Shiny dashboard ("Basket Lens") with 7 interactive sections

---

## 3. Dataset Description

### Source

The **UCI Online Retail dataset** (UCI ML Repository #352) — a well-known benchmark dataset used in data mining research.

### What Is In The Dataset?

| Attribute | Description |
|---|---|
| `InvoiceNo` | Unique ID for each transaction (basket) |
| `StockCode` | Unique product code |
| `Description` | Product name |
| `Quantity` | Number of units purchased |
| `InvoiceDate` | Date and time of the purchase |
| `UnitPrice` | Price per unit (in GBP) |
| `CustomerID` | Customer identifier |
| `Country` | Customer's country |

### Key Facts

| Metric | Value |
|---|---|
| Original rows | 541,909 |
| Date range | 1 Dec 2010 to 9 Dec 2011 |
| Products (StockCodes) | 4,070 |
| Countries | 38 |
| After cleaning | 515,784 rows (95.2% retained) |
| Unique baskets (transactions) | 18,273 |
| Unique products after cleaning | 3,765 |
| Mean basket size | 28.2 items |
| Median basket size | 17 items |
| Total revenue | ~GBP 9.66 million |

### The Business

The dataset belongs to a **UK-based online giftware retailer** that sells decorative household items — things like candle holders, teacups, party decorations, bags, and children's accessories. It sells to customers in 38 countries, but the majority are in the UK.

---

## 4. Data Preprocessing

Raw data is messy. Before we can analyze it, we need to clean it. Here is everything we did:

### Step 1: Download & Load
- The dataset is downloaded from UCI as a `.zip` file (23 MB).
- It is extracted and read from an Excel (`.xlsx`) file using the `readxl` package.

### Step 2: Data Quality Audit
We first counted how many problems exist in the raw data:

| Problem | Count |
|---|---|
| Missing product descriptions | Some rows |
| Cancelled invoices (InvoiceNo starts with "C") | Many rows |
| Quantity <= 0 (returns, free samples) | Many rows |
| UnitPrice <= 0 (adjustments, bad debt) | Many rows |
| Admin/postage stock codes (POST, DOT, BANK CHARGES, etc.) | Many rows |
| Warehouse free-text notes (like "?","damaged","found") | Many rows |
| Duplicate rows within an invoice | Some rows |

### Step 3: Cleaning Rules

We removed the following rows:

1. **Cancellations** — Invoice numbers starting with "C" represent returns/cancellations, not purchases.
2. **Negative/zero quantity** — These are returns, adjustments, or free samples, not real purchases.
3. **Negative/zero unit price** — Not valid product sales.
4. **Admin/fee stock codes** — Stock codes like `POST`, `DOT`, `D`, `M`, `BANK CHARGES`, `AMAZONFEE`, `gift_0001_10`, etc., represent postage, bank charges, or gift card fees — not actual products.
5. **Junk descriptions** — Rows where the product description is `?`, `damaged`, `check`, `found`, `lost`, `adjustment`, `test`, `samples`, `wrongly`, etc. These are warehouse notes, not products.
6. **Missing descriptions** — We cannot use a row as a product if we don't know what it is.
7. **Duplicate items within a basket** — If the same product appears twice in one invoice, we keep only one row per product per basket.
8. **Single-item baskets** — A basket with only one product carries no co-occurrence information (we need at least 2 items to learn what goes together).

### Step 4: Canonical Product Names
The same product sometimes has slightly different descriptions in different rows. We pinned each `StockCode` to one canonical description (the most common one) to ensure consistency.

### Step 5: Derived Features
From the raw date/time, we extracted:
- `Date` — the calendar date
- `Month` — the month (for seasonal analysis)
- `Hour` — hour of day (for trading rhythm)
- `Weekday` — day of week (Mon–Sun)
- `Revenue` — `Quantity * UnitPrice` for each line

### Result After Cleaning

| Metric | Value |
|---|---|
| Rows retained | 515,784 (95.2%) |
| Rows removed | 26,125 (4.8%) |
| Baskets (transactions) | 18,273 |
| Unique products | 3,765 |
| Countries | 38 |
| Mean basket size | 28.23 |
| Median basket size | 17 |
| Total revenue | GBP 9,658,813 |

---

## 5. Exploratory Data Analysis (EDA)

Before mining rules, we explored the data to understand what it looks like.

### 5.1 Top Products by Frequency
Counted how many baskets each product appears in. The most frequent product is **"WHITE HANGING HEART T-LIGHT HOLDER"** — it appears in 2,246 baskets (12.3% of all baskets).

### 5.2 Top Products by Revenue
Summed `Revenue` (Quantity * UnitPrice) for each product to find the biggest money-makers.

### 5.3 Basket Size Distribution
Most baskets have 8–30 items. A few have thousands (bulk orders). The distribution is right-skewed.

### 5.4 Monthly Revenue
Revenue peaks in **September–November 2011** (pre-Christmas festive quarter). This is the most important period for the retailer.

### 5.5 Trading Rhythm (Weekday x Hour Heatmap)
Most orders come in during **weekday business hours** (9 AM – 5 PM, Monday–Friday), with a peak around midday.

### 5.6 Geography
The UK accounts for the vast majority of revenue. Other notable countries include Germany, France, Ireland, and the Netherlands.

### 5.7 Item Frequency Plot
A bar chart showing the top 20 items by how often they appear in baskets — this tells us which products are staples in customers' carts.

---

## 6. Algorithms Used

### 6.1 Primary Algorithm: Apriori (Association Rule Mining)

#### What Is Association Rule Mining?

Association rule mining is a data mining technique that discovers interesting relationships (rules) between variables in large databases. In our case, it finds rules like:

> **If a customer buys "HERB MARKER MINT" and "HERB MARKER PARSLEY", they will also buy "HERB MARKER CHIVES" with 86% confidence.**

#### The Apriori Algorithm

**Apriori** is the classic algorithm for finding association rules, proposed by Agrawal and Srikant in 1994. It works in two phases:

**Phase 1 — Find Frequent Itemsets:**
An "itemset" is simply a set of items that appear together in baskets. An itemset is "frequent" if it appears in at least a minimum percentage of all baskets (called the **minimum support**).

Apriori uses the **Apriori Property**: *Every subset of a frequent itemset is also frequent.* This lets the algorithm dramatically prune its search — if a single item isn't frequent enough, no superset containing it can be frequent either. This is what makes Apriori efficient even with thousands of products.

**Phase 2 — Generate Association Rules:**
From each frequent itemset, Apriori generates rules of the form `{A, B} => {C}` (meaning: if A and B are in the basket, C is likely too). It keeps only rules that meet the minimum **confidence** threshold.

#### The Three Key Measures

Every rule is scored by three metrics:

| Measure | Formula | What It Tells You |
|---|---|---|
| **Support** | P(X ∪ Y) | How common the pattern is across all baskets. Low support = rare pattern. |
| **Confidence** | P(Y \| X) = support(X∪Y) / support(X) | How reliable the rule is. If confidence is 86%, then 86% of baskets containing X also contain Y. |
| **Lift** | confidence / support(Y) | How much better than random chance. Lift > 1 means positive association. Lift = 1 means the items are independent (no relationship). Lift = 75 means the item is 75x more likely to appear than by chance. |

**Lift is the most important measure** in this project. Confidence alone is misleading: any rule pointing at a very popular product (like "WHITE HANGING HEART T-LIGHT HOLDER", which is in 12% of all baskets) will score well on confidence regardless of whether there is a real association.

#### Our Parameters

| Parameter | Value | Meaning |
|---|---|---|
| `support` | 0.01 (1%) | A rule's antecedent+consequent must appear together in at least 1% of all baskets (~183 baskets) |
| `confidence` | 0.30 (30%) | The rule must be correct at least 30% of the time |
| `minlen` | 2 | Rules must have at least one item on each side (at least 2 items total) |
| `maxlen` | 4 | Rules with more than 4 items are hard to interpret |
| `min_lift` | 1.0 | Only rules better than random chance |
| `top_n` | 20 | How many top rules to show in tables and plots |

### 6.2 Statistical Significance: Fisher's Exact Test

Not every rule that passes the lift/confidence thresholds is truly meaningful. A rule could appear strong purely by chance. To guard against this:

1. We run **Fisher's Exact Test** on each rule's 2×2 contingency table.
2. We apply **Benjamini-Hochberg (BH) correction** to control the false discovery rate.
3. We keep only rules with BH-adjusted p-value < 0.05.

This ensures our 2,215 surviving rules are genuinely statistically significant, not just random noise.

### 6.3 Redundancy Removal

Two rules might say essentially the same thing. For example:
- `{A, B} => {C}` with 85% confidence
- `{A} => {C}` with 80% confidence

If `{A} => {C}` has equal or better confidence, then adding B to the antecedent adds nothing — the more general rule is just as good. We use `is.redundant()` from the `arules` package to detect and remove these redundant rules.

### 6.4 Threshold Sensitivity Analysis

To understand how sensitive our results are to parameter choices, we test a 5×5 grid of support and confidence values. This shows that rule count drops geometrically as support increases (support is the most critical parameter), while confidence merely trims the already-determined pool.

### 6.5 Segment-Based Re-Mining

The same Apriori algorithm is run separately on:
- **UK transactions** vs **International transactions** — to compare association structures across regions
- **Pre-Christmas quarter (Sep–Nov)** vs **Rest of year** — to find seasonal differences

The festive quarter produces far more rules from fewer baskets, confirming that the rule set needs to be re-mined quarterly.

---

## 7. Model Implementation

### Pipeline Overview

```
Raw Data (Excel)
 ↓
01_load_clean.R — Download, audit, clean → retail_clean.rds
 ↓
02_eda.R — Exploratory analysis → figures + tables
 ↓
03_apriori.R — Apriori mining → rules, itemsets, sensitivity analysis
 ↓
04_visualize_rules.R — Rule visualizations → association graphs, matrices
 ↓
05_segments_and_recommendations.R — Segments, seasons, recommender, ROI
 ↓
All outputs saved to data/processed/ and output/figures/tables/
 ↓
app.R (Shiny dashboard) reads all pre-computed outputs
```

### Implementation Details

**Packages used:**
- `readxl` — read the Excel file
- `dplyr`, `tidyr` — data manipulation
- `lubridate` — date/time handling
- `ggplot2`, `scales`, `RColorBrewer` — visualization
- `arules` — Apriori algorithm and association rule mining
- `arulesViz` — rule visualization (graphs, matrices, parallel coordinates)

### Rule Generation Steps (in `03_apriori.R`)

1. Convert the cleaned data into a **transactions object** (one basket = one character vector of item names)
2. Run `apriori()` to find frequent itemsets
3. Run `apriori()` again with confidence parameter to generate rules
4. Filter: keep only `lift > 1.0`
5. Remove redundant rules
6. Apply Fisher's exact test + BH correction
7. Export all 2,215 significant rules to CSV
8. Export top-20 tables sorted by lift, confidence, and support
9. Generate sensitivity analysis across threshold grid

### Business Value Calculation (in `05_segments_and_recommendations.R`)

For each rule, we calculate the revenue opportunity:

```
MissedBaskets = (coverage - support) × TotalBaskets
 = baskets that have the antecedent but NOT the consequent

ExpectedUplift = MissedBaskets × Confidence
 = baskets we would expect to convert if we prompted the rule

PotentialRevenue = ExpectedUplift × AvgPrice × AvgQty
```

This gives us a concrete GBP figure for each rule's untapped revenue potential.

---

## 8. Model Evaluation

### Association Rules: Key Metrics

| Metric | Value |
|---|---|
| Total rules generated (initial) | ~25,000+ |
| After lift > 1 filter | ~5,000+ |
| After redundancy removal | ~3,500+ |
| After Fisher's test + BH correction | **2,215 (final)** |

### Quality of the Rules

| Metric | Range |
|---|---|
| Support | 0.005 – 0.049 |
| Confidence | 0.30 – 0.99 |
| Lift | 1.00 – 75.47 |
| Mean Lift | ~13.2x |

### Top Rules by Lift

| Antecedent (If you buy...) | Consequent (You will also buy...) | Lift |
|---|---|---|
| HERB MARKER MINT + HERB MARKER PARSLEY | HERB MARKER CHIVES | **75.5x** |
| HERB MARKER PARSLEY + HERB MARKER THYME | HERB MARKER CHIVES | **75.1x** |
| HERB MARKER PARSLEY + HERB MARKER ROSEMARY | HERB MARKER CHIVES | **74.4x** |

These herb marker rules have extreme lift because customers buying giftware herb markers almost always complete the full set of 6 markers.

### Top Cross-Sell Opportunities by Revenue

| Rule | Revenue Opportunity |
|---|---|
| ROSES REGENCY TEACUP AND SAUCER => REGENCY CAKESTAND 3 TIER | **GBP 24,625** |
| JUMBO BAG RED RETROSPOT => JUMBO BAG PINK POLKADOT | **GBP 22,351** |
| LUNCH BAG RED RETROSPOT => JUMBO BAG RED RETROSPOT | **GBP 20,175** |

These are not the highest-lift rules, but they fire on many baskets against expensive items, making them the most valuable commercial opportunities.

### Total Revenue Opportunity

| Metric | Value |
|---|---|
| Best rule per product (defensible estimate) | **GBP 1,016,000** |
| Top 20 products of those | ~73% of total opportunity |

### Segment Comparison

| Segment | Baskets | Rules | Mean Lift | Max Lift |
|---|---|---|---|---|
| UK | 16,506 | 2,661 | 13.13x | 72.66x |
| International | 1,767 | 375 | 9.84x | 37.25x |

UK has far more rules because it has 9x more baskets. International rules have lower lift, suggesting different buying patterns.

### Season Comparison

| Season | Baskets | Rules | Mean Lift |
|---|---|---|---|
| Pre-Christmas (Sep-Nov) | 6,139 | **5,174** | 11.7x |
| Rest of Year | 12,134 | 2,296 | 13.4x |

The festive quarter produces **2.25x more rules from half as many baskets**. This means the Sep-Nov period has much denser association structure — likely because customers buy gift sets and themed products in groups. The rule set should be re-mined quarterly.

---

## 9. GUI Design & Implementation

### Tool: R Shiny

We chose **R Shiny** because:
- It integrates natively with R and all our data mining packages
- It creates interactive web applications without needing HTML/CSS/JS
- It supports real-time user input and dynamic output updates
- It is the standard for data science dashboards in R

### Framework: shinydashboard

We use `shinydashboard` which provides a professional admin-panel layout with a sidebar, header, and content boxes — ideal for a multi-section analytics dashboard.

### The Dashboard: "Basket Lens"

The dashboard has **7 tabs**, each focused on a different aspect of the analysis:

#### Tab 1: Overview
The "at a glance" dashboard. Four KPI boxes show the most important numbers: total baskets (18,273), unique products (3,765), significant rules (2,215), and total revenue (GBP 9.66M). Below that are four charts: monthly revenue over time, top 10 products by frequency, a weekday-hour trading heatmap, and top countries by revenue.

#### Tab 2: Exploratory (EDA)
All the exploratory analysis charts. Users can adjust how many top products to show (10, 15, 20, 25, 30, or 50) for both the frequency and revenue charts. Also shows the basket size distribution histogram and the item frequency plot.

#### Tab 3: Rules
Displays the core association rule analysis: threshold sensitivity chart (how many rules survive each parameter pair), rule statistics (support/confidence/lift ranges), top-20 rules by lift as a bar chart, support-vs-confidence scatter plot, and four interactive searchable tables (by lift, confidence, support, and all 2,215 rules). The tables have column filtering and pagination.

#### Tab 4: Explorer
An interactive rule filter where users can set minimum thresholds for lift, confidence, and support, plus search for specific item names. Clicking "Apply Filters" shows matching rules in a searchable table. Two buttons load the association network graph (top 25 rules by lift) and the parallel coordinates plot (top 20 by confidence).

#### Tab 5: Segments
Compares UK vs International customers with value boxes (basket counts, rule counts), a bar chart, and a summary table. Also shows seasonal analysis comparing the festive quarter (Sep-Nov) vs rest of year, and a table of rules that exist only in the festive period.

#### Tab 6: Recommender
An interactive product recommender. Users select items from a dropdown (with search-as-you-type), and the system finds all association rules whose "if" part (antecedent) is fully contained in their basket. It returns the top recommended items ranked by lift, excluding items already in the basket. Three "Sample Basket" buttons load real baskets from the dataset for quick testing.

#### Tab 7: Cross-Sell
Four KPI boxes: total revenue opportunity (GBP 1.02M), best single opportunity, average lift, and number of products with opportunities. A bar chart shows the top 15 opportunities by revenue. A sortable, filterable table shows all cross-sell opportunities with columns for rule, consequent, support, confidence, lift, missed baskets, and potential revenue.

### GUI Architecture

```
app.R (single-file Shiny app)
├── UI Definition
│ ├── dashboardHeader (logo, title)
│ ├── dashboardSidebar (7 menu items)
│ └── dashboardBody
│ ├── Custom CSS (Inter font, dark sidebar, colored boxes, shadows)
│ └── tabItems (7 tab panels)
│
└── Server Logic
 ├── Data Loading (on startup, reads .rds and .csv files)
 ├── Overview outputs (4 KPIs + 4 plots)
 ├── EDA outputs (2 interactive bar charts + 2 plots)
 ├── Rules outputs (2 images + 4 data tables)
 ├── Explorer outputs (filter logic + 2 images + 1 table)
 ├── Segments outputs (4 KPIs + 3 plots + 2 tables)
 ├── Recommender outputs (rule-matching logic + 1 table + 3 sample buttons)
 └── Cross-Sell outputs (4 KPIs + 1 plot + 1 table)
```

### Data Flow

The app does **not** re-run the Apriori algorithm when you open it. Instead, it reads the pre-computed outputs:
- `data/processed/retail_clean.rds` — the cleaned dataset (515K rows)
- `data/processed/transactions.rds` — the basket/transaction object
- `data/processed/rules_significant.rds` — the 2,215 rules for the recommender
- `output/tables/*.csv` — all the table data (28 CSV files)
- `output/figures/*.png` — all pre-rendered charts (15 PNG files)

This makes the app launch in **seconds** rather than minutes.

---

## 10. Results & Discussion

### Key Findings

1. **Products sell as families, not individually.** The highest-lift rules cluster inside product sets — herb markers (lift 75x), the regency tea range, the retrospot bag colorways, and the woodland/spaceboy children's line. Customers completing a set is the dominant buying pattern.

2. **Colourway substitution is predictable.** Rules consistently link the same product across color variants (e.g., red retrospot bag => pink retrospot bag). This means stock-outs on one color variant suppress sales of the entire product family.

3. **Association structure is seasonal.** The Sep-Nov festive quarter produces dramatically more rules from fewer baskets. The festive quarter generated 5,174 rules from 6,139 baskets, while the rest of the year generated only 2,296 rules from 12,134 baskets. The rule set needs quarterly re-mining.

4. **Segments differ measurably.** UK and international baskets have different association structures (mean lift: 13.1x vs 9.8x). They need separate rule sets for targeted recommendations.

5. **The commercial opportunity is GBP 1.02M.** The largest cross-sell gaps are not the highest-lift rules. The best opportunities are mid-lift, high-support rules on expensive items. For example, "ROSES REGENCY TEACUP AND SAUCER => REGENCY CAKESTAND 3 TIER" has a lift of only 4.6x but represents GBP 24,625 in missed revenue because it fires on hundreds of baskets against a high-ticket product.

### Why Apriori Was the Right Choice

- The problem is fundamentally about **co-occurrence**, not prediction. We are not predicting a target variable — we are discovering patterns in item combinations. Apriori is purpose-built for this.
- Apriori is **interpretable**. Each rule is a clear "if-then" statement that business users can understand and act on.
- The algorithm is **efficient** for this dataset size (18K baskets, 3,765 products) with a 1% support threshold.
- It provides **three complementary metrics** (support, confidence, lift) that together describe pattern frequency, reliability, and strength.

---

## 11. Conclusion

This project successfully demonstrates the complete data mining workflow:

1. **Data collection** — Obtained the UCI Online Retail dataset (541K rows, 38 countries, 12 months of transactions)
2. **Data preprocessing** — Removed 4.8% of rows through systematic cleaning (cancellations, returns, admin codes, junk descriptions, duplicates, single-item baskets), resulting in 515,784 clean rows across 18,273 baskets and 3,765 products
3. **Exploratory analysis** — Identified seasonal peaks (Sep-Nov), trading rhythms (weekday business hours), top products, and geographic distribution
4. **Model implementation** — Applied the Apriori algorithm with Fisher's exact test and Benjamini-Hochberg correction, yielding 2,215 statistically significant association rules with mean lift of 13.2x
5. **Business insights** — Found GBP 1.02M in cross-sell revenue opportunity, seasonal rule structure differences, and segment-specific patterns
6. **GUI deployment** — Built "Basket Lens," a 7-tab interactive Shiny dashboard that makes all findings accessible through a web browser

The project fulfills all course requirements: problem definition, preprocessing, EDA, algorithm implementation with proper evaluation, GUI integration, and demonstrated understanding of the Apriori algorithm and association rule mining concepts.

---

## 12. Limitations & Future Scope

### Limitations

1. **No customer-level personalization.** The rules are based on aggregate basket patterns, not individual customer preferences. Two different customers with the same basket get the same recommendations.

2. **Static rules.** The rules are mined from the full 12-month dataset. As noted, the festive quarter has a very different rule structure, so ideally rules should be re-mined quarterly.

3. **No price sensitivity analysis.** The cross-sell opportunity calculation uses average prices, but prices may vary over time or between customer segments.

4. **Single retailer.** The dataset is from one UK giftware retailer. Findings may not generalize to other retail sectors (electronics, groceries, fashion).

5. **No temporal dynamics.** The dataset spans 12 months, but we treat all transactions equally. Recent purchase patterns may be more predictive than old ones.

6. **Association rules only capture co-occurrence, not causality.** A rule like "A => B" does not mean A causes B — it could be that both are caused by a third factor (e.g., it's Christmas).

### Future Scope

1. **Sequence mining** — Instead of just "what items appear together," mine "what items are bought in what order" (e.g., first a teacup, then a saucer).

2. **Deep learning recommendations** — Implement collaborative filtering (matrix factorization) or neural network-based recommenders for comparison with Apriori.

3. **Real-time re-mining** — Set up a pipeline that re-mines rules weekly/monthly as new transaction data arrives.

4. **Customer segmentation + personalized rules** — Cluster customers by RFM (Recency, Frequency, Monetary) and mine separate rule sets per cluster.

5. **A/B testing framework** — Integrate the rules into a recommendation engine and run controlled experiments to measure actual revenue lift.

6. **Competitive benchmarking** — Compare Apriori against FP-Growth (a faster frequent pattern mining algorithm) on the same dataset.

7. **Mobile-responsive dashboard** — Adapt the Shiny UI for mobile devices using `shinyMobile` or `bslib`.

---

## 13. References

1. Agrawal, R. & Srikant, R.. *Fast Algorithms for Mining Association Rules*. Proceedings of the 20th International Conference on Very Large Data Bases (VLDB), 487-499.

2. Hahsler, M., Grün, B. & Hornik, K.. *arules — A Computational Environment for Mining Association Rules and Frequent Item Sets*. Journal of Statistical Software, 14(15).

3. Hahsler, M.. *arulesViz: Visualizing Association Rules and Frequent Itemsets*. R package.

4. Chen, D., Sain, S. L. & Guo, K.. *Data mining for the online retail industry: A case study of RFM model-based customer segmentation using data mining*. Journal of Database Marketing & Customer Strategy Management, 19(3), 197-208.

5. UCI Machine Learning Repository. *Online Retail Data Set* (#352). https://archive.ics.uci.edu/dataset/352/online+retail

6. R Core Team. *R: A Language and Environment for Statistical Computing*. https://www.R-project.org/

7. Chang, W. et al.. *shiny: Web Application Framework for R*. R package. https://shiny.posit.co/

8. Chang, W.. *shinydashboard: Create Dashboards with 'Shiny'*. R package.

9. Benjamini, Y. & Hochberg, Y.. *Controlling the False Discovery Rate: A Practical and Powerful Approach to Multiple Testing*. Journal of the Royal Statistical Society, Series B, 57(1), 289-300.

---

*Report generated for the Data Mining course project. All results are derived from the UCI Online Retail dataset processed through the R Apriori pipeline.*
