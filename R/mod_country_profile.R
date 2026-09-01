country_profile_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "spi-profile-controls",
      shiny::selectInput(ns("profile_country"), "Country", choices = NULL,
        multiple = TRUE),
      shiny::selectInput(ns("profile_year"), "Data year", choices = NULL)
    ),
    shiny::div(
      class = "spi-profile-header",
      shiny::div(class = "spi-profile-country-mark",
        shiny::textOutput(ns("profile_country_code"), inline = TRUE)
      ),
      shiny::div(class = "spi-profile-country-meta",
        shiny::h1(shiny::textOutput(ns("profile_country_name"))),
        shiny::div(class = "spi-profile-badges",
          shiny::span(class = "spi-profile-badge",
            shiny::textOutput(ns("profile_region"), inline = TRUE)
          ),
          shiny::span(class = "spi-profile-badge spi-profile-badge-blue",
            shiny::textOutput(ns("profile_income"), inline = TRUE)
          )
        )
      ),
      shiny::div(class = "spi-profile-score",
        shiny::span("Overall SPI score"),
        shiny::strong(shiny::textOutput(ns("profile_score"), inline = TRUE))
      )
    ),
    shiny::div(class = "spi-profile-status",
      shiny::textOutput(ns("profile_overall_status"), inline = TRUE)
    ),
    shiny::div(class = "spi-profile-section spi-profile-context",
      shiny::h2("Country context"),
      shiny::p("Official SPI benchmarks for the selected year."),
      DT::DTOutput(ns("profile_context"))
    ),
    shiny::div(class = "spi-profile-hero-grid",
      shiny::div(class = "spi-profile-section spi-profile-radar",
        shiny::h2("Pillar Performance"),
        shiny::textOutput(ns("profile_radar_status")),
        shiny::plotOutput(ns("profile_radar"), height = "350px")
      ),
      shiny::div(class = "spi-profile-section spi-profile-trend",
        shiny::div(class = "spi-profile-panel-heading",
          shiny::h2("Score Over Time"),
          shiny::span("Selected year: ", shiny::textOutput(
            ns("profile_selected_year"), inline = TRUE
          ))
        ),
        shiny::textOutput(ns("profile_trend_status")),
        shiny::plotOutput(ns("profile_trend_plot"), height = "350px"),
        shiny::div(class = "spi-profile-trend-note",
          shiny::textOutput(ns("profile_trend"))
        )
      )
    ),
    shiny::uiOutput(ns("profile_dimension_extremes")),
    shiny::div(class = "spi-profile-section",
      shiny::h2("Pillars"),
      shiny::textOutput(ns("profile_pillars_status")),
      DT::DTOutput(ns("profile_pillars"))
    ),
    shiny::div(class = "spi-profile-section",
      shiny::h2("Dimensions"),
      shiny::textOutput(ns("profile_dimensions_status")),
      DT::DTOutput(ns("profile_dimensions"))
    ),
    shiny::div(class = "spi-profile-section",
      shiny::h2("Indicators"),
      shiny::textOutput(ns("profile_indicators_status")),
      DT::DTOutput(ns("profile_indicators"))
    )
  )
}

country_profile_section_message <- function(section) {
  if (is.null(section)) {
    return("unavailable")
  }
  if (!is.null(section$message) && nzchar(section$message)) {
    return(section$message)
  }
  if (!is.null(section$status)) {
    status <- as.character(section$status)
    if (identical(status, "ok")) return("")
    return(status)
  }
  "unavailable"
}

