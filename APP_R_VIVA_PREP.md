# app.R — Full Code Explanation + Viva/Exam Prep

This file is dedicated entirely to **`app.R`** — the Shiny dashboard file. It goes section by
section through the actual code, explains what each part does in easy language, says what
output you'll see on screen for each part, and ends with a **Q&A prep section** for likely
questions a professor/examiner could ask about this file, with model answers.

`app.R` is 953 lines, split into exactly two halves: **UI** (lines 86–414, "what the page looks
like") and **Server** (lines 419–949, "what computes the numbers"), joined by one line at the
very end (`shinyApp(ui = ui, server = server)`, line 952) that actually launches the app.

---

# PART A — Section-by-Section Code Walkthrough

## A.1 Setup block (lines 1–24)

```r
options(shiny.autoload.r = FALSE)
library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)
library(arules)

PROJ_ROOT <- ifelse(basename(getwd()) == "R", dirname(getwd()), getwd())
DIR_PROC  <- file.path(PROJ_ROOT, "data", "processed")
DIR_FIG   <- file.path(PROJ_ROOT, "output", "figures")
DIR_TAB   <- file.path(PROJ_ROOT, "output", "tables")

shiny::addResourcePath("figures", DIR_FIG)
```

**What it does:**
- `options(shiny.autoload.r = FALSE)` stops Shiny from automatically sourcing every `.R` file
  in the working directory on startup — since this project's `R/` folder holds the *pipeline*
  scripts (which download data, take minutes, and would otherwise auto-run every time the app
  launches), this line prevents that.
- Loads the 8 packages the **app itself** needs at runtime (a smaller list than the pipeline's
  package list — no `readxl`, `lubridate`, `RColorBrewer` here, because the app never touches
  raw data).
- Works out the project's root folder regardless of whether R's working directory is the project
  root or the `R/` subfolder.
- `addResourcePath("figures", DIR_FIG)` is a **Shiny-specific trick**: it tells the built-in web
  server "whenever a browser asks for something under the URL path `/figures/...`, actually serve
  it from the real folder `output/figures/` on disk." This is what makes `<img src="figures/01_top_items_frequency.png">`
  tags work later in the UI.

**Output when run:** nothing visible yet — this just prepares the environment silently.

---

## A.2 Theme, colours, and helper functions (lines 26–81)

```r
mba_theme <- function(bs = 12) {
  theme_minimal(base_size = bs) + theme(plot.title = element_text(face="bold", ...), ...)
}
mba_colors <- c(primary = "#1565C0", accent = "#00ACC1", danger = "#E53935", ...)
`%||%` <- function(a, b) if (is.null(a)) b else a
show_fig <- function(name, width = "100%") { ... }
load_csv <- function(name) { ... }
```

**What it does:**
- `mba_theme()` is a reusable `ggplot2` theme function (bold titles, grey subtitle text, minimal
  gridlines) — called at the end of nearly every chart in the server code so all charts look
  visually consistent.
- `mba_colors` is a named vector of hex colours reused for chart fills.
- `%||%` (nicknamed the "null-coalescing operator") is a tiny custom operator: `a %||% b` returns
  `a` unless `a` is `NULL`, in which case it returns `b`. Used throughout the server code as a
  safe default, e.g. `input$eda_freq_n %||% 20` means "use the dropdown's value, or 20 if
  somehow unset."
- `show_fig(name, width)` — checks if a PNG file exists in `output/figures/`; if yes, wraps it in
  a styled `<img>` tag; if no, shows a grey "Figure ... not found. Run the pipeline first."
  placeholder instead of crashing.
- `load_csv(name)` — checks if a CSV exists in `output/tables/`; if yes, reads it with
  `read.csv()`; if no, returns a 1-row data frame saying `"<name> not found."` instead of
  crashing.

**Why this matters:** these two "safe loader" functions are the reason the whole dashboard can
be opened even *before* the data pipeline has been run once — you'd just see friendly
placeholder messages everywhere instead of a red Shiny error screen.

**Output when run:** nothing visible yet — these are just function definitions.

---

## A.3 UI — `dashboardPage()` skeleton (lines 86–97)

```r
ui <- dashboardPage(
  dashboardHeader(
    title = tagList(img(src = "...shopping-cart..."), span("Basket Lens", ...)),
    tags$li(class = "dropdown", tags$a(href = "https://github.com/joshua-mint", icon("github"), ...))
  ),
  ...
```

**What it does:** `dashboardPage()` (from `shinydashboard`) is the top-level layout function —
it always takes exactly three parts: a header, a sidebar, and a body. Here the header shows a
shopping-cart emoji + the "Basket Lens" title on the left, and a GitHub icon link on the right.

**Output:** the blue top bar of the dashboard with the logo/title and a GitHub icon.

## A.4 UI — Sidebar menu (lines 99–115)

```r
dashboardSidebar(
  sidebarMenu(
    menuItem("Overview", tabName = "overview", icon = icon("gauge-high")),
    menuItem("Exploratory", tabName = "eda", icon = icon("chart-column")),
    menuItem("Rules", tabName = "rules", icon = icon("circle-nodes")),
    menuItem("Explorer", tabName = "explorer", icon = icon("magnifying-glass")),
    menuItem("Segments", tabName = "segments", icon = icon("globe")),
    menuItem("Recommender", tabName = "recom", icon = icon("wand-magic-sparkles")),
    menuItem("Cross-Sell", tabName = "crosssell", icon = icon("pound-sign")),
    ...
  ),
  ...
)
```

**What it does:** defines the 7 clickable menu entries in the left sidebar. Each `menuItem`'s
`tabName` (e.g. `"overview"`) is the link between the sidebar and the matching `tabItem()` in the
body (§A.6 onward) — clicking a sidebar entry just shows/hides the `tabItem` with the same name.

**Output:** the dark navy sidebar with 7 labelled, icon-prefixed menu links.

## A.5 UI — Custom CSS (lines 117–164)

```r
dashboardBody(
  tags$head(
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Inter..."),
    tags$style(HTML("
      body, .main-sidebar { font-family: 'Inter', sans-serif; }
      .skin-blue .main-sidebar { background: linear-gradient(180deg, #1a2332 0%, #1e293b 100%); }
      ...
    "))
  ),
  tabItems( ... )
)
```

**What it does:** loads the "Inter" font from Google Fonts, then injects a block of raw CSS that
restyles `shinydashboard`'s default Bootstrap look — dark gradient sidebar, rounded box corners,
coloured left-borders per box status (`box-primary`/`box-danger`/etc.), custom button colours,
and smaller table fonts. This is pure visual styling — it has zero effect on any number or
calculation, only on appearance.

**Output:** the whole dashboard's distinctive look (dark sidebar, rounded white cards, blue/teal/
red/orange accent colours) instead of `shinydashboard`'s plain default blue theme.

