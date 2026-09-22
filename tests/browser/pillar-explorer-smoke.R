Sys.setenv(NOT_CRAN = "true")
library(shinytest2)

app <- AppDriver$new(
  app_dir = normalizePath(file.path("tests", "browser", "fixture-app")),
  name = "pillar-explorer-smoke",
  load_timeout = 120000,
  timeout = 120000,
  check_names = FALSE
)
on.exit(app$stop(), add = TRUE)

app$set_window_size(width = 1280, height = 900)
app$click(selector = "a[data-value='Explore by Pillar']")
app$wait_for_value(output = "pillar_explorer-pillar_1_score")

pillar_1_html <- app$get_html(selector = "#pillar_explorer-pillar_1_score")
stopifnot(!grepl("^-$", trimws(pillar_1_html)))

total_html <- app$get_html(selector = "#pillar_explorer-total")
stopifnot(grepl("100", total_html, fixed = TRUE))

status_html <- app$get_html(selector = "#pillar_explorer-status")
stopifnot(!grepl("requires exactly five structural pillars", status_html, fixed = TRUE))

correlation_html <- app$get_html(selector = "#pillar_explorer-correlation_plot")
stopifnot(nchar(correlation_html) > 0L)
scatter_html <- app$get_html(selector = "#pillar_explorer-scatter_plot")
stopifnot(nchar(scatter_html) > 0L)

profile_text <- app$get_html(selector = ".spi-pillar-page")
stopifnot(!grepl("full country profile", profile_text, fixed = TRUE))

app$set_window_size(width = 390, height = 844)
window_size <- app$get_window_size()
mobile_width <- as.integer(window_size[["width"]])
stopifnot(mobile_width >= 360L && mobile_width <= 390L)
stopifnot(nchar(app$get_html(selector = ".spi-pillar-filters")) > 0L)

cat("Explore by Pillar browser smoke passed at 1280px and 390px.\n")
