# =============================================================================
# Basket Lens -- Market Basket Analysis Dashboard
# UCI Online Retail dataset | Apriori + Association Rules
# =============================================================================

options(shiny.autoload.r = FALSE)

library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)
library(arules)

# ---- Paths -----------------------------------------------------------
PROJ_ROOT <- ifelse(basename(getwd()) == "R", dirname(getwd()), getwd())
DIR_PROC  <- file.path(PROJ_ROOT, "data", "processed")
DIR_FIG   <- file.path(PROJ_ROOT, "output", "figures")
DIR_TAB   <- file.path(PROJ_ROOT, "output", "tables")

# Register resource path for images so browsers can load them directly via HTTP
shiny::addResourcePath("figures", DIR_FIG)

# ---- Theme -----------------------------------------------------------
mba_theme <- function(bs = 12) {
  theme_minimal(base_size = bs) +
    theme(
      plot.title = element_text(face = "bold", size = bs + 2, colour = "#1a2332"),
      plot.subtitle = element_text(colour = "grey50"),
      panel.grid.minor = element_blank(),
      axis.title = element_text(colour = "grey35"),
      legend.title = element_text(face = "bold"),
      plot.background = element_rect(fill = "white", colour = NA),
      axis.text.x = element_text(colour = "grey40"),
      axis.text.y = element_text(colour = "grey40")
    )
}

mba_colors <- c(
  primary = "#1565C0", # deep blue
  accent  = "#00ACC1", # teal
  danger  = "#E53935", # red
  success = "#2E7D32", # green
  purple  = "#7E57C2", # purple
  orange  = "#FB8C00", # orange
  dark    = "#1a2332", # sidebar
  card_bg = "#f8f9fa"
)

# ---- Safe figure loader -----------------------------------------------
`%||%` <- function(a, b) if (is.null(a)) b else a

show_fig <- function(name, width = "100%") {
  img_path <- file.path(DIR_FIG, name)
  if (file.exists(img_path)) {
    tags$div(
      style = "text-align:center; padding: 6px;",
      tags$img(
        src = paste0("figures/", name),
        style = paste0("width:100%; max-width:", width %||% "100%",
                       "; height:auto; display:block; margin:0 auto; border-radius:8px; box-shadow:0 2px 6px rgba(0,0,0,0.06);")
      )
    )
  } else {
    div(style = "padding:40px; text-align:center; color:#999;",
        icon("image", class = "fa-3x"), br(),
        paste("Figure", name, "not found. Run the pipeline first."))
  }
}

# ---- Safe CSV loader ----------------------------------------------
load_csv <- function(name) {
  path <- file.path(DIR_TAB, name)
  if (file.exists(path)) {
    read.csv(path, stringsAsFactors = FALSE)
  } else {
    data.frame(Note = paste(name, "not found."))
  }
}

