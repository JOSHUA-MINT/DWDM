# Graph Report - DWDM  (2026-09-03)

## Corpus Check
- 17 files · ~191,673 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 342 nodes · 334 edges · 21 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3dfc4dac`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Market Basket Analysis of Online Retail Transactions
- Basket Lens — Market Basket Analysis Project Report
- The Dashboard: "Basket Lens"
- 6. Algorithms Used
- 5. Exploratory Data Analysis (EDA)
- 8. Model Evaluation
- 4. Data Preprocessing
- DASHBOARD_VISUAL_GUIDE.md
- Basket Lens — Every Number on the Dashboard, Traced to Its Source
- Basket Lens — Code Walkthrough (What Runs, What It Produces)
- Basket Lens — How This Project Actually Works (Plain-English Deep Dive)
- Basket Lens — Theory Behind the Project (Formulas Explained Simply)
- PART B — Viva / Exam Prep: Likely Questions & Model Answers
- PART A — Section-by-Section Code Walkthrough
- Part 9 — Things worth knowing (quirks and gotchas)
- `R/01_load_clean.R` — download, audit, clean
- Tab 5 — Segments
- 3. The Data Pipeline, Step by Step (with formulas as they appear)
- Part 0 — The machine behind the screen
- Tab 5 — Segments
- Tab 2 — Exploratory

## God Nodes (most connected - your core abstractions)
1. `PART B — Viva / Exam Prep: Likely Questions & Model Answers` - 21 edges
2. `PART A — Section-by-Section Code Walkthrough` - 17 edges
3. `Basket Lens — Market Basket Analysis Project Report` - 14 edges
4. `Part 9 — Things worth knowing (quirks and gotchas)` - 13 edges
5. `Basket Lens — How This Project Actually Works (Plain-English Deep Dive)` - 10 edges
6. `Basket Lens — Code Walkthrough (What Runs, What It Produces)` - 9 edges
7. `Basket Lens — Every Number on the Dashboard, Traced to Its Source` - 9 edges
8. `Tab 1 — Overview` - 9 edges
9. `Market Basket Analysis of Online Retail Transactions` - 9 edges
10. `Basket Lens — Theory Behind the Project (Formulas Explained Simply)` - 9 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (21 total, 0 thin omitted)

### Community 0 - "Market Basket Analysis of Online Retail Transactions"
Cohesion: 0.14
Nodes (13): Cleaning, DWDM, Headline findings, Market Basket Analysis of Online Retail Transactions, Method, Mining, Outputs, Project layout (+5 more)

### Community 1 - "Basket Lens — Market Basket Analysis Project Report"
Cohesion: 0.08
Nodes (24): 10. Results & Discussion, 11. Conclusion, 12. Limitations & Future Scope, 13. References, 1. Project Title, 2. Problem Statement & Objectives, 3. Dataset Description, 7. Model Implementation (+16 more)

### Community 2 - "The Dashboard: "Basket Lens""
Cohesion: 0.15
Nodes (13): 9. GUI Design & Implementation, Data Flow, Framework: shinydashboard, GUI Architecture, Tab 1: Overview, Tab 2: Exploratory (EDA), Tab 3: Rules, Tab 4: Explorer (+5 more)

### Community 3 - "6. Algorithms Used"
Cohesion: 0.20
Nodes (10): 6.1 Primary Algorithm: Apriori (Association Rule Mining), 6.2 Statistical Significance: Fisher's Exact Test, 6.3 Redundancy Removal, 6.4 Threshold Sensitivity Analysis, 6.5 Segment-Based Re-Mining, 6. Algorithms Used, Our Parameters, The Apriori Algorithm (+2 more)

### Community 4 - "5. Exploratory Data Analysis (EDA)"
Cohesion: 0.25
Nodes (8): 5.1 Top Products by Frequency, 5.2 Top Products by Revenue, 5.3 Basket Size Distribution, 5.4 Monthly Revenue, 5.5 Trading Rhythm (Weekday x Hour Heatmap), 5.6 Geography, 5.7 Item Frequency Plot, 5. Exploratory Data Analysis (EDA)

### Community 5 - "8. Model Evaluation"
Cohesion: 0.25
Nodes (8): 8. Model Evaluation, Association Rules: Key Metrics, Quality of the Rules, Season Comparison, Segment Comparison, Top Cross-Sell Opportunities by Revenue, Top Rules by Lift, Total Revenue Opportunity

### Community 6 - "4. Data Preprocessing"
Cohesion: 0.29
Nodes (7): 4. Data Preprocessing, Result After Cleaning, Step 1: Download & Load, Step 2: Data Quality Audit, Step 3: Cleaning Rules, Step 4: Canonical Product Names, Step 5: Derived Features

### Community 7 - "DASHBOARD_VISUAL_GUIDE.md"
Cohesion: 0.05
Nodes (38): All Cross-Sell Opportunities (table), Appendix A — Panel-to-code index, Appendix B — Which script writes which file, Association Network (Top 25 by Lift)  *(static image)*, Basket Lens — Visual Guide to Every Feature, How do rule counts react to threshold pairs?  *(static image)*, Monthly Revenue Trend, Parallel Coordinates (Top 20 by Confidence)  *(static image)* (+30 more)

### Community 8 - "Basket Lens — Every Number on the Dashboard, Traced to Its Source"
Cohesion: 0.05
Nodes (37): Basket Lens — Every Number on the Dashboard, Traced to Its Source, Chart: "Basket Size Distribution", Chart: "Monthly Revenue Trend", Chart: "Top 10 Products by Frequency", Chart: "Top Countries by Revenue", Chart: "Top Products by Basket Frequency" (with the "Show top N items" dropdown), Chart: "Top Products by Revenue" (with its own N dropdown), Chart: "Trading Rhythm: Weekday x Hour" (heatmap) (+29 more)

### Community 9 - "Basket Lens — Code Walkthrough (What Runs, What It Produces)"
Cohesion: 0.06
Nodes (34): `app.R` — the dashboard (what running `shiny::runApp()` gives you), arulesViz plots (guarded by a package check), Bar chart of top rules by lift, Basket Lens — Code Walkthrough (What Runs, What It Produces), Building the transaction object, Exporting tables, Filtering the rules down, Geographic segments (+26 more)

### Community 10 - "Basket Lens — How This Project Actually Works (Plain-English Deep Dive)"
Cohesion: 0.07
Nodes (26): 1. What This Project Is, In One Paragraph, 2. File-by-File Guide, 4.1 Support, Confidence, Lift — the three core measures, 4.2 How Apriori actually runs (`R/03_apriori.R:17-99`), 4.3 Threshold sensitivity (`R/03_apriori.R:142-152`), 4.4 The recommender-matching logic, 4.5 The cross-sell revenue formula (`R/05_segments_and_recommendations.R:148-193`), 4. The Formulas (+18 more)

### Community 11 - "Basket Lens — Theory Behind the Project (Formulas Explained Simply)"
Cohesion: 0.08
Nodes (24): 1. The Problem Type: Association Rule Mining, 2. Itemsets and the Apriori Property, 3.1 Support — "how common is this pattern?", 3.2 Confidence — "how reliable is this rule?", 3.3 Lift — "is this better than coincidence?", 3.4 Why lift is the project's primary ranking measure, 3. The Three Measures: Support, Confidence, Lift, 4.1 Fisher's Exact Test (+16 more)

### Community 12 - "PART B — Viva / Exam Prep: Likely Questions & Model Answers"
Cohesion: 0.10
Nodes (21): PART B — Viva / Exam Prep: Likely Questions & Model Answers, Q10. Where does the number **2,215** (Significant Rules) actually get computed, and does, Q11. Why is the GBP 1.02M figure computed from `05_cross_sell_best_rule_per_product.csv`, Q12. What R package does the actual Apriori algorithm live in, and does `app.R` import it?, Q13. What is `DT::datatable()` doing that a plain R table print wouldn't?, Q14. Why does the Explorer tab require clicking "Apply Filters" instead of updating live, Q15. What's the practical difference between a *static* output (like `show_fig("14_top_rules_by_lift_bars.png")`), Q16. If you changed `PARAMS$support` in `00_setup.R` and re-ran the pipeline, would `app.R` (+13 more)

### Community 13 - "PART A — Section-by-Section Code Walkthrough"
Cohesion: 0.11
Nodes (18): A.10 Server — EDA tab outputs (lines 552–594), A.11 Server — Rules tab outputs (lines 598–639), A.12 Server — Explorer tab logic (lines 643–678), A.13 Server — Segments tab outputs (lines 682–757), A.14 Server — Recommender tab logic (lines 761–867), A.15 Server — Cross-Sell tab outputs (lines 871–948), A.16 The final line (line 952), A.1 Setup block (lines 1–24) (+10 more)

### Community 14 - "Part 9 — Things worth knowing (quirks and gotchas)"
Cohesion: 0.15
Nodes (13): 10. Static images ignore the controls next to them, 11. The two segments were mined at different thresholds, 12. Some International rules rest on ~37 baskets, ⚠️ 1. Launching the app can silently re-run the entire pipeline, ⚠️ 2. Two bar charts render grey with no legend, ⚠️ 3. "UK Top Rules: 25" is not a rule count, ⚠️ 4. Explorer caps before it searches, ⚠️ 5. Two hard-coded rule counts (+5 more)

### Community 15 - "`R/01_load_clean.R` — download, audit, clean"
Cohesion: 0.25
Nodes (8): If you run it, `R/01_load_clean.R` — download, audit, clean, Step 1: Download (only if not already cached), Step 2: Data quality audit, Step 3: The cleaning chain, Step 4: Canonical product names, Step 5: Drop single-item baskets, Step 6: Report + save

### Community 16 - "Tab 5 — Segments"
Cohesion: 0.25
Nodes (8): Chart: "Festive vs Rest of Year" (bar), KPI box: "International Baskets", KPI box: "UK Baskets", KPI box: "UK Top Rules" / "Intl Top Rules", Tab 5 — Segments, Table: "Rules That Exist Only in the Festive Quarter", Table: "Segment Comparison Summary" + Chart: "UK vs International: Baskets & Rules", Tables: "UK: Top Rules by Lift" / "International: Top Rules by Lift"

### Community 17 - "3. The Data Pipeline, Step by Step (with formulas as they appear)"
Cohesion: 0.29
Nodes (7): 3. The Data Pipeline, Step by Step (with formulas as they appear), `R/00_setup.R` — the control panel, `R/01_load_clean.R` — turning messy checkout data into usable baskets, `R/02_eda.R` — exploratory analysis, `R/03_apriori.R` — the actual data-mining step, `R/04_visualize_rules.R` — turning rules into pictures, `R/05_segments_and_recommendations.R` — turns rules into business answers

### Community 18 - "Part 0 — The machine behind the screen"
Cohesion: 0.33
Nodes (6): 0.1 The pipeline, in order, 0.2 The two kinds of picture on this dashboard, 0.3 How data reaches the server, 0.4 The cleaning that produced every number, 0.5 The parameters that control everything, Part 0 — The machine behind the screen

### Community 19 - "Tab 5 — Segments"
Cohesion: 0.33
Nodes (6): Seasonal Analysis, Segment Comparison Summary, Tab 5 — Segments, The four KPI boxes, UK and International rule tables, UK vs International: Baskets & Rules

### Community 20 - "Tab 2 — Exploratory"
Cohesion: 0.40
Nodes (5): Basket Size Distribution, Relative Item Frequency  *(static image)*, Tab 2 — Exploratory, Top Products by Basket Frequency (interactive), Top Products by Revenue (interactive)

## Knowledge Gaps
- **278 isolated node(s):** `app.R — Full Code Explanation + Viva/Exam Prep`, `A.1 Setup block (lines 1–24)`, `A.2 Theme, colours, and helper functions (lines 26–81)`, `A.3 UI — `dashboardPage()` skeleton (lines 86–97)`, `A.4 UI — Sidebar menu (lines 99–115)` (+273 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Basket Lens — Market Basket Analysis Project Report` connect `Basket Lens — Market Basket Analysis Project Report` to `The Dashboard: "Basket Lens"`, `6. Algorithms Used`, `5. Exploratory Data Analysis (EDA)`, `8. Model Evaluation`, `4. Data Preprocessing`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `Basket Lens — Every Number on the Dashboard, Traced to Its Source` connect `Basket Lens — Every Number on the Dashboard, Traced to Its Source` to `Tab 5 — Segments`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `Basket Lens — Code Walkthrough (What Runs, What It Produces)` connect `Basket Lens — Code Walkthrough (What Runs, What It Produces)` to ``R/01_load_clean.R` — download, audit, clean`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **What connects `app.R — Full Code Explanation + Viva/Exam Prep`, `A.1 Setup block (lines 1–24)`, `A.2 Theme, colours, and helper functions (lines 26–81)` to the rest of the system?**
  _278 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Market Basket Analysis of Online Retail Transactions` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Basket Lens — Market Basket Analysis Project Report` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `DASHBOARD_VISUAL_GUIDE.md` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._