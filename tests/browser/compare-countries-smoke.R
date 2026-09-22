Sys.setenv(NOT_CRAN = "true")
library(shinytest2)

app <- AppDriver$new(
  app_dir = normalizePath(file.path("tests", "browser", "fixture-app")),
  name = "compare-countries-smoke",
  load_timeout = 120000,
  timeout = 120000,
  check_names = FALSE
)
on.exit(app$stop(), add = TRUE)

app$set_window_size(width = 1280, height = 900)
app$click(selector = "a[data-value='Compare Countries']")
app$wait_for_idle()

app$set_inputs(`country_compare-compare_country` = c("AAA", "BBB"))
app$wait_for_value(output = "country_compare-compare_selected")

selected_html <- app$get_html(selector = "#country_compare-compare_selected")
stopifnot(grepl("AAA", selected_html, fixed = TRUE))
stopifnot(grepl("BBB", selected_html, fixed = TRUE))

status_html <- app$get_html(selector = "#country_compare-compare_status")
stopifnot(!grepl("Select two or three countries", status_html, fixed = TRUE))

pillars_html <- app$get_html(selector = "#country_compare-compare_pillars")
stopifnot(nchar(pillars_html) > 0L)
trend_html <- app$get_html(selector = "#country_compare-compare_plot")
stopifnot(nchar(trend_html) > 0L)

profile_text <- app$get_html(selector = ".spi-compare-header")
stopifnot(!grepl("full country profile", profile_text, fixed = TRUE))

app$set_window_size(width = 390, height = 844)
window_size <- app$get_window_size()
mobile_width <- as.integer(window_size[["width"]])
stopifnot(mobile_width >= 360L && mobile_width <= 390L)
stopifnot(nchar(app$get_html(selector = ".spi-compare-controls")) > 0L)

cat("Compare Countries browser smoke passed at 1280px and 390px.\n")