country_profile_server <- function(
  id,
  profile_loader = function() list(),
  active = function() TRUE
) {
  shiny::moduleServer(id, function(input, output, session) {
    profile <- shiny::reactiveVal(NULL)
    shiny::observe({
      if (isTRUE(active()) && is.null(profile())) {
        profile(tryCatch(
          profile_loader(),
          error = function(error) list(
            countries = data.frame(),
            overall = list(data = data.frame(), status = "error",
              message = conditionMessage(error)),
            pillars = list(data = data.frame(), status = "unavailable"),
            dimensions = list(data = data.frame(), status = "unavailable"),
            indicators = list(data = data.frame(), status = "unavailable"),
            benchmarks = list(data = data.frame(), status = "unavailable")
          )
        ))
      }
    })

    profile_value <- shiny::reactive({
      value <- profile()
      if (is.null(value)) {
        return(list(
          countries = data.frame(),
          overall = list(data = data.frame(), status = "pending"),
          pillars = list(data = data.frame(), status = "pending"),
          dimensions = list(data = data.frame(), status = "pending"),
          indicators = list(data = data.frame(), status = "pending"),
          benchmarks = list(data = data.frame(), status = "pending"),
          radar_index = data.frame(), radar_metadata = data.frame()
        ))
      }
      value
    })

    countries <- shiny::reactive({
      choices <- profile_value()$countries
      if (!is.data.frame(choices) || nrow(choices) == 0L) {
        overall <- profile_value()$overall$data
        if (!is.data.frame(overall) || nrow(overall) == 0L) {
          return(character())
        }
        choices <- unique(overall[c("country_code", "country_name")])
      }
      choices <- choices[!duplicated(choices$country_code), , drop = FALSE]
      choices <- choices[order(tolower(as.character(choices$country_name))), ,
        drop = FALSE
      ]
      stats::setNames(as.character(choices$country_code),
        as.character(choices$country_name))
    })

    shiny::observeEvent(c(profile(), countries()), {
      choices <- countries()
      shiny::updateSelectInput(
        session, "profile_country", choices = choices,
        selected = if (length(choices) > 0L) choices[[1L]] else character()
      )
    }, ignoreInit = FALSE)

    selected_country <- shiny::reactive({
      choices <- countries()
      requested <- input$profile_country
      if (length(choices) == 0L) return(NA_character_)
      requested <- as.character(requested)
      requested <- requested[requested %in% unname(choices)]
      if (length(requested) > 0L) {
        return(requested[[1L]])
      }
      unname(choices[[1L]])
    })

    selected_countries <- shiny::reactive({
      choices <- countries()
      requested <- as.character(input$profile_country)
      requested[requested %in% unname(choices)]
    })

    selected_overall <- shiny::reactive({
      overall <- profile_value()$overall$data
      if (!is.data.frame(overall)) return(data.frame())
      overall[as.character(overall$country_code) == selected_country(), ,
        drop = FALSE
      ]
    })

    available_years <- shiny::reactive({
      data <- selected_overall()
      if (!is.data.frame(data) || nrow(data) == 0L) return(integer())
      values <- suppressWarnings(as.numeric(data$score))
      sort(unique(as.integer(data$year)[!is.na(data$year) & !is.na(values)]))
    })

    shiny::observeEvent(c(profile(), selected_country()), {
      years <- available_years()
      shiny::updateSelectInput(
        session, "profile_year", choices = years,
        selected = if (length(years) > 0L) max(years) else character()
      )
    }, ignoreInit = FALSE)

    selected_year <- shiny::reactive({
      years <- available_years()
      requested <- suppressWarnings(as.integer(input$profile_year))
      if (length(years) == 0L) return(NA_integer_)
      if (length(requested) == 1L && !is.na(requested) && requested %in% years) {
        return(requested)
      }
      max(years)
    })

    selected_row <- shiny::reactive({
      data <- selected_overall()
      data[data$year == selected_year(), , drop = FALSE]
    })

    section <- function(name) {
      value <- profile_value()[[name]]
      if (is.null(value)) list(data = data.frame(), status = "unavailable") else value
    }
    radar_value <- shiny::reactive({
      index <- profile_value()$radar_index
      metadata <- profile_value()$radar_metadata
      radar <- spi_profile_radar_data(
        index, metadata, selected_country(), selected_year()
      )
      has_official <- requireNamespace("spiR", quietly = TRUE) &&
        exists("spi_plot_radar", asNamespace("spiR"), inherits = FALSE)
      status <- if (nrow(radar) > 0L || has_official) "ok" else "unavailable"
      list(data = radar, status = status, source = "spiR")
    })
    dimension_extremes <- shiny::reactive({
      dimensions <- section("dimensions")$data
      if (is.data.frame(dimensions) && "country_code" %in% names(dimensions)) {
        dimensions <- dimensions[
          as.character(dimensions$country_code) == selected_country(), ,
          drop = FALSE
        ]
      }
      spi_profile_prepare_dimension_extremes(
        dimensions, selected_year(), coverage_threshold = 0.5, limit = 3L
      )
    })

    profile_section_data <- function(section_name) {
      value <- section(section_name)$data
      if (!is.data.frame(value) || nrow(value) == 0L) {
        return(data.frame())
      }
      if ("country_code" %in% names(value)) {
        value <- value[
          as.character(value$country_code) == selected_country(), ,
          drop = FALSE
        ]
      }
      if ("year" %in% names(value)) {
        value <- value[value$year == selected_year(), , drop = FALSE]
      }
      rownames(value) <- NULL
      value
    }

    output$profile_selected_country <- shiny::renderText(selected_country())
    output$profile_country_name <- shiny::renderText({
      choices <- countries()
      name <- names(choices)[match(selected_country(), unname(choices))]
      if (is.na(name) || is.null(name)) "-" else name
    })
    output$profile_country_code <- shiny::renderText(selected_country())
    output$profile_region <- shiny::renderText({
      metadata <- profile_value()$radar_metadata
      row <- metadata[as.character(metadata$country_code) == selected_country() &
        metadata$year == selected_year(), , drop = FALSE]
      if (nrow(row) == 0L || is.na(row$region[[1L]])) "Region unavailable" else row$region[[1L]]
    })
    output$profile_income <- shiny::renderText({
      metadata <- profile_value()$radar_metadata
      row <- metadata[as.character(metadata$country_code) == selected_country() &
        metadata$year == selected_year(), , drop = FALSE]
      if (nrow(row) == 0L || is.na(row$income_group[[1L]])) "Income unavailable" else row$income_group[[1L]]
    })
    output$profile_selected_year <- shiny::renderText(as.character(selected_year()))
    output$profile_score <- shiny::renderText({
      row <- selected_row()
      if (nrow(row) == 0L) return("-")
      spi_profile_format_value(row$score[[1L]])
    })
    output$profile_context <- DT::renderDT({
      data <- spi_profile_prepare_context(
        profile_value()$overall$data,
        profile_value()$radar_metadata,
        profile_value()$benchmarks$data,
        selected_country(), selected_year()
      )
      if (nrow(data) == 0L) {
        return(DT::datatable(data.frame(), rownames = FALSE))
      }
      table <- data.frame(
        Comparison = data$comparison,
        Benchmark = data$benchmark,
        Country = data$country_score,
        Benchmark.score = data$benchmark_score,
        Difference = data$difference,
        stringsAsFactors = FALSE
      )
      DT::datatable(
        table, rownames = FALSE,
        colnames = c("Comparison", "Benchmark", "Country score", "Benchmark score", "Difference"),
        class = "compact stripe spi-profile-score-table",
        options = list(dom = "t", ordering = FALSE)
      ) |>
        DT::formatRound(columns = c("Country", "Benchmark.score", "Difference"), digits = 1) |>
        DT::formatStyle(
          columns = "Difference",
          color = DT::styleInterval(c(0), c("#a12828", "#176b42")),
          fontWeight = "700"
        )
    })
    output$profile_overall_status <- shiny::renderText(
      country_profile_section_message(section("overall"))
    )
    output$profile_trend <- shiny::renderText({
      trend <- profile_value()$trend
      if (is.null(trend) || !is.data.frame(trend$data) || nrow(trend$data) == 0L) {
        return("-")
      }
      latest <- tail(trend$data, 1L)
      spi_profile_format_value(latest$change_previous)
    })
    output$profile_trend_status <- shiny::renderText(
      country_profile_section_message(section("trend"))
    )
    output$profile_trend_plot <- shiny::renderPlot({
      data <- profile_value()$overall$data
      data <- data[as.character(data$country_code) == selected_country(), , drop = FALSE]
      spi_profile_official_trend(
        selected_country(), data, selected_year()
      )
    })
    output$profile_radar_status <- shiny::renderText(
      country_profile_section_message(radar_value())
    )
    output$profile_radar <- shiny::renderPlot({
      radar <- radar_value()
      spi_profile_official_radar(
        selected_country(), selected_year(), radar$data
      )
    })
    output$profile_dimension_extremes <- shiny::renderUI({
      extremes <- dimension_extremes()
      render_extreme_list <- function(data, empty_message) {
        if (!is.data.frame(data) || nrow(data) == 0L) {
          return(shiny::div(class = "spi-profile-extremes-status",
            empty_message
          ))
        }
        shiny::div(
          class = "spi-profile-extremes-list",
          lapply(seq_len(nrow(data)), function(row_number) {
            label <- data$dimension_label[[row_number]]
            if (is.null(label) || is.na(label) || !nzchar(label)) {
              label <- data$dimension_id[[row_number]]
            }
            shiny::div(
              class = "spi-profile-extreme-row",
              shiny::span(label),
              shiny::strong(spi_profile_format_value(
                data$score[[row_number]]
              ))
            )
          })
        )
      }
      shiny::div(
        class = "spi-profile-extremes-grid",
        shiny::div(
          class = "spi-profile-extremes spi-profile-strongest",
          shiny::h2("Strongest Dimensions"),
          render_extreme_list(
            extremes$highest, "No sufficiently covered dimensions available."
          )
        ),
        shiny::div(
          class = "spi-profile-extremes spi-profile-improvement",
          shiny::h2("Areas for Improvement"),
          render_extreme_list(
            extremes$lowest, "No sufficiently covered dimensions available."
          )
        )
      )
    })

    profile_score_table <- function(section_name) {
      value <- profile_section_data(section_name)
      if (!is.data.frame(value) || nrow(value) == 0L) {
        return(DT::datatable(data.frame(), rownames = FALSE))
      }
      if (identical(section_name, "pillars")) {
        table <- data.frame(
          Name = value$metric_label,
          Score = suppressWarnings(as.numeric(value$score)),
          stringsAsFactors = FALSE
        )
      } else if (identical(section_name, "dimensions")) {
        table <- data.frame(
          Name = value$dimension_label,
          Score = suppressWarnings(as.numeric(value$score)),
          stringsAsFactors = FALSE
        )
      } else if (identical(section_name, "indicators")) {
        table <- data.frame(
          Name = value$indicator_label,
          Score = suppressWarnings(as.numeric(value$score)),
          stringsAsFactors = FALSE
        )
      } else {
        table <- value
      }
      score_values <- suppressWarnings(as.numeric(table$Score))
      valid_scores <- score_values[!is.na(score_values) & score_values >= 0]
      is_fractional <- length(valid_scores) > 0L &&
        max(valid_scores) <= 1
      score_digits <- if (is_fractional) 3L else 1L
      score_breaks <- if (is_fractional) c(0.4, 0.7) else c(40, 70)
      result <- DT::datatable(
        table,
        rownames = FALSE,
        class = "compact stripe spi-profile-score-table",
        options = list(pageLength = 10, dom = "tip")
      )
      if ("Score" %in% names(table)) {
        result <- DT::formatRound(result, "Score", digits = score_digits)
        result <- DT::formatStyle(
          result,
          "Score",
          backgroundColor = DT::styleInterval(
            score_breaks, c("#fde2e1", "#fff3cd", "#dff3e4")
          ),
          color = DT::styleInterval(
            score_breaks, c("#a12828", "#795900", "#176b42")
          ),
          fontWeight = "700"
        )
      }
      result
    }

    for (name in c("pillars", "dimensions", "indicators", "benchmarks")) {
      local({
        section_name <- name
        output[[paste0("profile_", section_name, "_status")]] <-
          shiny::renderText(country_profile_section_message(section(section_name)))
        output[[paste0("profile_", section_name)]] <- DT::renderDT({
          profile_score_table(section_name)
        })
      })
    }

    list(
      profile = profile_value,
      selected_country = selected_country,
      selected_countries = selected_countries,
      selected_year = selected_year,
      available_years = available_years
    )
  })
}