## A.6 UI — the 7 `tabItem()` blocks (lines 166–412)

Each tab is one `tabItem(tabName = "...", fluidRow(...), fluidRow(...), ...)` block. This is pure
layout — boxes, plot placeholders (`plotOutput`), table placeholders (`DTOutput`), and input
widgets (`selectInput`, `sliderInput`, `actionButton`, etc.). **None of these compute anything —
they only reserve a named "slot" that the server half will later fill in.** For example:

```r
valueBoxOutput("ov_baskets", width = 3)
```
This just says "there will be a KPI box called `ov_baskets` here, taking up 3 of 12 grid
columns." The actual number inside it is supplied later by `output$ov_baskets <- renderValueBox({...})`
in the server section.

**Output:** the full visual skeleton of all 7 tabs — boxes, empty chart areas, empty table areas,
dropdowns, sliders, buttons — but with **no numbers or charts populated yet** until the server
code runs (which happens automatically the instant the app starts).

*(For exactly what's on each of the 7 tabs, see `NUMBERS_TRACED.md` — that file already maps
every single UI element to its server code and upstream data source in full detail.)*

---

## A.7 Server — data loading (lines 419–457)

```r
server <- function(input, output, session) {
  data_store <- reactiveVal(NULL)

  observe({
    d <- list()
    tryCatch({ d$retail <- readRDS(file.path(DIR_PROC, "retail_clean.rds")) },
              error = function(e) message("retail_clean.rds: ", e$message))
    tryCatch({ d$trans <- readRDS(file.path(DIR_PROC, "transactions.rds")) }, ...)
    tryCatch({ d$sig <- readRDS(file.path(DIR_PROC, "rules_significant.rds")) }, ...)

    d$all_rules   <- load_csv("03_all_significant_rules.csv")
    d$monthly     <- load_csv("02_monthly_sales.csv")
    ... # ~15 more load_csv() calls
    data_store(d)
  })

  D <- reactive({ data_store() })
```

