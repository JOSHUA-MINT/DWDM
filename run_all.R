# =============================================================================
# run_all.R -- Execute the complete Market Basket Analysis pipeline
#
# In RStudio:  open DWDM.Rproj (or setwd() to this folder), then
#              source("run_all.R")
# In a shell:  Rscript run_all.R
# =============================================================================

.start <- Sys.time()

stages <- c(
  "R/01_load_clean.R",
  "R/02_eda.R",
  "R/03_apriori.R",
  "R/04_visualize_rules.R",
  "R/05_segments_and_recommendations.R"
)

# The stage scripts run in the global environment and use short variable names
# of their own (05 loops over `s`), so the loop state here is namespaced with a
# leading dot to keep it from being clobbered mid-run.
for (.stage in stages) {
  message("\n", strrep("=", 78))
  message("RUNNING: ", .stage)
  message(strrep("=", 78))
  .t0 <- Sys.time()
  source(.stage, echo = FALSE)
  message(sprintf(">>> %s finished in %.1f s", .stage,
                  as.numeric(difftime(Sys.time(), .t0, units = "secs"))))
}

message("\n", strrep("=", 78))
message(sprintf("PIPELINE COMPLETE in %.1f minutes",
                as.numeric(difftime(Sys.time(), .start, units = "mins"))))
message("Figures -> output/figures/   Tables -> output/tables/")
message(strrep("=", 78))