# =============================================================================
# UI
# =============================================================================
ui <- dashboardPage(
  dashboardHeader(
    title = tagList(
      img(src = "https://em-content.zobj.net/source/microsoft-teams/337/shopping-cart_1f6d2.png",
          height = "28px", style = "margin-right:8px; vertical-align:middle;"),
      span("Basket Lens", style = "font-weight:700; font-size:18px; letter-spacing:0.5px;")
    ),
    tags$li(class = "dropdown", tags$a(
      href = "https://github.com/joshua-mint", target = "_blank",
      icon("github"), style = "font-size:16px; padding:14px 18px;"
    ))
  ),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("gauge-high")),
      menuItem("Exploratory", tabName = "eda", icon = icon("chart-column")),
      menuItem("Rules", tabName = "rules", icon = icon("circle-nodes")),
      menuItem("Explorer", tabName = "explorer", icon = icon("magnifying-glass")),
      menuItem("Segments", tabName = "segments", icon = icon("globe")),
      menuItem("Recommender", tabName = "recom", icon = icon("wand-magic-sparkles")),
      menuItem("Cross-Sell", tabName = "crosssell", icon = icon("pound-sign")),
      style = "padding-top:10px;"
    ),
    tags$hr(),
    tags$div(style = "padding:0 20px 10px; color:#8a9aaa; font-size:11px;",
             p("Built with R Shiny"),
             p("UCI Online Retail Dataset"),
             p("Apriori Association Mining"))
  ),

  dashboardBody(
    tags$head(
      tags$link(rel = "stylesheet",
                href = "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap"),
      tags$style(HTML("
        body, .main-sidebar { font-family: 'Inter', sans-serif; }
        .skin-blue .main-sidebar { background: linear-gradient(180deg, #1a2332 0%, #1e293b 100%); }
        .skin-blue .main-sidebar .sidebar-menu > li > a { color: #b0bec5; font-weight:500; }
        .skin-blue .main-sidebar .sidebar-menu > li.active > a {
          background: rgba(21,101,192,0.15); color: #64b5f6;
          border-left: 3px solid #42a5f5; font-weight:600;
        }
        .skin-blue .main-sidebar .sidebar-menu > li > a:hover {
          background: rgba(21,101,192,0.08); color: #e0e0e0;
        }
        .skin-blue .main-header .navbar { background: #1a2332; }
        .skin-blue .main-header .logo { background: #111922; }
        .skin-blue .main-header .logo a { color: #fff; font-weight:700; }
        .skin-blue .main-header .navbar .sidebar-toggle:hover { background: #233040; }
        .small-box { border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); border:none; }
        .small-box .inner { padding: 16px 20px; }
        .small-box .icon { line-height: 56px; opacity:0.85; }
        .small-box .inner h3 { font-weight:700; font-size:26px; }
        .small-box .inner p { font-weight:500; font-size:13px; }
        .small-box > .small-box-footer { border-radius:0 0 10px 10px; padding:6px; font-size:12px; }
        .box { border-radius: 10px; box-shadow: 0 1px 4px rgba(0,0,0,0.06); border: 1px solid #e8ecf1; }
        .box-header.with-border { border-bottom: 2px solid #e8ecf1; }
        .box.box-primary { border-top-color: #1565C0; }
        .box.box-info { border-top-color: #00ACC1; }
        .box.box-danger { border-top-color: #E53935; }
        .box.box-warning { border-top-color: #FB8C00; }
        .box.box-success { border-top-color: #2E7D32; }
        .box.box-purple { border-top-color: #7E57C2; }
        .box-title { font-weight:600; font-size:14px; letter-spacing:0.3px; }
        .nav-tabs-custom > .nav-tabs > li.active > a { border-top-color: #42a5f5; font-weight:600; }
        .btn-primary { background: #1565C0; border-color: #1565C0; font-weight:600; }
        .btn-primary:hover { background: #0D47A1; }
        .btn-info { background: #00ACC1; border-color: #00ACC1; font-weight:600; }
        .btn-warning { background: #FB8C00; border-color: #FB8C00; font-weight:600; color:#fff; }
        .btn-success { background: #2E7D32; border-color: #2E7D32; font-weight:600; }
        .btn-danger { background: #E53935; border-color: #E53935; font-weight:600; }
        table.dataTable thead th { font-size:11px; font-weight:600; color:#37474f; }
        .dataTables_wrapper .dataTables_length,
        .dataTables_wrapper .dataTables_filter { padding:8px 0; font-size:12px; }
        .tab-pane h4 { color: #1a2332; }
        hr { border-color: #e8ecf1; }
      "))
    ),

    tabItems(

      # =================================================================
      # OVERVIEW
      # =================================================================
      tabItem(tabName = "overview",
        fluidRow(
          valueBoxOutput("ov_baskets", width = 3),
          valueBoxOutput("ov_products", width = 3),
          valueBoxOutput("ov_rules", width = 3),
          valueBoxOutput("ov_revenue", width = 3)
        ),
        fluidRow(
          box(title = "Monthly Revenue Trend", status = "primary", solidHeader = TRUE, width = 8,
              plotOutput("ov_monthly", height = "340px")),
          box(title = "Top 10 Products by Frequency", status = "info", solidHeader = TRUE, width = 4,
              plotOutput("ov_top10", height = "340px"))
        ),
        fluidRow(
          box(title = "Trading Rhythm: Weekday x Hour", status = "warning", solidHeader = TRUE, width = 6,
              plotOutput("ov_heatmap", height = "360px")),
          box(title = "Top Countries by Revenue", status = "success", solidHeader = TRUE, width = 6,
              plotOutput("ov_countries", height = "360px"))
        )
      ),

      # =================================================================
      # EDA
      # =================================================================
      tabItem(tabName = "eda",
        fluidRow(
          box(title = "Top Products by Basket Frequency", status = "info", solidHeader = TRUE, width = 6,
              selectInput("eda_freq_n", "Show top N items",
                          choices = c(10, 15, 20, 25, 30, 50), selected = 20, width = "40%"),
              plotOutput("eda_freq_plot", height = "500px")),
          box(title = "Top Products by Revenue", status = "info", solidHeader = TRUE, width = 6,
              selectInput("eda_rev_n", "Show top N items",
                          choices = c(10, 15, 20, 25, 30, 50), selected = 20, width = "40%"),
              plotOutput("eda_rev_plot", height = "500px"))
        ),
        fluidRow(
          box(title = "Basket Size Distribution", status = "primary", solidHeader = TRUE, width = 6,
              plotOutput("eda_basket", height = "400px")),
          box(title = "Relative Item Frequency", status = "primary", solidHeader = TRUE, width = 6,
              show_fig("07_item_frequency_relative.png", "100%"))
        )
      ),

      # =================================================================
      # RULES
      # =================================================================
      tabItem(tabName = "rules",
        fluidRow(
          box(title = "How do rule counts react to threshold pairs?", status = "warning",
              solidHeader = TRUE, width = 8,
              show_fig("08_threshold_sensitivity.png", "100%")),
          box(title = "Rule Statistics", status = "info", solidHeader = TRUE, width = 4,
              verbatimTextOutput("rules_stats"),
              tags$div(style = "padding:10px; font-size:13px; color:#555;",
                       p("Rules are filtered by Fisher's exact test with Benjamini-Hochberg correction (p < 0.05)."),
                       p("Redundant rules are removed so each rule adds distinct predictive value."),
                       p("Only rules with lift > 1 are kept, meaning they outperform random chance.")))
        ),
        fluidRow(
          box(title = "Top 20 Rules by Lift", status = "danger", solidHeader = TRUE, width = 6,
              show_fig("14_top_rules_by_lift_bars.png", "100%")),
          box(title = "Rule Landscape: Support vs Confidence", status = "primary",
              solidHeader = TRUE, width = 6,
              show_fig("09_rules_scatter.png", "100%"))
        ),
        fluidRow(
          tabBox(title = "Rule Tables (interactive, searchable, sortable)", width = 12,
                 tabPanel("By Lift", value = "lift", DTOutput("tab_lift")),
                 tabPanel("By Confidence", value = "conf", DTOutput("tab_conf")),
                 tabPanel("By Support", value = "supp", DTOutput("tab_supp")),
                 tabPanel("All Rules", value = "all", DTOutput("tab_all"))
          )
        )
      ),

      # =================================================================
      # EXPLORER
      # =================================================================
      tabItem(tabName = "explorer",
        fluidRow(
          box(title = "Filter Rules", status = "primary", solidHeader = TRUE, width = 3,
              h5("Thresholds"),
              sliderInput("exp_min_lift", "Min Lift", min = 1, max = 100, value = 1, step = 0.5),
              sliderInput("exp_min_conf", "Min Confidence", min = 0, max = 1, value = 0, step = 0.01),
              sliderInput("exp_min_supp", "Min Support", min = 0, max = 0.05, value = 0, step = 0.0005),
              numericInput("exp_max", "Max results", value = 300, min = 10, max = 2215),
              h5("Search"),
              textInput("exp_search", "Item keyword",
                        placeholder = "e.g. HEART, BAG, LIGHT..."),
              actionButton("exp_apply", "Apply Filters", icon = icon("filter"),
                           class = "btn-primary", width = "100%", style = "margin-top:10px;")
          ),
          box(title = "Filtered Rules", status = "primary", solidHeader = TRUE, width = 9,
              div(DTOutput("exp_table"), style = "height:620px; overflow-y:auto;"))
        ),
        fluidRow(
          box(title = "Association Network (Top 25 by Lift)", status = "primary",
              solidHeader = TRUE, width = 12, show_fig("11_rules_graph_top25_lift.png", "100%"))
        ),
        fluidRow(
          box(title = "Parallel Coordinates (Top 20 by Confidence)", status = "warning",
              solidHeader = TRUE, width = 12, show_fig("13_rules_paracoord.png", "100%"))
        )
      ),

      # =================================================================
      # SEGMENTS
      # =================================================================
      tabItem(tabName = "segments",
        fluidRow(
          valueBoxOutput("seg_uk_baskets", width = 3),
          valueBoxOutput("seg_intl_baskets", width = 3),
          valueBoxOutput("seg_uk_rules_count", width = 3),
          valueBoxOutput("seg_intl_rules_count", width = 3)
        ),
        fluidRow(
          box(title = "UK vs International: Baskets & Rules", status = "primary",
              solidHeader = TRUE, width = 6, plotOutput("seg_bar", height = "400px")),
          box(title = "Segment Comparison Summary", status = "info", solidHeader = TRUE, width = 6,
              tableOutput("seg_table"))
        ),
        fluidRow(
          box(title = "UK: Top Rules by Lift", status = "info", solidHeader = TRUE, width = 6,
              DTOutput("seg_uk_table")),
          box(title = "International: Top Rules by Lift", status = "info", solidHeader = TRUE, width = 6,
              DTOutput("seg_intl_table"))
        ),
        fluidRow(
          tabBox(title = "Seasonal Analysis", width = 12,
                 tabPanel("Festive vs Rest of Year", box(
                   title = "Pre-Christmas (Sep-Nov) vs Rest of Year",
                   status = "warning", solidHeader = TRUE, width = 12,
                   plotOutput("season_bar", height = "380px")
                 )),
                 tabPanel("Festive-Only Rules", box(
                   title = "Rules That Exist Only in the Festive Quarter",
                   status = "danger", solidHeader = TRUE, width = 12,
                   DTOutput("season_table")
                 ))
          )
        )
      ),

      # =================================================================
      # RECOMMENDER
      # =================================================================
      tabItem(tabName = "recom",
        fluidRow(
          box(title = "Basket Recommender", status = "primary", solidHeader = TRUE, width = 4,
              p("Add items to a basket and get rule-based recommendations ranked by lift.", class = "text-muted"),
              selectizeInput("recom_items", "Items in basket",
                             choices = NULL, multiple = TRUE,
                             options = list(
                               placeholder = "Start typing a product name...",
                               maxItems = 20
                             )),
              actionButton("recom_go", "Get Recommendations", icon = icon("wand-magic-sparkles"),
                           class = "btn-primary", width = "100%"),
              hr(),
              h5("Try a sample basket:"),
              fluidRow(
                column(4, actionButton("recom_s1", "Sample 1",
                                       class = "btn-default", width = "100%")),
                column(4, actionButton("recom_s2", "Sample 2",
                                       class = "btn-default", width = "100%")),
                column(4, actionButton("recom_s3", "Sample 3",
                                       class = "btn-default", width = "100%"))
              )
          ),
          box(title = "Recommended Items", status = "success", solidHeader = TRUE, width = 8,
              div(DTOutput("recom_table"), style = "min-height:200px;"))
        ),
        fluidRow(
          box(title = "How the Recommender Works", status = "info", solidHeader = TRUE, width = 12,
              h4("Rule-Based Recommendations"),
              p("This recommender matches your basket against ", strong("2,215 significant association rules."),
                " For each rule whose ", strong("antecedent (the 'if' part)"),
                " is fully contained in your basket, it suggests the ",
                strong("consequent (the 'then' part)"), " as a recommendation."),
              p("Results are ranked by ", strong("Lift"),
                " (how many times more likely the item is to appear given the basket), filtered to exclude items already in your basket."),
              fluidRow(
                column(4, valueBoxOutput("recom_metric_lift", width = 12)),
                column(4, valueBoxOutput("recom_metric_conf", width = 12)),
                column(4, valueBoxOutput("recom_metric_supp", width = 12))
              ),
              tags$hr(),
              h5("The Three Measures of Association"),
              tags$table(class = "table table-striped table-condensed",
                         tags$thead(tags$tr(
                           tags$th("Measure"), tags$th("Formula"), tags$th("Interpretation")
                         )),
                         tags$tbody(
                           tags$tr(tags$td(strong("Support")), tags$td("P(X ∩ Y)"), tags$td("How common the pattern is across all baskets")),
                           tags$tr(tags$td(strong("Confidence")), tags$td("P(Y | X)"), tags$td("How reliable the rule is when X is present")),
                           tags$tr(tags$td(strong("Lift")), tags$td("conf / supp(Y)"), tags$td("How much better than chance; > 1 means positive association"))
                         ))
          )
        )
      ),

      # =================================================================
      # CROSS-SELL
      # =================================================================
      tabItem(tabName = "crosssell",
        fluidRow(
          valueBoxOutput("cs_total_opp", width = 3),
          valueBoxOutput("cs_best_single", width = 3),
          valueBoxOutput("cs_avg_lift", width = 3),
          valueBoxOutput("cs_products", width = 3)
        ),
        fluidRow(
          box(title = "Top 15 Cross-Sell Opportunities by Estimated Revenue",
              status = "danger", solidHeader = TRUE, width = 12,
              show_fig("15_cross_sell_opportunity_value.png", "100%"))
        ),
        fluidRow(
          box(title = "All Cross-Sell Opportunities", status = "info",
              solidHeader = TRUE, width = 12,
              fluidRow(
                column(4,
                       selectInput("cs_sort", "Sort by:",
                                   choices = c(
                                     "PotentialRevenue" = "PotentialRevenue",
                                     "Lift" = "Lift",
                                     "Confidence" = "Confidence",
                                     "MissedBaskets" = "MissedBaskets"
                                   ),
                                   selected = "PotentialRevenue")
                ),
                column(4,
                       selectInput("cs_minlift", "Min Lift:",
                                   choices = c("Any" = "0", "1.5" = "1.5",
                                               "2" = "2", "3" = "3", "5" = "5", "10" = "10"),
                                   selected = "0")
                )
              ),
              DTOutput("cs_table")
          )
        )
      )
    )
  )
)

# =============================================================================
# SERVER
# =============================================================================
server <- function(input, output, session) {

  # ---- Load all data ---------------------------------------------------
  data_store <- reactiveVal(NULL)

  observe({
    d <- list()
    tryCatch({
      d$retail <- readRDS(file.path(DIR_PROC, "retail_clean.rds"))
    }, error = function(e) message("retail_clean.rds: ", e$message))
    tryCatch({
      d$trans <- readRDS(file.path(DIR_PROC, "transactions.rds"))
    }, error = function(e) message("transactions.rds: ", e$message))
    tryCatch({
      d$sig <- readRDS(file.path(DIR_PROC, "rules_significant.rds"))
    }, error = function(e) message("rules_significant.rds: ", e$message))
    
    d$all_rules   <- load_csv("03_all_significant_rules.csv")
    d$monthly     <- load_csv("02_monthly_sales.csv")
    d$by_country  <- load_csv("02_by_country.csv")
    d$top_freq    <- load_csv("02_top50_items_by_frequency.csv")
    d$top_rev     <- load_csv("02_top50_items_by_revenue.csv")
    d$basket_stats <- load_csv("02_basket_size_stats.csv")
    d$sens        <- load_csv("03_threshold_sensitivity.csv")
    d$rules_lift  <- load_csv("03_top_rules_by_lift.csv")
    d$rules_conf  <- load_csv("03_top_rules_by_confidence.csv")
    d$rules_supp  <- load_csv("03_top_rules_by_support.csv")
    d$seg_comp    <- load_csv("05_segment_comparison.csv")
    d$uk_rules    <- load_csv("05_top_rules_uk.csv")
    d$intl_rules  <- load_csv("05_top_rules_international.csv")
    d$season_comp <- load_csv("05_season_comparison.csv")
    d$festive     <- load_csv("05_festive_only_rules.csv")
    d$cs_best     <- load_csv("05_cross_sell_best_rule_per_product.csv")
    d$cs_all      <- load_csv("05_cross_sell_opportunity_value.csv")
    d$recom_demo  <- load_csv("05_recommender_demo.csv")
    data_store(d)
  })

  D <- reactive({ data_store() })

  # -- Populate recommender dropdown -----------------------------------
  observe({
    d <- D()
    if (!is.null(d$retail) && ncol(d$retail) > 0) {
      choices <- sort(unique(d$retail$Item))
      updateSelectizeInput(session, "recom_items", choices = choices, server = TRUE)
    }
  })

  # =================================================================
  # OVERVIEW
  # =================================================================
  output$ov_baskets <- renderValueBox({
    d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
    valueBox(
      format(n_distinct(d$retail$InvoiceNo), big.mark = ","),
      "Baskets", icon = icon("shopping-basket"), color = "blue"
    )
  })
  output$ov_products <- renderValueBox({
    d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
    valueBox(
      format(n_distinct(d$retail$Item), big.mark = ","),
      "Unique Products", icon = icon("tags"), color = "teal"
    )
  })
  output$ov_rules <- renderValueBox({
    d <- D(); if (is.null(d) || is.null(d$sig)) return(NULL)
    valueBox(
      format(length(d$sig), big.mark = ","),
      "Significant Rules", icon = icon("circle-nodes"), color = "red"
    )
  })
  output$ov_revenue <- renderValueBox({
    d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
    valueBox(
      paste0("GBP ", format(round(sum(d$retail$Revenue)), big.mark = ",")),
      "Total Revenue", icon = icon("pound-sign"), color = "orange"
    )
  })

  output$ov_monthly <- renderPlot({
    d <- D(); if (is.null(d) || nrow(d$monthly) == 0 || "Note" %in% names(d$monthly)) return(NULL)
    d$monthly %>%
      mutate(Month = as.Date(Month)) %>%
      ggplot(aes(Month, Revenue)) +
      geom_col(fill = "#D94801", width = 18) +
      scale_y_continuous(labels = label_number(prefix = "GBP ", scale = 1e-3, suffix = "k")) +
      scale_x_date(date_labels = "%b %y", date_breaks = "1 month") +
      labs(title = "Monthly Revenue", x = NULL, y = "Revenue") +
      mba_theme() + theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })

  output$ov_top10 <- renderPlot({
    d <- D(); if (is.null(d) || nrow(d$top_freq) == 0 || "Note" %in% names(d$top_freq)) return(NULL)
    head(d$top_freq, 10) %>%
      mutate(Item = reorder(Item, Baskets)) %>%
      ggplot(aes(Item, Baskets)) +
      geom_col(fill = "#2C7FB8") +
      geom_text(aes(label = format(Baskets, big.mark = ",")),
                hjust = -0.15, size = 2.6) +
      coord_flip() +
      scale_y_continuous(expand = expansion(mult = c(0, .12)), labels = comma) +
      labs(title = "Top 10 by basket frequency", x = NULL, y = "Baskets") +
      mba_theme(10)
  })

  output$ov_heatmap <- renderPlot({
    d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
    d$retail %>%
      distinct(InvoiceNo, Weekday, Hour) %>%
      count(Weekday, Hour, name = "Transactions") %>%
      ggplot(aes(x = Hour, y = Weekday, fill = Transactions)) +
      geom_tile(colour = "white") +
      scale_fill_distiller(palette = "YlGnBu", direction = 1, labels = comma) +
      labs(title = "Trading rhythm: weekday x hour", x = "Hour of day", y = NULL) +
      mba_theme()
  })

  output$ov_countries <- renderPlot({
    d <- D(); if (is.null(d) || nrow(d$by_country) == 0 || "Note" %in% names(d$by_country)) return(NULL)
    head(arrange(d$by_country, desc(Revenue)), 10) %>%
      mutate(Country = reorder(Country, Revenue)) %>%
      ggplot(aes(Country, Revenue)) +
      geom_col(fill = "#7A0177") +
      coord_flip() +
      scale_y_continuous(labels = label_number(prefix = "GBP ", scale = 1e-3, suffix = "k")) +
      labs(title = "Top 10 countries by revenue", x = NULL, y = "Revenue") +
      mba_theme(10)
  })

  # =================================================================
  # EDA
  # =================================================================
  output$eda_freq_plot <- renderPlot({
    d <- D(); if (is.null(d) || nrow(d$top_freq) == 0 || "Note" %in% names(d$top_freq)) return(NULL)
    n <- as.integer(input$eda_freq_n) %||% 20
    head(d$top_freq, n) %>%
      mutate(Item = reorder(Item, Baskets)) %>%
      ggplot(aes(Item, Baskets)) +
      geom_col(fill = "#2C7FB8") +
      geom_text(aes(label = format(Baskets, big.mark = ",")),
                hjust = -0.1, size = 3) +
      coord_flip() +
      scale_y_continuous(expand = expansion(mult = c(0, .12)), labels = comma) +
      labs(title = paste("Top", n, "products by basket frequency"),
           subtitle = "UCI Online Retail (Dec 2010 – Dec 2011)", x = NULL, y = "Baskets") +
      mba_theme(11)
  })

  output$eda_rev_plot <- renderPlot({
    d <- D(); if (is.null(d) || nrow(d$top_rev) == 0 || "Note" %in% names(d$top_rev)) return(NULL)
    n <- as.integer(input$eda_rev_n) %||% 20
    head(d$top_rev, n) %>%
      mutate(Item = reorder(Item, Revenue)) %>%
      ggplot(aes(Item, Revenue)) +
      geom_col(fill = "#238B45") +
      coord_flip() +
      scale_y_continuous(labels = label_number(prefix = "GBP ", big.mark = ",")) +
      labs(title = paste("Top", n, "products by revenue"), x = NULL, y = "Revenue") +
      mba_theme(11)
  })

  output$eda_basket <- renderPlot({
    d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
    bs <- d$retail %>% count(InvoiceNo, name = "BasketSize")
    mn <- round(mean(bs$BasketSize), 1)
    md <- median(bs$BasketSize)
    ggplot(bs, aes(BasketSize)) +
      geom_histogram(binwidth = 2, fill = "#6A51A3", colour = "white") +
      scale_x_continuous(limits = c(0, 100)) +
      labs(title = "Distribution of basket size",
           subtitle = sprintf("Mean = %s items | Median = %d items | X-axis capped at 100", mn, md),
           x = "Distinct products in basket", y = "Number of baskets") +
      mba_theme()
  })

  # =================================================================
  # RULES
  # =================================================================
  output$rules_stats <- renderPrint({
    d <- D()
    if (is.null(d) || is.null(d$sig)) {
      cat("Rules not loaded. Run the pipeline first.\n")
      return()
    }
    cat("SIGNIFICANT ASSOCIATION RULES\n")
    cat(rep("=", 45), "\n", sep = "")
    cat(sprintf("Total rules : %d\n", length(d$sig)))
    q <- quality(d$sig)
    cat(sprintf("Support     : %.4f – %.4f\n", min(q$support), max(q$support)))
    cat(sprintf("Confidence  : %.3f – %.3f\n", min(q$confidence), max(q$confidence)))
    cat(sprintf("Lift        : %.2f – %.2f\n", min(q$lift), max(q$lift)))
    cat(sprintf("Mean lift   : %.2f\n", mean(q$lift)))
    cat(rep("=", 45), "\n", sep = "")
  })

  output$tab_lift <- renderDT({
    d <- D(); if (is.null(d) || nrow(d$rules_lift) == 0) return(NULL)
    datatable(d$rules_lift, options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE, filter = "top",
              class = "cell-border stripe")
  })

  output$tab_conf <- renderDT({
    d <- D(); if (is.null(d) || nrow(d$rules_conf) == 0) return(NULL)
    datatable(d$rules_conf, options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE, filter = "top", class = "cell-border stripe")
  })

  output$tab_supp <- renderDT({
    d <- D(); if (is.null(d) || nrow(d$rules_supp) == 0) return(NULL)
    datatable(d$rules_supp, options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE, filter = "top", class = "cell-border stripe")
  })

  output$tab_all <- renderDT({
    d <- D(); if (is.null(d) || nrow(d$all_rules) == 0) return(NULL)
    datatable(d$all_rules, options = list(pageLength = 25, scrollX = TRUE, scrollY = "450px"),
              rownames = FALSE, filter = "top", class = "cell-border stripe")
  })

  # =================================================================
  # EXPLORER
  # =================================================================
  observeEvent(input$exp_apply, {
    d <- D()
    if (is.null(d) || is.null(d$sig) || length(d$sig) == 0) return()
    q <- quality(d$sig)
    min_lift <- input$exp_min_lift %||% 1
    min_conf <- input$exp_min_conf %||% 0
    min_supp <- input$exp_min_supp %||% 0
    max_r <- input$exp_max %||% 300
    search <- trimws(input$exp_search %||% "")

    keep <- q$lift >= min_lift & q$confidence >= min_conf & q$support >= min_supp
    filtered <- d$sig[keep]
    if (length(filtered) > max_r) {
      filtered <- head(sort(filtered, by = "lift", decreasing = TRUE), max_r)
    }

    df <- arules::DATAFRAME(filtered, setStart = "", setEnd = "", itemSep = " + ")
    names(df)[1:2] <- c("Antecedent", "Consequent")
    num <- vapply(df, is.numeric, logical(1))
    df[num] <- lapply(df[num], function(x) round(x, 4))

    if (nchar(search) > 0) {
      combined <- paste(df$Antecedent, df$Consequent)
      df <- df[grepl(search, combined, ignore.case = TRUE), ]
    }

    output$exp_table <- renderDT({
      if (nrow(df) == 0) {
        datatable(data.frame(Message = "No rules match the current filters."))
      } else {
        datatable(df, options = list(pageLength = 20, scrollX = TRUE),
                  rownames = FALSE, filter = "top", class = "cell-border stripe")
      }
    })
  }, ignoreNULL = FALSE)

  # =================================================================
  # SEGMENTS
  # =================================================================
  output$seg_uk_baskets <- renderValueBox({
    d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
    n_uk <- n_distinct(d$retail$InvoiceNo[d$retail$Country == "United Kingdom"])
    valueBox(format(n_uk, big.mark = ","), "UK Baskets",
             icon = icon("flag"), color = "blue")
  })
  output$seg_intl_baskets <- renderValueBox({
    d <- D(); if (is.null(d) || is.null(d$retail)) return(NULL)
    n_intl <- n_distinct(d$retail$InvoiceNo[d$retail$Country != "United Kingdom"])
    valueBox(format(n_intl, big.mark = ","), "International Baskets",
             icon = icon("globe"), color = "teal")
  })
  output$seg_uk_rules_count <- renderValueBox({
    d <- D(); if (is.null(d)) return(NULL)
    n <- if (nrow(d$uk_rules) > 0 && !"Note" %in% names(d$uk_rules)) nrow(d$uk_rules) else 0
    valueBox(n, "UK Top Rules", icon = icon("circle-nodes"), color = "purple")
  })
  output$seg_intl_rules_count <- renderValueBox({
    d <- D(); if (is.null(d)) return(NULL)
    n <- if (nrow(d$intl_rules) > 0 && !"Note" %in% names(d$intl_rules)) nrow(d$intl_rules) else 0
    valueBox(n, "Intl Top Rules", icon = icon("circle-nodes"), color = "red")
  })

  output$seg_table <- renderTable({
    d <- D(); if (is.null(d) || nrow(d$seg_comp) == 0 || "Note" %in% names(d$seg_comp)) return(data.frame())
    d$seg_comp
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$seg_bar <- renderPlot({
    d <- D(); if (is.null(d) || nrow(d$seg_comp) == 0 || "Note" %in% names(d$seg_comp)) return(NULL)
    long <- pivot_longer(d$seg_comp, cols = c(Rules, Baskets),
                         names_to = "Metric", values_to = "Value")
    ggplot(long, aes(x = Segment, y = Value, fill = Metric)) +
      geom_col(position = "dodge", width = 0.55, alpha = 0.9) +
      scale_fill_manual(values = c(Rules = mba_colors["primary"],
                                   Baskets = mba_colors["orange"])) +
      labs(title = "UK vs International: Baskets & Rules", x = NULL, y = "Count") +
      mba_theme() + theme(legend.position = "bottom",
                          legend.title = element_blank())
  })

  output$seg_uk_table <- renderDT({
    d <- D(); if (is.null(d) || nrow(d$uk_rules) == 0 || "Note" %in% names(d$uk_rules)) return(NULL)
    datatable(d$uk_rules, options = list(pageLength = 8, scrollX = TRUE),
              rownames = FALSE, class = "cell-border stripe")
  })

  output$seg_intl_table <- renderDT({
    d <- D(); if (is.null(d) || nrow(d$intl_rules) == 0 || "Note" %in% names(d$intl_rules)) return(NULL)
    datatable(d$intl_rules, options = list(pageLength = 8, scrollX = TRUE),
              rownames = FALSE, class = "cell-border stripe")
  })

  output$season_bar <- renderPlot({
    d <- D(); if (is.null(d) || nrow(d$season_comp) == 0 || "Note" %in% names(d$season_comp)) return(NULL)
    long <- pivot_longer(d$season_comp, cols = c(Baskets, Rules),
                         names_to = "Metric", values_to = "Value")
    ggplot(long, aes(x = Season, y = Value, fill = Metric)) +
      geom_col(position = "dodge", width = 0.55, alpha = 0.9) +
      scale_fill_manual(values = c(Baskets = mba_colors["primary"],
                                   Rules = mba_colors["danger"])) +
      labs(title = "Festive Quarter vs Rest of Year", x = NULL, y = "Count") +
      mba_theme() + theme(legend.position = "bottom",
                          legend.title = element_blank(),
                          axis.text.x = element_text(angle = 10, hjust = 1))
  })

  output$season_table <- renderDT({
    d <- D(); if (is.null(d) || nrow(d$festive) == 0 || "Note" %in% names(d$festive)) {
      datatable(data.frame(Note = "No festive-only rules found."))
      return()
    }
    datatable(d$festive, options = list(pageLength = 10, scrollX = TRUE),
              rownames = FALSE, class = "cell-border stripe")
  })

  # =================================================================
  # RECOMMENDER
  # =================================================================
  output$recom_metric_lift <- renderValueBox({
    valueBox("Lift", "Measures rule strength", icon = icon("arrow-up"), color = "blue")
  })
  output$recom_metric_conf <- renderValueBox({
    valueBox("Confidence", "P(RHS | LHS)", icon = icon("chart-line"), color = "teal")
  })
  output$recom_metric_supp <- renderValueBox({
    valueBox("Support", "P(LHS & RHS)", icon = icon("chart-bar"), color = "orange")
  })

  observeEvent(input$recom_go, {
    d <- D()
    if (is.null(d) || is.null(d$sig) || length(d$sig) == 0) {
      output$recom_table <- renderDT({
        datatable(data.frame(Message = "Rules not loaded. Run the pipeline first."))
      })
      return()
    }

    basket <- input$recom_items
    if (length(basket) == 0) {
      output$recom_table <- renderDT({
        datatable(data.frame(Message = "Select at least one item from your basket."))
      })
      return()
    }

    sig <- d$sig
    LHS_LIST <- as(lhs(sig), "list")
    RHS_ITEM <- unlist(as(rhs(sig), "list"))
    QUAL <- quality(sig)

    fires <- vapply(LHS_LIST, function(l) all(l %in% basket), logical(1))
    if (!any(fires)) {
      output$recom_table <- renderDT({
        datatable(data.frame(
          Message = "No rules fired for this combination of items.",
          Suggestion = "Try selecting different items or use one of the Sample buttons."
        ))
      })
      return()
    }

    rec <- data.frame(
      Recommendation = RHS_ITEM[fires],
      Confidence = round(QUAL$confidence[fires], 3),
      Lift = round(QUAL$lift[fires], 2),
      Support = round(QUAL$support[fires], 4),
      stringsAsFactors = FALSE
    )
    rec <- rec[!rec$Recommendation %in% basket, , drop = FALSE]
    if (nrow(rec) == 0) {
      output$recom_table <- renderDT({
        datatable(data.frame(Message = "All recommendations are already in your basket!"))
      })
      return()
    }
    rec <- rec[order(-rec$Lift), ]
    rec <- rec[!duplicated(rec$Recommendation), ]
    rec <- head(rec, 10)
    rec$Rank <- seq_len(nrow(rec))
    rec <- rec[, c("Rank", "Recommendation", "Lift", "Confidence", "Support")]

    output$recom_table <- renderDT({
      datatable(rec, options = list(pageLength = 10, scrollX = TRUE),
                rownames = FALSE, selection = "none",
                class = "cell-border stripe")
    })
  }, ignoreNULL = FALSE)

  observeEvent(input$recom_s1, {
    d <- D()
    if (is.null(d) || is.null(d$trans)) return()
    set.seed(7)
    ts <- d$trans
    sz <- size(ts)
    cands <- names(ts)[sz >= 3 & sz <= 8]
    if (length(cands) > 0) {
      basket <- as(ts[[sample(cands, 1)]], "list")[[1]]
      updateSelectizeInput(session, "recom_items", selected = basket[1:min(5, length(basket))])
    }
  })
  observeEvent(input$recom_s2, {
    d <- D()
    if (is.null(d) || is.null(d$trans)) return()
    set.seed(42)
    ts <- d$trans
    sz <- size(ts)
    cands <- names(ts)[sz >= 3 & sz <= 8]
    if (length(cands) > 0) {
      basket <- as(ts[[sample(cands, 1)]], "list")[[1]]
      updateSelectizeInput(session, "recom_items", selected = basket[1:min(5, length(basket))])
    }
  })
  observeEvent(input$recom_s3, {
    d <- D()
    if (is.null(d) || is.null(d$trans)) return()
    set.seed(99)
    ts <- d$trans
    sz <- size(ts)
    cands <- names(ts)[sz >= 4 & sz <= 10]
    if (length(cands) > 0) {
      basket <- as(ts[[sample(cands, 1)]], "list")[[1]]
      updateSelectizeInput(session, "recom_items", selected = basket[1:min(5, length(basket))])
    }
  })

  # =================================================================
  # CROSS-SELL
  # =================================================================
  output$cs_total_opp <- renderValueBox({
    d <- D()
    if (is.null(d) || nrow(d$cs_best) == 0 || "Note" %in% names(d$cs_best)) {
      valueBox("N/A", "Revenue Opportunity", icon = icon("pound-sign"), color = "orange")
      return()
    }
    total <- sum(d$cs_best$PotentialRevenue, na.rm = TRUE)
    valueBox(
      paste0("GBP ", format(round(total), big.mark = ",")),
      "Total Revenue Opportunity", icon = icon("pound-sign"), color = "red"
    )
  })

  output$cs_best_single <- renderValueBox({
    d <- D()
    if (is.null(d) || nrow(d$cs_best) == 0 || "Note" %in% names(d$cs_best)) {
      valueBox("N/A", "Best Single Opportunity", icon = icon("arrow-up"), color = "green")
      return()
    }
    top <- head(arrange(d$cs_best, desc(PotentialRevenue)), 1)
    valueBox(
      paste0("GBP ", format(round(top$PotentialRevenue), big.mark = ",")),
      "Best Single Opportunity", icon = icon("arrow-up"), color = "green"
    )
  })

  output$cs_avg_lift <- renderValueBox({
    d <- D()
    if (is.null(d) || nrow(d$cs_best) == 0 || "Note" %in% names(d$cs_best)) {
      valueBox("N/A", "Average Lift", icon = icon("arrows-up-down"), color = "purple")
      return()
    }
    avg <- round(mean(d$cs_best$Lift, na.rm = TRUE), 1)
    valueBox(paste0(avg, "x"), "Average Lift", icon = icon("arrows-up-down"), color = "purple")
  })

  output$cs_products <- renderValueBox({
    d <- D()
    if (is.null(d) || nrow(d$cs_best) == 0 || "Note" %in% names(d$cs_best)) {
      valueBox("N/A", "Products", icon = icon("tags"), color = "blue")
      return()
    }
    valueBox(nrow(d$cs_best), "Products with Opportunity",
             icon = icon("tags"), color = "blue")
  })

  output$cs_table <- renderDT({
    d <- D()
    if (is.null(d) || nrow(d$cs_best) == 0 || "Note" %in% names(d$cs_best)) {
      datatable(data.frame(Note = "Cross-sell data not found. Run the pipeline first."))
      return()
    }

    min_lift_val <- as.numeric(input$cs_minlift %||% 0)
    sort_col <- input$cs_sort %||% "PotentialRevenue"

    df <- d$cs_best
    if (min_lift_val > 0) {
      df <- df[df$Lift >= min_lift_val, ]
    }
    if (sort_col %in% names(df)) {
      df <- arrange(df, desc(.data[[sort_col]]))
    }

    # Shorten long columns for display
    if ("Rule" %in% names(df)) {
      df$Rule <- ifelse(nchar(df$Rule) > 75,
                        paste0(substr(df$Rule, 1, 72), "..."), df$Rule)
    }
    if ("Consequent" %in% names(df)) {
      df$Consequent <- ifelse(nchar(df$Consequent) > 40,
                              paste0(substr(df$Consequent, 1, 37), "..."), df$Consequent)
    }

    datatable(df, options = list(pageLength = 20, scrollX = TRUE),
              rownames = FALSE, filter = "top", class = "cell-border stripe")
  })
}

# =============================================================================
shinyApp(ui = ui, server = server)