**What it does:**
- `reactiveVal(NULL)` creates a special Shiny variable that can hold any value and automatically
  notifies every part of the app that's using it whenever it changes.
- The `observe({...})` block runs **once**, automatically, the moment the app starts (Shiny runs
  every `observe()` block immediately and then again whenever anything it reads changes — since
  this block reads nothing reactive itself, it truly only runs once, at startup).
- Inside it, `tryCatch()` wraps each of the three `.rds` reads so that if one file is missing
  (e.g. the pipeline hasn't been run), the app prints a friendly console message instead of
  hard-crashing the whole app.
- ~18 CSV files are loaded via the safe `load_csv()` helper (§A.2) into named slots of a single
  list `d`.
- `data_store(d)` stores that entire list into the reactive value.
- `D <- reactive({ data_store() })` is a tiny wrapper — every output block later calls `d <- D()`
  to grab the current value of `data_store` in a reactive-safe way.

**Why load everything once, into one shared list, instead of each output reading its own file?**
Because disk reads are relatively slow — loading ~18 CSVs and 3 `.rds` files once at startup and
sharing them means every chart/table/KPI render is then just fast in-memory list access, not a
fresh disk read every time. This is the single biggest reason the dashboard feels instant to use
after the initial load.

**Output (console):** nothing unless a file is missing, in which case you'd see a line like
`retail_clean.rds: cannot open the connection`.

## A.8 Server — populating the Recommender dropdown (lines 460–466)

```r
observe({
  d <- D()
  if (!is.null(d$retail) && ncol(d$retail) > 0) {
    choices <- sort(unique(d$retail$Item))
    updateSelectizeInput(session, "recom_items", choices = choices, server = TRUE)
  }
})
```

**What it does:** a second `observe()` block, this time reactive on `D()` — it runs once
`data_store` is populated, and fills the Recommender tab's item-picker with every distinct
product name (`Item`), sorted alphabetically. `server = TRUE` means the searching/filtering as
the user types happens on the R server side rather than shipping all 3,765 names to the browser
up front — keeps the page fast to load.

**Output:** the Recommender tab's "Items in basket" input becomes a live, searchable product
picker instead of an empty box.

## A.9 Server — Overview tab outputs (lines 468–548)

Four `renderValueBox({...})` blocks (KPI numbers) and four `renderPlot({...})` blocks (charts).
Every single one starts with the same guard pattern:

```r
output$ov_baskets <- renderValueBox({
  d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
  valueBox(format(n_distinct(d$retail$InvoiceNo), big.mark = ","), "Baskets", icon = icon("shopping-basket"), color = "blue")
})
```

**What it does, in general terms:** grab the shared data (`d <- D()`); if it's not ready yet or
missing the needed piece, return `NULL` (Shiny just shows nothing / an empty box, no crash);
otherwise compute the number/plot and return it. The four KPIs are: distinct basket count,
distinct product count, rule count, and total revenue. The four charts are: monthly revenue
(bar), top-10 products by basket frequency (horizontal bar), a weekday×hour heatmap (the only
Overview chart computed live rather than from a CSV), and top-10 countries by revenue (horizontal
bar).

**Output:** the 4 KPI cards populate with real numbers (18,273 / 3,765 / 2,215 / GBP 9,658,813),
and the four charts render below them.

## A.10 Server — EDA tab outputs (lines 552–594)

Two charts driven by dropdown inputs (`eda_freq_n`, `eda_rev_n`), and one live-computed
histogram:

```r
output$eda_freq_plot <- renderPlot({
  d <- D(); ...
  n <- as.integer(input$eda_freq_n) %||% 20
  head(d$top_freq, n) %>% mutate(Item = reorder(Item, Baskets)) %>%
    ggplot(aes(Item, Baskets)) + geom_col(...) + coord_flip() + ...
})
```

**What it does:** reads the currently selected dropdown value (`input$eda_freq_n`), re-slices the
already-sorted top-50 items table to just that many rows, and redraws. Because this reads a
reactive `input$` value inside `renderPlot`, **Shiny automatically re-runs this block every time
the dropdown changes** — no explicit "on change" handler needed; that's the core of Shiny's
reactive programming model.

The basket-size histogram (`eda_basket`, lines 582–594) is computed fully live:
```r
bs <- d$retail %>% count(InvoiceNo, name = "BasketSize")
mn <- round(mean(bs$BasketSize), 1); md <- median(bs$BasketSize)
```
— it counts distinct products per basket on the spot, and the mean/median shown in the subtitle
are computed right there too, not read from any pre-saved file.

**Output:** two adjustable bar charts (10/15/20/25/30/50 items, chosen live by the user) plus a
histogram with a caption like "Mean = 28.2 items | Median = 17 items."

## A.11 Server — Rules tab outputs (lines 598–639)

```r
output$rules_stats <- renderPrint({
  d <- D(); if (is.null(d) || is.null(d$sig)) { cat("Rules not loaded...\n"); return() }
  cat("SIGNIFICANT ASSOCIATION RULES\n")
  q <- quality(d$sig)
  cat(sprintf("Total rules : %d\n", length(d$sig)))
  cat(sprintf("Support     : %.4f – %.4f\n", min(q$support), max(q$support)))
  cat(sprintf("Confidence  : %.3f – %.3f\n", min(q$confidence), max(q$confidence)))
  cat(sprintf("Lift        : %.2f – %.2f\n", min(q$lift), max(q$lift)))
  cat(sprintf("Mean lift   : %.2f\n", mean(q$lift)))
})
```

**What it does:** `quality(d$sig)` pulls out the support/confidence/lift vectors that `arules`
stores alongside the 2,215-rule object. `renderPrint` captures whatever gets `cat()`'d or
printed and shows it as plain monospace text (like a console). This is the **one place in the
whole dashboard** where summary statistics are computed live, directly against the loaded rule
object, rather than read from a pre-made CSV.

Below that: 4 `renderDT({...})` blocks, each just wrapping a CSV in `DT::datatable(..., filter =
"top")` — no computation, just interactive display (search boxes per column, sortable headers,
pagination).

**Output:** a monospace text block showing the rule-count/support/confidence/lift ranges, plus
two static images (threshold sensitivity, top-20-by-lift bars), a scatter-plot image, and four
searchable data tables.

## A.12 Server — Explorer tab logic (lines 643–678)

```r
observeEvent(input$exp_apply, {
  d <- D()
  q <- quality(d$sig)
  min_lift <- input$exp_min_lift %||% 1
  min_conf <- input$exp_min_conf %||% 0
  min_supp <- input$exp_min_supp %||% 0
  max_r <- input$exp_max %||% 300
  search <- trimws(input$exp_search %||% "")

  keep <- q$lift >= min_lift & q$confidence >= min_conf & q$support >= min_supp
  filtered <- d$sig[keep]
  if (length(filtered) > max_r) filtered <- head(sort(filtered, by = "lift", decreasing = TRUE), max_r)

  df <- arules::DATAFRAME(filtered, setStart = "", setEnd = "", itemSep = " + ")
  names(df)[1:2] <- c("Antecedent", "Consequent")
  ...
  if (nchar(search) > 0) {
    combined <- paste(df$Antecedent, df$Consequent)
    df <- df[grepl(search, combined, ignore.case = TRUE), ]
  }
  output$exp_table <- renderDT({ ... datatable(df, ...) })
}, ignoreNULL = FALSE)
```

**What it does — this is the app's most "computational" moment:**
1. `observeEvent(input$exp_apply, {...})` means this whole block **only runs when the "Apply
   Filters" button is clicked** — not continuously as sliders are dragged. This is a deliberate
   performance choice: filtering 2,215 rules and rebuilding a table on every pixel of slider drag
   would feel laggy; requiring a button click batches it into one clean recompute per click.
2. `keep` is a `TRUE`/`FALSE` vector, one entry per rule, `TRUE` only if that rule's own lift,
   confidence, AND support (read from `quality()`) all clear the three slider thresholds
   simultaneously (`&` = logical AND, applied element-wise across all 2,215 rules at once — this
   is vectorised R, not a loop).
3. `d$sig[keep]` subsets the *actual rule object* (not just a table) down to only the kept rules
   — `arules` supports indexing its rule objects directly with a logical vector, just like a
   normal R vector.
4. If still more than `max_r` rules remain, it keeps only the top-lift ones up to that cap.
5. Converts to a plain data frame for display, and (if a keyword was typed) keeps only rows
   whose combined Antecedent+Consequent text contains that keyword, case-insensitively
   (`grepl(..., ignore.case = TRUE)`).
6. Builds the interactive table.

**Output:** a live-filtered, searchable table showing only rules meeting the chosen
lift/confidence/support minimums and (optionally) an item-name keyword — updates every time
"Apply Filters" is clicked. Also shows two static images below (network graph, parallel
coordinates) that never change regardless of the filter.

## A.13 Server — Segments tab outputs (lines 682–757)

Mostly straightforward CSV-to-table/chart wraps, plus two live-computed KPI boxes:

```r
output$seg_uk_baskets <- renderValueBox({
  d <- D(); n_uk <- n_distinct(d$retail$InvoiceNo[d$retail$Country == "United Kingdom"])
  valueBox(format(n_uk, big.mark = ","), "UK Baskets", ...)
})
```

**What it does:** filters `d$retail` (the raw cleaned dataset, in memory) down to UK rows and
counts distinct invoices — computed live, not from a CSV. The "UK Top Rules"/"Intl Top Rules"
boxes just take `nrow()` of the (already top-25-capped) segment CSV files.

Below that: a grouped bar chart (`seg_bar`), a summary table (`seg_table`), two rule tables (UK
and International), and a seasonal comparison section with its own bar chart and a
"festive-only" rules table — all straightforward reads of the segment/season CSVs produced by
`R/05_segments_and_recommendations.R`.

**Output:** 4 KPI boxes, 1 bar chart, 1 summary table, 2 rule tables side by side, 1 seasonal
bar chart, and 1 festive-only-rules table.

## A.14 Server — Recommender tab logic (lines 761–867)

This is the app's most "interactive/algorithmic" tab. Broken into 4 pieces:

**(1) Three static info boxes** (lines 762–770) — just labels restating what Lift/Confidence/
Support mean; no computation.

**(2) The recommendation engine** (lines 772–830), triggered by clicking "Get Recommendations":
```r
observeEvent(input$recom_go, {
  d <- D()
  if (is.null(d) || is.null(d$sig) || length(d$sig) == 0) { ... return() }
  basket <- input$recom_items
  if (length(basket) == 0) { ... return() }

  sig <- d$sig
  LHS_LIST <- as(lhs(sig), "list")
  RHS_ITEM <- unlist(as(rhs(sig), "list"))
  QUAL <- quality(sig)

  fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
  if (!any(fires)) { ... return() }

  rec <- data.frame(Recommendation = RHS_ITEM[fires], Confidence = round(QUAL$confidence[fires], 3),
                     Lift = round(QUAL$lift[fires], 2), Support = round(QUAL$support[fires], 4))
  rec <- rec[!rec$Recommendation %in% basket, , drop = FALSE]
  rec <- rec[order(-rec$Lift), ]
  rec <- rec[!duplicated(rec$Recommendation), ]
  rec <- head(rec, 10)
  rec$Rank <- seq_len(nrow(rec))
  output$recom_table <- renderDT({ datatable(rec, ...) })
}, ignoreNULL = FALSE)
```
**What it does, step by step:**
1. Two early-exit guards: if rules aren't loaded, or the user picked no items, show a friendly
   message and stop.
2. `lhs(sig)`/`rhs(sig)` are `arules` accessor functions pulling out every rule's left-hand-side
   (antecedent) and right-hand-side (consequent) item sets. Converting to plain R lists makes
   them easy to loop/check with base R functions.
3. `fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))` is the heart of the
   recommender: for every single rule, check whether **every item in that rule's antecedent is
   present in the user's current basket**. `vapply` runs this check once per rule and returns a
   clean logical vector the same length as the rule set — `TRUE` means that rule "fires" for this
   basket.
4. Build a small data frame of just the firing rules' consequent + their own confidence/lift/
   support.
5. Remove anything already in the basket, sort by lift descending, keep only the best-lift entry
   per distinct product name (dedup), cap at 10, and add a `Rank` column for display.

**(3) Three "Sample Basket" buttons** (lines 832–867) — each seeds R's random number generator
to a *fixed* value (`set.seed(7)`, `set.seed(42)`, `set.seed(99)`) before randomly picking one
real basket (size 3–8, or 4–10 for Sample 3) from `transactions.rds`, then pre-fills the first 5
of its items into the dropdown. Because the seed is fixed, the "random" pick is actually always
the *same* basket every time a given button is clicked.

**Output:** clicking "Get Recommendations" produces a ranked table of up to 10 recommended
products with Lift/Confidence/Support columns; clicking a Sample button auto-fills the basket
input with a real historical basket's items so the user has something to try immediately.

## A.15 Server — Cross-Sell tab outputs (lines 871–948)

Four KPI boxes (Total Revenue Opportunity, Best Single Opportunity, Average Lift, Products with
Opportunity), each reading from `d$cs_best` (the **deduplicated** best-rule-per-product cross-
sell CSV), plus one static PNG and one interactive, sort/filterable table:

```r
output$cs_table <- renderDT({
  d <- D()
  min_lift_val <- as.numeric(input$cs_minlift %||% 0)
  sort_col <- input$cs_sort %||% "PotentialRevenue"

  df <- d$cs_best
  if (min_lift_val > 0) df <- df[df$Lift >= min_lift_val, ]
  if (sort_col %in% names(df)) df <- arrange(df, desc(.data[[sort_col]]))

  if ("Rule" %in% names(df)) df$Rule <- ifelse(nchar(df$Rule) > 75, paste0(substr(df$Rule,1,72),"..."), df$Rule)
  if ("Consequent" %in% names(df)) df$Consequent <- ifelse(nchar(df$Consequent) > 40, paste0(substr(df$Consequent,1,37),"..."), df$Consequent)

  datatable(df, options = list(pageLength = 20, scrollX = TRUE), filter = "top", ...)
})
```

**What it does:** reads the user's sort-column and min-lift choices from two dropdowns, filters
the deduplicated cross-sell table by minimum lift if set, sorts descending by whichever column
was picked (`.data[[sort_col]]` is dynamic/programmatic column selection — lets one block of code
sort by any of 4 different columns depending on user choice, using `dplyr`'s tidy-eval), and
truncates any overly long text fields purely for table display (the underlying numeric values
are untouched).

**Output:** 4 KPI boxes (GBP totals and counts), 1 static bar chart image of the top 15
opportunities, and 1 sortable/filterable table of every cross-sell opportunity.

## A.16 The final line (line 952)

```r
shinyApp(ui = ui, server = server)
```
**What it does:** hands the `ui` object and the `server` function to Shiny's app-constructor.
This is what actually turns "a UI description + a server function" into a runnable web
application object. Running `shiny::runApp("app.R")` (or clicking "Run App" in RStudio) starts a
local web server hosting this app and opens it in a browser.

---

# PART B — Viva / Exam Prep: Likely Questions & Model Answers

### Q1. Why is `app.R` split into `ui` and `server`? What's the difference?
**A:** Shiny apps always separate **what the page looks like** (`ui`) from **what computes the
values shown on it** (`server`). `ui` is a static description built once when the app starts —
boxes, plot placeholders, inputs — and never changes structure while the app runs. `server` is a
function that runs *per user session*, computing every output value and reacting to input
changes. This separation is what lets Shiny automatically re-run only the specific outputs that
depend on a changed input, instead of redrawing the whole page.

### Q2. What is "reactivity" in Shiny, and where does it show up in this app?
**A:** Reactivity means an output automatically recalculates whenever a reactive value it reads
(an `input$...` or a `reactive()`/`reactiveVal()`) changes — without the programmer writing any
explicit "on change" event-wiring. Example: the EDA tab's `eda_freq_plot` chart reads
`input$eda_freq_n` inside `renderPlot({...})`; the instant the user picks a different dropdown
value, Shiny detects that dependency and re-runs just that chart, nothing else.

### Q3. Why does the app load all its data into one shared `data_store` instead of each output
reading its own file?
**A:** Performance and consistency. Reading ~18 CSVs and 3 `.rds` files from disk is comparatively
slow; doing it once at startup and sharing the result via `reactiveVal`/`reactive()` means every
individual chart/table/KPI just does fast in-memory list access. It also guarantees every tab is
looking at the exact same snapshot of the data.

### Q4. What does `d$sig[keep]` do, and why is it interesting?
**A:** `d$sig` is not a plain data frame — it's an `arules` "rules" S4 object. `arules` supports
indexing that object directly with a logical vector (`keep`), just like subsetting a normal R
vector, and returns a smaller rules object with the same structure. This lets the Explorer tab
filter thousands of rules by threshold conditions in one vectorised line, without ever converting
to a data frame until after filtering.

### Q5. Explain the recommender's core matching rule (`fires <- vapply(...)`), in plain words.
**A:** For each of the 2,215 rules, look at its antecedent (left-hand side) — the rule "fires"
only if **every single item in that antecedent** is present in the user's current selected
basket. `all(l %in% basket)` checks that condition for one rule; `vapply` repeats it across every
rule and returns one `TRUE`/`FALSE` per rule. Only firing rules contribute a recommended item
(their consequent).

### Q6. Why does the recommender remove duplicate recommendations and cap the list at 10?
**A:** Many different rules can point at the *same* consequent product (e.g., five different
antecedent combinations might all suggest "REGENCY CAKESTAND 3 TIER"). Sorting by lift first,
then removing duplicates by product name, keeps only each product's single strongest (highest
lift) supporting rule and avoids showing the same recommended product multiple times. Capping at
10 keeps the result list short and usable for the end user.

### Q7. Why are the "Sample Basket" buttons deterministic despite calling `sample()`?
**A:** Each button calls `set.seed(<fixed number>)` immediately before `sample()`. Setting a seed
fixes R's pseudo-random number generator to a specific, repeatable starting sequence, so
`sample()` always returns the exact same "random" pick given the same seed — making the demo
buttons reproducible across every session and every user, even though `sample()` looks random.

### Q8. What's the difference between the KPI "UK Top Rules" number and the "Rules" column in
the Segment Comparison Summary table?
**A:** "UK Top Rules" is `nrow()` of `05_top_rules_uk.csv`, which was deliberately capped to the
top 25 rules by lift when it was generated — so that KPI can never show more than 25. The
Segment Comparison Summary table's "Rules" column comes from `05_segment_comparison.csv`, which
records the segment's **true total rule count** from its independent Apriori re-mine (thousands,
not capped at 25). They intentionally measure different things and are not meant to match.

