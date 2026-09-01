# =============================================================================
# 02_eda.R -- Exploratory analysis of the cleaned transaction data
# Output: output/figures/*.png, output/tables/*.csv
# =============================================================================

source(file.path(getwd(), "R", "00_setup.R"))

retail <- readRDS(file.path(DIR_PROC, "retail_clean.rds"))

# ---- 1. Top products by frequency (how often they appear in a basket) -------
top_items <- retail |>
  dplyr::count(Item, name = "Baskets") |>
  dplyr::mutate(Support = Baskets / dplyr::n_distinct(retail$InvoiceNo)) |>
  dplyr::arrange(dplyr::desc(Baskets))

save_tab(head(top_items, 50), "02_top50_items_by_frequency")

p1 <- head(top_items, PARAMS$top_n) |>
  ggplot(aes(x = reorder(Item, Baskets), y = Baskets)) +
  geom_col(fill = "#2C7FB8") +
  geom_text(aes(label = format(Baskets, big.mark = ",")), hjust = -0.12, size = 3) +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, .15)), labels = comma) +
  labs(title = paste("Top", PARAMS$top_n, "products by number of baskets"),
       subtitle = "UCI Online Retail, cleaned transactions",
       x = NULL, y = "Baskets containing the product") +
  theme_mba()
save_fig(p1, "01_top_items_frequency")

# ---- 2. Top products by revenue --------------------------------------------
top_revenue <- retail |>
  dplyr::group_by(Item) |>
  dplyr::summarise(Revenue = sum(Revenue), Units = sum(Quantity), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(Revenue))
save_tab(head(top_revenue, 50), "02_top50_items_by_revenue")

p2 <- head(top_revenue, PARAMS$top_n) |>
  ggplot(aes(x = reorder(Item, Revenue), y = Revenue)) +
  geom_col(fill = "#238B45") +
  coord_flip() +
  scale_y_continuous(labels = label_number(prefix = "GBP ", big.mark = ",")) +
  labs(title = paste("Top", PARAMS$top_n, "products by revenue"),
       x = NULL, y = "Revenue") +
  theme_mba()
save_fig(p2, "02_top_items_revenue")

# ---- 3. Basket size distribution -------------------------------------------
basket_sizes <- retail |> dplyr::count(InvoiceNo, name = "BasketSize")

p3 <- ggplot(basket_sizes, aes(x = BasketSize)) +
  geom_histogram(binwidth = 2, fill = "#6A51A3", colour = "white") +
  scale_x_continuous(limits = c(0, 100)) +
  labs(title = "Distribution of basket size",
       subtitle = sprintf("Mean = %.1f items, median = %d items (x-axis capped at 100)",
                          mean(basket_sizes$BasketSize),
                          median(basket_sizes$BasketSize)),
       x = "Distinct products in basket", y = "Number of baskets") +
  theme_mba()
save_fig(p3, "03_basket_size_distribution")

save_tab(
  data.frame(Statistic = c("Min","Q1","Median","Mean","Q3","P95","Max"),
             BasketSize = round(c(min(basket_sizes$BasketSize),
                                  quantile(basket_sizes$BasketSize, .25),
                                  median(basket_sizes$BasketSize),
                                  mean(basket_sizes$BasketSize),
                                  quantile(basket_sizes$BasketSize, .75),
                                  quantile(basket_sizes$BasketSize, .95),
                                  max(basket_sizes$BasketSize)), 2)),
  "02_basket_size_stats")

# ---- 4. Sales over time -----------------------------------------------------
monthly <- retail |>
  dplyr::group_by(Month) |>
  dplyr::summarise(Revenue = sum(Revenue),
                   Transactions = dplyr::n_distinct(InvoiceNo), .groups = "drop")
save_tab(monthly, "02_monthly_sales")

p4 <- ggplot(monthly, aes(Month, Revenue)) +
  geom_col(fill = "#D94801") +
  scale_y_continuous(labels = label_number(prefix = "GBP ", scale = 1e-3, suffix = "k")) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "1 month") +
  labs(title = "Monthly revenue",
       subtitle = "Note the pre-Christmas peak in Sep-Nov 2011",
       x = NULL, y = "Revenue") +
  theme_mba() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_fig(p4, "04_monthly_revenue")

# ---- 5. Trading rhythm: weekday x hour -------------------------------------
heat <- retail |>
  dplyr::distinct(InvoiceNo, Weekday, Hour) |>
  dplyr::count(Weekday, Hour, name = "Transactions")

p5 <- ggplot(heat, aes(x = Hour, y = Weekday, fill = Transactions)) +
  geom_tile(colour = "white") +
  scale_fill_distiller(palette = "YlGnBu", direction = 1, labels = comma) +
  labs(title = "When do orders come in?",
       subtitle = "Transaction counts by weekday and hour of day",
       x = "Hour of day", y = NULL) +
  theme_mba()
save_fig(p5, "05_weekday_hour_heatmap", width = 9, height = 4.5)

# ---- 6. Geography -----------------------------------------------------------
by_country <- retail |>
  dplyr::group_by(Country) |>
  dplyr::summarise(Transactions = dplyr::n_distinct(InvoiceNo),
                   Revenue = sum(Revenue), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(Revenue)) |>
  dplyr::mutate(RevenueShare = Revenue / sum(Revenue))
save_tab(by_country, "02_by_country")

p6 <- by_country |>
  dplyr::slice_head(n = 10) |>
  ggplot(aes(reorder(Country, Revenue), Revenue)) +
  geom_col(fill = "#7A0177") +
  coord_flip() +
  scale_y_continuous(labels = label_number(prefix = "GBP ", scale = 1e-3, suffix = "k")) +
  labs(title = "Top 10 countries by revenue",
       subtitle = sprintf("The UK alone accounts for %.1f%% of revenue",
                          100 * by_country$RevenueShare[by_country$Country == "United Kingdom"]),
       x = NULL, y = "Revenue") +
  theme_mba()
save_fig(p6, "06_top_countries")

message("EDA complete.")
