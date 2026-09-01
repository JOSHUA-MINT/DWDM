# Graph Report - DWDM  (2026-09-01)

## Corpus Check
- 10 files · ~52,976 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 14 nodes · 13 edges · 3 communities (2 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `108371b2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Market Basket Analysis of Online Retail Transactions
- Method
- README.md

## God Nodes (most connected - your core abstractions)
1. `Market Basket Analysis of Online Retail Transactions` - 9 edges
2. `Method` - 4 edges
3. `Quick start` - 1 edges
4. `Project layout` - 1 edges
5. `Tuning the analysis` - 1 edges
6. `Cleaning` - 1 edges
7. `Mining` - 1 edges
8. `The three measures` - 1 edges
9. `Headline findings` - 1 edges
10. `Outputs` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (3 total, 1 thin omitted)

### Community 0 - "Market Basket Analysis of Online Retail Transactions"
Cohesion: 0.25
Nodes (8): Headline findings, Market Basket Analysis of Online Retail Transactions, Outputs, Project layout, Quick start, References, Requirements, Tuning the analysis

### Community 1 - "Method"
Cohesion: 0.50
Nodes (4): Cleaning, Method, Mining, The three measures

## Knowledge Gaps
- **11 isolated node(s):** `Quick start`, `Project layout`, `Tuning the analysis`, `Cleaning`, `Mining` (+6 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Market Basket Analysis of Online Retail Transactions` connect `Market Basket Analysis of Online Retail Transactions` to `Method`, `README.md`?**
  _High betweenness centrality (0.910) - this node is a cross-community bridge._
- **Why does `Method` connect `Method` to `Market Basket Analysis of Online Retail Transactions`?**
  _High betweenness centrality (0.423) - this node is a cross-community bridge._
- **What connects `Quick start`, `Project layout`, `Tuning the analysis` to the rest of the system?**
  _11 weakly-connected nodes found - possible documentation gaps or missing edges._