### Q9. Why does the app never crash even if the pipeline hasn't been run yet?
**A:** Two defensive helper functions, `load_csv()` and `show_fig()`, wrap every file access.
`load_csv()` returns a placeholder one-row data frame (`"<file> not found."`) instead of throwing
an error if a CSV is missing; `show_fig()` returns a "Figure not found" placeholder `div()`
instead of a broken image tag if a PNG is missing. Additionally, the three critical `.rds` reads
are wrapped in `tryCatch()` so a missing pipeline output is logged as a message rather than
stopping the whole app. Every `render*` block also starts with an `is.null()` guard that
`return(NULL)`s early if the needed data piece isn't available.

### Q10. Where does the number **2,215** (Significant Rules) actually get computed, and does
`app.R` recompute it?
**A:** No — `app.R` never runs Apriori or any of its filtering steps. That number is simply
`length(d$sig)`, where `d$sig` is the `arules` rules object loaded straight from
`rules_significant.rds`. That object was produced once, offline, by `R/03_apriori.R`, after
passing through the lift filter, redundancy removal, Fisher's exact test, and Benjamini-Hochberg
correction. The dashboard only *counts* an already-finished object.

### Q11. Why is the GBP 1.02M figure computed from `05_cross_sell_best_rule_per_product.csv`
and not the full `05_cross_sell_opportunity_value.csv`?
**A:** The full file has one row per rule, and many rules share the same consequent and overlap
on the same "missed" baskets, so summing its `PotentialRevenue` column would double- (or
triple-) count the same opportunity multiple times. The "best rule per product" file keeps only
the single highest-revenue rule for each distinct consequent product, so summing it counts each
product's opportunity exactly once — a defensible, non-inflated total. `app.R`'s Cross-Sell KPI
sums exactly this deduplicated file (`app.R:872-883`).

