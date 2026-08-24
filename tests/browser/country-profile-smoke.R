Sys.setenv(NOT_CRAN = "true")
library(shinytest2)

app <- AppDriver$new(
  app_dir = normalizePath(file.path("tests", "browser", "fixture-app")),
  name = "country-profile-smoke",
  load_timeout = 120000,
  check_names = FALSE
)
on.exit(app$stop(), add = TRUE)

app$set_window_size(width = 1280, height = 900)
app$click(selector = "a[data-value='Country Profile']")
app$wait_for_value(output = "country_profile-profile_selected_year")
selected_country <- app$get_html(
  selector = "#country_profile-profile_selected_country"
)
selected_score <- app$get_html(selector = "#country_profile-profile_score")
stopifnot(grepl("AAA", selected_country, fixed = TRUE))
stopifnot(grepl("70.0", selected_score, fixed = TRUE))

explorer_text <- app$get_html(selector = ".spi-explorer-page")
stopifnot(!grepl("full country profile", explorer_text, fixed = TRUE))

app$set_window_size(width = 390, height = 844)
window_size <- app$get_window_size()
mobile_width <- as.integer(window_size[["width"]])
stopifnot(mobile_width >= 360L && mobile_width <= 390L)
stopifnot(nchar(app$get_html(selector = ".spi-profile-controls")) > 0L)

cat("Country Profile browser smoke passed at 1280px and 390px.\n")
