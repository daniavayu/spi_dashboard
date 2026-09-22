Sys.setenv(NOT_CRAN = "true")
library(shinytest2)

app <- AppDriver$new(
  app_dir = normalizePath(file.path("tests", "browser", "fixture-app")),
  name = "country-explorer-smoke",
  load_timeout = 120000,
  timeout = 120000,
  check_names = FALSE
)
on.exit(app$stop(), add = TRUE)

app$set_window_size(width = 1280, height = 900)
app$click(selector = "a[data-value='Country Explorer']")
app$wait_for_value(output = "country_explorer-explorer_selected_year")

selected_year <- app$get_html(
  selector = "#country_explorer-explorer_selected_year"
)
stopifnot(grepl("2024", selected_year, fixed = TRUE))

average_html <- app$get_html(selector = "#country_explorer-explorer_average")
stopifnot(!grepl("^-$", trimws(average_html)))

table_html <- app$get_html(selector = "#country_explorer-explorer_table")
stopifnot(grepl("Alpha", table_html, fixed = TRUE) ||
  grepl("AAA", table_html, fixed = TRUE))

profile_text <- app$get_html(selector = ".spi-explorer-page")
stopifnot(!grepl("full country profile", profile_text, fixed = TRUE))

app$set_window_size(width = 390, height = 844)
window_size <- app$get_window_size()
mobile_width <- as.integer(window_size[["width"]])
stopifnot(mobile_width >= 360L && mobile_width <= 390L)
stopifnot(nchar(app$get_html(selector = ".spi-explorer-controls")) > 0L)

cat("Country Explorer browser smoke passed at 1280px and 390px.\n")