### Q12. What R package does the actual Apriori algorithm live in, and does `app.R` import it?
**A:** The `arules` package. Yes — `app.R` explicitly `library(arules)`s it (line 15), because
several *live* operations depend on `arules` functions at runtime: `quality()` (Rules tab
stats, Explorer filter), `lhs()`/`rhs()` (Recommender matching), and indexing/sorting the rules
S4 object directly (`d$sig[keep]`, `sort(filtered, by = "lift")`). Even though Apriori itself
only ever runs offline in the pipeline scripts, the app still needs `arules` loaded to
manipulate the already-mined rule objects.

### Q13. What is `DT::datatable()` doing that a plain R table print wouldn't?
**A:** `DT` (DataTables) renders an R data frame as an interactive HTML table with client-side
sorting (click a column header), per-column search boxes (`filter = "top"`), pagination
(`pageLength = ...`), and horizontal scrolling (`scrollX = TRUE`) for wide tables — all without
the developer writing any JavaScript; `DT` wraps a well-known jQuery table plugin automatically.

### Q14. Why does the Explorer tab require clicking "Apply Filters" instead of updating live
as sliders move?
**A:** Performance/UX design choice: `observeEvent(input$exp_apply, {...})` only fires on the
button click event, not on every intermediate slider position while dragging. If the filter
logic instead read the sliders directly inside a `renderDT`, Shiny would re-filter 2,215 rules
and rebuild the whole table on every pixel of drag movement, which would feel janky; batching it
behind an explicit button click keeps the UI responsive.

