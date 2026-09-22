Sys.setenv(NOT_CRAN = "true")
library(shinytest2)

app <- AppDriver$new(
  app_dir = normalizePath(file.path("tests", "browser", "fixture-app")),
  name = "trends-progress-smoke",
  load_timeout = 120000,
  timeout = 120000,
  check_names = FALSE
)
on.exit(app$stop(), add = TRUE)

app$set_window_size(width = 1280, height = 900)
app$click(selector = "a[data-value='Trends & Progress']")
app$wait_for_value(output = "trends_progress-status")

status_html <- app$get_html(selector = "#trends_progress-status")
stopifnot(grepl("Showing", status_html, fixed = TRUE))

global_trend_html <- app$get_html(selector = "#trends_progress-global_trend")
stopifnot(nchar(global_trend_html) > 0L)

# DT tables render client-side via their own AJAX call after Shiny goes
# idle, so give the DataTables JS a moment to populate rows before reading.
app$wait_for_idle()
Sys.sleep(1)

changes_html <- app$get_html(selector = "#trends_progress-changes")
stopifnot(grepl("AAA", changes_html, fixed = TRUE) ||
  grepl("Alpha", changes_html, fixed = TRUE))

associations_html <- app$get_html(selector = "#trends_progress-associations")
stopifnot(nchar(associations_html) > 0L)

profile_text <- app$get_html(selector = ".spi-trends-page")
stopifnot(!grepl("full country profile", profile_text, fixed = TRUE))

app$set_window_size(width = 390, height = 844)
window_size <- app$get_window_size()
mobile_width <- as.integer(window_size[["width"]])
stopifnot(mobile_width >= 360L && mobile_width <= 390L)
stopifnot(nchar(app$get_html(selector = ".spi-explorer-controls")) > 0L)

cat("Trends & Progress browser smoke passed at 1280px and 390px.\n")
