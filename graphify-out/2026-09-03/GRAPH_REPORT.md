# Graph Report - DWDM  (2026-09-01)

## Corpus Check
- 11 files · ~73,073 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 85 nodes · 83 edges · 9 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `108371b2`
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
- 3. Dataset Description
- 2. Problem Statement & Objectives

## God Nodes (most connected - your core abstractions)
1. `Basket Lens — Market Basket Analysis Project Report` - 14 edges
2. `Market Basket Analysis of Online Retail Transactions` - 9 edges
3. `5. Exploratory Data Analysis (EDA)` - 8 edges
4. `8. Model Evaluation` - 8 edges
5. `The Dashboard: "Basket Lens"` - 8 edges
6. `4. Data Preprocessing` - 7 edges
7. `6. Algorithms Used` - 6 edges
8. `9. GUI Design & Implementation` - 6 edges
9. `3. Dataset Description` - 5 edges
10. `6.1 Primary Algorithm: Apriori (Association Rule Mining)` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (9 total, 0 thin omitted)

### Community 0 - "Market Basket Analysis of Online Retail Transactions"
Cohesion: 0.14
Nodes (13): Cleaning, DWDM, Headline findings, Market Basket Analysis of Online Retail Transactions, Method, Mining, Outputs, Project layout (+5 more)

### Community 1 - "Basket Lens — Market Basket Analysis Project Report"
Cohesion: 0.12
Nodes (15): 10. Results & Discussion, 11. Conclusion, 12. Limitations & Future Scope, 13. References, 1. Project Title, 7. Model Implementation, Basket Lens — Market Basket Analysis Project Report, Business Value Calculation (in `05_segments_and_recommendations.R`) (+7 more)

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

### Community 7 - "3. Dataset Description"
Cohesion: 0.40
Nodes (5): 3. Dataset Description, Key Facts, Source, The Business, What Is In The Dataset?

### Community 8 - "2. Problem Statement & Objectives"
Cohesion: 0.50
Nodes (4): 2. Problem Statement & Objectives, Expected Outcome, Objectives, What Problem Are We Solving?

## Knowledge Gaps
- **68 isolated node(s):** `1. Project Title`, `What Problem Are We Solving?`, `Objectives`, `Expected Outcome`, `Source` (+63 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Basket Lens — Market Basket Analysis Project Report` connect `Basket Lens — Market Basket Analysis Project Report` to `The Dashboard: "Basket Lens"`, `6. Algorithms Used`, `5. Exploratory Data Analysis (EDA)`, `8. Model Evaluation`, `4. Data Preprocessing`, `3. Dataset Description`, `2. Problem Statement & Objectives`?**
  _High betweenness centrality (0.626) - this node is a cross-community bridge._
- **Why does `9. GUI Design & Implementation` connect `The Dashboard: "Basket Lens"` to `Basket Lens — Market Basket Analysis Project Report`?**
  _High betweenness centrality (0.211) - this node is a cross-community bridge._
- **Why does `6. Algorithms Used` connect `6. Algorithms Used` to `Basket Lens — Market Basket Analysis Project Report`?**
  _High betweenness centrality (0.165) - this node is a cross-community bridge._
- **What connects `1. Project Title`, `What Problem Are We Solving?`, `Objectives` to the rest of the system?**
  _68 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Market Basket Analysis of Online Retail Transactions` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Basket Lens — Market Basket Analysis Project Report` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._