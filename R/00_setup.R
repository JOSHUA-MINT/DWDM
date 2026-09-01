# =============================================================================
# 00_setup.R -- Package installation and global project configuration
# Project : Market Basket Analysis of Online Retail Transactions
# Dataset : UCI ML Repository #352 -- Online Retail
# =============================================================================

options(repos = c(CRAN = "https://cloud.r-project.org"))

required_packages <- c(
  "readxl",         # read the .xlsx source file
  "dplyr",          # data wrangling
  "tidyr",          # reshaping
  "lubridate",      # date handling
  "ggplot2",        # plots
  "scales",         # axis formatting
  "RColorBrewer",   # palettes
  "arules",         # Apriori + association rules
  "shiny",          # dashboard framework
  "shinydashboard", # dashboard theme/layout
  "shinyjs",        # JavaScript operations in Shiny
  "DT",             # interactive tables
  "plotly"          # interactive plots
)

missing <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing) > 0) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing)
}

invisible(lapply(required_packages, library, character.only = TRUE))
if (requireNamespace("arulesViz", quietly = TRUE)) library(arulesViz)

# ---- Project paths ----------------------------------------------------------
# Works whether you run from the project root or from inside R/
PROJ_ROOT <- getwd()
if (basename(PROJ_ROOT) == "R") PROJ_ROOT <- dirname(PROJ_ROOT)

DIR_RAW    <- file.path(PROJ_ROOT, "data", "raw")
DIR_PROC   <- file.path(PROJ_ROOT, "data", "processed")
DIR_FIG    <- file.path(PROJ_ROOT, "output", "figures")
DIR_TAB    <- file.path(PROJ_ROOT, "output", "tables")

for (d in c(DIR_RAW, DIR_PROC, DIR_FIG, DIR_TAB)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

# ---- Analysis parameters (single place to tune the whole study) -------------
PARAMS <- list(
  support     = 0.01,   # 1% of baskets -- ~ 200 baskets at ~19.8k transactions
  confidence  = 0.30,   # 30% conditional probability
  minlen      = 2,      # rules must have >= 1 item on each side
  maxlen      = 4,      # keep itemsets interpretable
  min_lift    = 1.0,    # only rules better than chance
  top_n       = 20      # how many rules/items to report in tables & plots
)

# ---- Plot theme -------------------------------------------------------------
theme_mba <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title    = element_text(face = "bold", size = base_size + 3),
      plot.subtitle = element_text(colour = "grey35"),
      panel.grid.minor = element_blank(),
      axis.title    = element_text(colour = "grey25")
    )
}

save_fig <- function(plot, name, width = 9, height = 6, dpi = 150) {
  path <- file.path(DIR_FIG, paste0(name, ".png"))
  ggsave(path, plot, width = width, height = height, dpi = dpi, bg = "white")
  message("  saved figure -> ", path)
}

save_tab <- function(df, name) {
  path <- file.path(DIR_TAB, paste0(name, ".csv"))
  write.csv(df, path, row.names = FALSE)
  message("  saved table  -> ", path)
}

set.seed(42)
message("Setup complete. Project root: ", PROJ_ROOT)