### Q15. What's the practical difference between a *static* output (like `show_fig("14_top_rules_by_lift_bars.png")`)
and a *live* output (like `renderPlot({ ggplot(...) })`) in this app?
**A:** A static output is a PNG image file, pre-rendered once by an offline pipeline script
(`R/02_eda.R`, `R/03_apriori.R`, `R/04_visualize_rules.R`, or `R/05_segments_and_recommendations.R`)
and just served as-is by `show_fig()` — it never changes while the app runs, no matter what the
user does. A live output is a `ggplot2` (or `DT`) object built fresh, inside the running Shiny
session, from data already loaded into memory (`d$retail`, `d$sig`, etc.) — it can respond to
user input (dropdowns, sliders, buttons) and redraw itself accordingly. The app mixes both:
static images for expensive-to-render plots (network graphs, parallel coordinates) that don't
need to be interactive, and live plots/tables for anything the user should be able to adjust.

### Q16. If you changed `PARAMS$support` in `00_setup.R` and re-ran the pipeline, would `app.R`
automatically reflect the new rules without any changes to `app.R` itself?
**A:** Yes. `app.R` contains no hardcoded thresholds or rule counts — it only reads whatever is
currently saved in `rules_significant.rds` and the various CSVs. Re-running the pipeline with a
different `PARAMS$support` would overwrite those files with a new rule set, and the next time
`app.R` starts (or is refreshed), every KPI, chart, and table that depends on rules would reflect
the new numbers automatically, with zero code changes needed in `app.R`.

