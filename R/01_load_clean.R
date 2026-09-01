# =============================================================================
# 01_load_clean.R -- Load the raw UCI Online Retail file and clean it
# Output: data/processed/retail_clean.rds  +  data/processed/retail_clean.csv
# =============================================================================

source(file.path(getwd(), "R", "00_setup.R"))

xlsx_path <- file.path(DIR_RAW, "Online Retail.xlsx")
zip_path  <- file.path(DIR_RAW, "online_retail.zip")

# ---- 1. Download on first run ----------------------------------------------
if (!file.exists(xlsx_path)) {
  if (!file.exists(zip_path)) {
    message("Downloading dataset from the UCI ML Repository ...")
    download.file("https://archive.ics.uci.edu/static/public/352/online+retail.zip",
                  destfile = zip_path, mode = "wb")
  }
  unzip(zip_path, exdir = DIR_RAW)
}

message("Reading Excel file (this takes ~30-60 seconds) ...")
raw <- readxl::read_excel(xlsx_path, sheet = 1,
                          col_types = c("text", "text", "text", "numeric",
                                        "date", "numeric", "text", "text"))
names(raw) <- c("InvoiceNo", "StockCode", "Description", "Quantity",
                "InvoiceDate", "UnitPrice", "CustomerID", "Country")

message(sprintf("Raw data: %s rows x %s columns", format(nrow(raw), big.mark = ","), ncol(raw)))

# ---- 2. Data quality audit --------------------------------------------------
audit <- data.frame(
  Check = c("Total rows",
            "Missing Description",
            "Missing CustomerID",
            "Cancelled invoices (InvoiceNo starts with 'C')",
            "Quantity <= 0",
            "UnitPrice <= 0",
            "Duplicate rows",
            "Distinct invoices",
            "Distinct stock codes",
            "Distinct countries"),
  Value = c(nrow(raw),
            sum(is.na(raw$Description)),
            sum(is.na(raw$CustomerID)),
            sum(grepl("^C", raw$InvoiceNo)),
            sum(raw$Quantity <= 0, na.rm = TRUE),
            sum(raw$UnitPrice <= 0, na.rm = TRUE),
            sum(duplicated(raw)),
            dplyr::n_distinct(raw$InvoiceNo),
            dplyr::n_distinct(raw$StockCode),
            dplyr::n_distinct(raw$Country))
)
print(audit)
save_tab(audit, "01_data_quality_audit")

# ---- 3. Cleaning ------------------------------------------------------------
# Non-product stock codes used by the retailer for postage, fees, adjustments.
admin_codes <- c("POST", "DOT", "D", "M", "S", "C2", "CRUK", "BANK CHARGES",
                 "AMAZONFEE", "B", "PADS", "gift_0001_10", "gift_0001_20",
                 "gift_0001_30", "gift_0001_40", "gift_0001_50")

junk_desc <- paste0("(?i)^([?]+|check|damage|damaged|found|lost|missing|",
                    "adjust|adjustment|amazon|sold as set|smashed|wet|",
                    "thrown away|mailout|test|dotcom|manual|samples|",
                    "wrongly|incorrect|broken|crushed|mouldy|rusty|water damage)")

retail <- raw |>
  dplyr::filter(!is.na(Description)) |>
  dplyr::filter(!grepl("^C", InvoiceNo)) |>               # drop cancellations
  dplyr::filter(Quantity > 0, UnitPrice > 0) |>           # drop returns / freebies
  dplyr::filter(!toupper(trimws(StockCode)) %in% toupper(admin_codes)) |>
  dplyr::mutate(
    Description = trimws(toupper(Description)),
    StockCode   = trimws(toupper(StockCode))
  ) |>
  dplyr::filter(!grepl(junk_desc, Description, perl = TRUE)) |>
  dplyr::filter(nchar(Description) > 2) |>
  dplyr::distinct(InvoiceNo, StockCode, .keep_all = TRUE) |>  # 1 row per item per basket
  dplyr::mutate(
    Revenue   = Quantity * UnitPrice,
    Date      = as.Date(InvoiceDate),
    Month     = lubridate::floor_date(Date, "month"),
    Hour      = lubridate::hour(InvoiceDate),
    Weekday   = lubridate::wday(Date, label = TRUE, abbr = TRUE, week_start = 1)
  )

# ---- 4. A description can drift across rows; pin one label per StockCode ----
canonical <- retail |>
  dplyr::count(StockCode, Description, name = "n") |>
  dplyr::group_by(StockCode) |>
  dplyr::slice_max(n, n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::select(StockCode, Item = Description)

retail <- retail |>
  dplyr::left_join(canonical, by = "StockCode") |>
  dplyr::filter(!is.na(Item))

# ---- 5. Drop single-item baskets: they carry no co-occurrence information ---
basket_sizes <- retail |> dplyr::count(InvoiceNo, name = "BasketSize")
retail <- retail |>
  dplyr::inner_join(dplyr::filter(basket_sizes, BasketSize >= 2), by = "InvoiceNo")

# ---- 6. Report ---------------------------------------------------------------
summary_tbl <- data.frame(
  Metric = c("Rows after cleaning", "Rows removed", "% rows retained",
             "Transactions (baskets)", "Unique products", "Countries",
             "Date range", "Mean basket size", "Median basket size",
             "Total revenue (GBP)"),
  Value  = c(format(nrow(retail), big.mark = ","),
             format(nrow(raw) - nrow(retail), big.mark = ","),
             sprintf("%.1f%%", 100 * nrow(retail) / nrow(raw)),
             format(dplyr::n_distinct(retail$InvoiceNo), big.mark = ","),
             format(dplyr::n_distinct(retail$Item), big.mark = ","),
             dplyr::n_distinct(retail$Country),
             paste(min(retail$Date), "to", max(retail$Date)),
             sprintf("%.2f", nrow(retail) / dplyr::n_distinct(retail$InvoiceNo)),
             median(basket_sizes$BasketSize[basket_sizes$BasketSize >= 2]),
             format(round(sum(retail$Revenue)), big.mark = ","))
)
print(summary_tbl)
save_tab(summary_tbl, "01_cleaning_summary")

saveRDS(retail, file.path(DIR_PROC, "retail_clean.rds"))
write.csv(retail[, c("InvoiceNo","StockCode","Item","Quantity","InvoiceDate",
                     "UnitPrice","CustomerID","Country","Revenue")],
          file.path(DIR_PROC, "retail_clean.csv"), row.names = FALSE)

message("Cleaning complete -> data/processed/retail_clean.rds")