### Q17. What does `session` (the third argument to `server <- function(input, output, session)`)
get used for in this app?
**A:** It's used in two places: `updateSelectizeInput(session, "recom_items", choices = ..., server = TRUE)`
(populating/searching the Recommender's product dropdown) and the same function again inside the
three Sample Basket button handlers (to programmatically set the dropdown's *selected* values).
`session` represents the specific browser connection/tab currently talking to the server, and is
required by any `update*Input()` function because those functions push a change to an
already-rendered UI element in that specific user's browser, rather than defining the UI from
scratch.

### Q18. Is there any risk of a user's slider/dropdown choice on one tab affecting another tab's
numbers?
**A:** No — each tab's interactive inputs (`input$eda_freq_n`, `input$exp_min_lift`,
`input$recom_items`, `input$cs_sort`, etc.) are only read inside that specific tab's own
`render*` blocks. They never mutate the shared `data_store`/`D()` object itself — every
interactive tab reads from the same underlying loaded data and produces a *new, separate* filtered
view for its own output each time, leaving the shared data untouched for every other tab.

### Q19. Name one number on the dashboard that is genuinely computed live inside `app.R` (not
just read from a CSV) and explain why.
**A:** The Overview tab's Weekday × Hour heatmap (`app.R:526-536`). Unlike almost every other
Overview chart, it recomputes `d$retail %>% distinct(InvoiceNo, Weekday, Hour) %>% count(Weekday, Hour)`
directly inside the `renderPlot` block, live, rather than reading a pre-aggregated CSV — even
though a nearly-identical static PNG of the same chart also exists on disk
(`05_weekday_hour_heatmap.png`, made by `R/02_eda.R`). Another example: the Rules tab's
"Rule Statistics" text box (`app.R:599-614`), which calls `quality(d$sig)` and computes
min/max/mean directly from the loaded rule object every time it renders.

### Q20. What would happen if `rules_significant.rds` existed but `transactions.rds` did not?
**A:** `d$trans` would end up `NULL` (caught by the `tryCatch` at `app.R:429-431`). The
Recommender tab's "Get Recommendations" button and Rules/Explorer tabs would still work fine
since they only need `d$sig`. But the three "Sample Basket" buttons would silently do nothing,
since their handlers guard with `if (is.null(d) || is.null(d$trans)) return()` (e.g.
`app.R:833-834`) — clicking them just wouldn't populate the basket, with no error shown to the
user.
