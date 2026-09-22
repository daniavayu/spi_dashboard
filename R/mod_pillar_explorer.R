pillar_explorer_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "spi-pillar-page",
      shiny::h1(class = "spi-title", "Explore by Pillar"),
      shiny::p(
        class = "spi-intro",
        "Explore one country's SPI pillars with transparent custom weights."
      ),
      shiny::div(
        class = "spi-explorer-controls spi-pillar-filters",
        shiny::selectInput(ns("country"), "Country", choices = NULL),
        shiny::selectInput(ns("year"), "Data year", choices = NULL)
      ),
      shiny::div(
        class = "spi-pillar-cards",
        lapply(seq_len(5L), function(number) {
          shiny::div(
            class = "spi-pillar-card",
            shiny::div(class = "spi-pillar-card-number", sprintf("0%d", number)),
            shiny::div(class = "spi-pillar-card-name", paste("Pillar", number)),
            shiny::div(class = "spi-pillar-card-score", shiny::textOutput(
              ns(paste0("pillar_", number, "_score")), inline = TRUE
            )),
            shiny::div(class = "spi-pillar-card-note", "Official score"),
            shiny::div(class = "spi-pillar-card-change", shiny::textOutput(
              ns(paste0("pillar_", number, "_change")), inline = TRUE
            )),
            shiny::div(class = "spi-pillar-card-contribution",
              "Weighted contribution: ", shiny::textOutput(
                ns(paste0("pillar_", number, "_contribution")), inline = TRUE
              )
            )
          )
        })
      ),
      shiny::div(
        class = "spi-card spi-panel spi-pillar-weight-panel",
        shiny::div(class = "spi-pillar-panel-heading",
          shiny::div(
            shiny::h2("Custom weighting"),
            shiny::p("Use integer percentages. The total must equal exactly 100%.")
          ),
          shiny::actionButton(ns("reset"), "Reset weights", class = "btn-secondary")
        ),
        shiny::div(
          class = "spi-pillar-weight-grid",
          lapply(seq_len(5L), function(number) {
            shiny::numericInput(
              ns(paste0("pillar_", number, "_weight")),
              paste0("Pillar ", number, " (%)"),
              value = 20, min = 0, max = 100, step = 1
            )
          })
        ),
        shiny::div(class = "spi-pillar-total",
          shiny::span("Total weight"),
          shiny::strong(shiny::textOutput(ns("total"), inline = TRUE))
        )
      ),
      shiny::div(
        class = "spi-pillar-results",
        lapply(names(c(
          official_score = "Official SPI",
          custom_score = "Custom exploratory score",
          difference = "Difference"
        )), function(output_id) {
          shiny::div(class = "spi-card spi-result-card",
            shiny::div(
              class = "spi-result-label",
              c(
                official_score = "Official SPI",
                custom_score = "Custom exploratory score",
                difference = "Difference"
              )[[output_id]]
            ),
            shiny::div(class = "spi-result-value", shiny::textOutput(
              ns(output_id), inline = TRUE
            ))
          )
        })
      ),
      shiny::div(class = "spi-pillar-status", shiny::textOutput(ns("status"))),
      shiny::div(
        class = "spi-pillar-analysis-grid",
        shiny::div(
          class = "spi-card spi-pillar-analysis-card",
          shiny::h2("Pillar Correlations"),
          shiny::p("How strongly are the five pillars correlated across countries?"),
          shiny::plotOutput(ns("correlation_plot"), height = "330px"),
          shiny::div(class = "spi-pillar-analysis-summary",
            shiny::textOutput(ns("correlation_summary")))
        ),
        shiny::div(
          class = "spi-card spi-pillar-analysis-card",
          shiny::h2("Cross-Pillar Explorer"),
          shiny::p("Compare two pillar scores across countries for the selected year."),
          shiny::div(
            class = "spi-pillar-axis-controls",
            shiny::selectInput(ns("scatter_x"), "X-Axis", choices = NULL),
            shiny::selectInput(ns("scatter_y"), "Y-Axis", choices = NULL)
          ),
          shiny::plotOutput(ns("scatter_plot"), height = "330px")
        )
      )
    )
  )
}

pillar_explorer_server <- function(
  id,
  snapshot_loader = function() spi_provider_snapshot(load_details = TRUE),
  active = function() TRUE
) {
  shiny::moduleServer(id, function(input, output, session) {
    snapshot <- shiny::reactiveVal(NULL)
    snapshot_error <- shiny::reactiveVal(NULL)

    shiny::observe({
      if (isTRUE(active()) && is.null(snapshot())) {
        loaded <- tryCatch(
          list(ok = TRUE, value = snapshot_loader()),
          error = function(error) list(
            ok = FALSE, error = conditionMessage(error)
          )
        )
        if (isTRUE(loaded$ok)) {
          snapshot(loaded$value)
        } else {
          snapshot_error(loaded$error)
          snapshot(list(index = data.frame(), pillar_labels = data.frame()))
        }
      }
    })

    index <- shiny::reactive({
      value <- snapshot()
      if (is.null(value) || !is.data.frame(value$index)) {
        return(data.frame())
      }
      value$index
    })
    schema <- shiny::reactive({
      value <- snapshot()
      labels <- if (is.null(value)) NULL else value$pillar_labels
      pillar_explorer_schema(index(), labels)
    })
    choices <- shiny::reactive({
      pillar_explorer_country_year_choices(index())
    })
    country_choices <- shiny::reactive({
      rows <- pillar_explorer_country_choices(index())
      if (!nrow(rows)) return(character())
      stats::setNames(rows$country_code, rows$country_name)
    })

    shiny::observeEvent(choices(), {
      countries <- country_choices()
      selected_country <- if (length(countries)) {
        if (!is.null(input$country) && !is.na(input$country) &&
          input$country %in% countries) {
          input$country
        } else {
          unname(countries[[1L]])
        }
      } else {
        character()
      }
      shiny::updateSelectInput(
        session, "country", choices = countries, selected = selected_country
      )
      years <- pillar_explorer_year_choices(index(), selected_country)
      shiny::updateSelectInput(
        session, "year", choices = years,
        selected = if (length(years)) max(years) else character()
      )
      pillar_choices <- stats::setNames(
        schema()$columns, schema()$labels
      )
      shiny::updateSelectInput(
        session, "scatter_x", choices = pillar_choices,
        selected = schema()$columns[[1L]]
      )
      shiny::updateSelectInput(
        session, "scatter_y", choices = pillar_choices,
        selected = schema()$columns[[3L]]
      )
    }, ignoreInit = FALSE)

    selected_country <- shiny::reactive({
      countries <- country_choices()
      requested <- as.character(input$country)
      if (length(countries) && length(requested) == 1L &&
        !is.na(requested) &&
        requested %in% countries) {
        requested
      } else if (length(countries)) {
        unname(countries[[1L]])
      } else {
        NA_character_
      }
    })
    selected_year <- shiny::reactive({
      years <- pillar_explorer_year_choices(index(), selected_country())
      requested <- suppressWarnings(as.integer(input$year))
      if (length(years) && length(requested) == 1L &&
        !is.na(requested) && requested %in% years) {
        requested
      } else if (length(years)) {
        max(years)
      } else {
        NA_integer_
      }
    })
    selected_row <- shiny::reactive({
      data <- index()
      if (!nrow(data) || is.na(selected_country()) ||
        is.na(selected_year())) {
        return(data[FALSE, , drop = FALSE])
      }
      data[data$country_code == selected_country() &
        data$year == selected_year(), , drop = FALSE]
    })
    previous_row <- shiny::reactive({
      data <- index()
      current_year <- selected_year()
      if (!nrow(data) || is.na(selected_country()) || is.na(current_year)) {
        return(data[FALSE, , drop = FALSE])
      }
      candidates <- data[data$country_code == selected_country() &
        suppressWarnings(as.integer(data$year)) < current_year, , drop = FALSE]
      if (!nrow(candidates)) return(data[FALSE, , drop = FALSE])
      candidates[which.max(as.integer(candidates$year)), , drop = FALSE]
    })
    weights <- shiny::reactive({
      vapply(seq_len(5L), function(number) {
        value <- input[[paste0("pillar_", number, "_weight")]]
        if (is.null(value)) 20 else suppressWarnings(as.numeric(value))
      }, numeric(1L))
    })
    calculation <- shiny::reactive({
      row <- selected_row()
      scores <- if (nrow(row)) {
        as.numeric(row[1L, schema()$columns, drop = TRUE])
      } else {
        rep(NA_real_, 5L)
      }
      official <- if (nrow(row)) row$score[[1L]] else NA_real_
      pillar_explorer_calculate(scores, weights(), official)
    })
    pillar_metrics <- shiny::reactive({
      row <- selected_row()
      previous <- previous_row()
      scores <- if (nrow(row)) {
        as.numeric(row[1L, schema()$columns, drop = TRUE])
      } else {
        rep(NA_real_, 5L)
      }
      previous_scores <- if (nrow(previous)) {
        as.numeric(previous[1L, schema()$columns, drop = TRUE])
      } else {
        rep(NA_real_, 5L)
      }
      result <- pillar_explorer_pillar_metrics(
        scores, previous_scores, calculation()$effective_weights
      )
      result$previous_year <- if (nrow(previous)) {
        as.integer(previous$year[[1L]])
      } else {
        NA_integer_
      }
      result
    })

    shiny::observeEvent(input$reset, {
      for (number in seq_len(5L)) {
        shiny::updateNumericInput(
          session, paste0("pillar_", number, "_weight"), value = 20
        )
      }
    })

    output$total <- shiny::renderText({
      values <- weights()
      if (anyNA(values) || any(!is.finite(values))) "-" else {
        paste0(sum(values), "%")
      }
    })
    for (number in seq_len(5L)) {
      local({
        pillar_number <- number
        output[[paste0("pillar_", pillar_number, "_score")]] <-
          shiny::renderText({
            row <- selected_row()
            column <- schema()$columns[[pillar_number]]
            value <- if (nrow(row) && column %in% names(row)) {
              suppressWarnings(as.numeric(row[[column]][[1L]]))
            } else {
              NA_real_
            }
            if (is.na(value)) "-" else sprintf("%.1f", value)
          })
        output[[paste0("pillar_", pillar_number, "_change")]] <-
          shiny::renderText({
            value <- pillar_metrics()$change[[pillar_number]]
            previous_year <- pillar_metrics()$previous_year
            if (is.na(value)) "No prior year" else sprintf(
              "%+.1f vs %s", value, previous_year
            )
          })
        output[[paste0("pillar_", pillar_number, "_contribution")]] <-
          shiny::renderText({
            value <- pillar_metrics()$contribution[[pillar_number]]
            if (is.na(value)) "-" else sprintf("%.1f pts", value)
          })
      })
    }
    output$official_score <- shiny::renderText({
      value <- calculation()$official_score
      if (is.na(value)) "-" else sprintf("%.2f", value)
    })
    output$custom_score <- shiny::renderText({
      value <- calculation()$custom_score
      if (is.na(value)) "-" else sprintf("%.2f", value)
    })
    output$difference <- shiny::renderText({
      value <- calculation()$difference
      if (is.na(value)) "-" else sprintf("%.2f", value)
    })
    output$status <- shiny::renderText({
      if (!is.null(snapshot_error())) {
        return(paste("Data could not be loaded:", snapshot_error()))
      }
      if (is.null(snapshot())) return("Loading pillar data...")
      if (!identical(schema()$status, "ok")) return(schema()$message)
      if (!nrow(choices())) return("No country-year with valid pillar scores.")
      result <- calculation()
      if (!identical(result$status, "ok")) return(result$message)
      if (isTRUE(result$coverage$renormalized)) return(result$message)
      ""
    })
    output$correlation_plot <- shiny::renderPlot({
      matrix <- pillar_explorer_correlation(index(), selected_year())
      labels <- schema()$labels
      if (!any(is.finite(matrix))) {
        plot.new()
        text(0.5, 0.5, "Not enough country data for correlations")
        return(invisible(NULL))
      }
      graphics::par(mar = c(5, 6, 1, 1))
      graphics::image(
        x = seq_len(5L), y = seq_len(5L), z = t(matrix[5:1, , drop = FALSE]),
        col = grDevices::colorRampPalette(c("#e6f4fb", "#3b95c8", "#002244"))(20),
        zlim = c(-1, 1), axes = FALSE, xlab = "", ylab = ""
      )
      graphics::axis(1, at = seq_len(5L), labels = labels, las = 2,
        cex.axis = 0.75)
      graphics::axis(2, at = seq_len(5L), labels = rev(labels), las = 2,
        cex.axis = 0.75)
      for (row in seq_len(5L)) for (column in seq_len(5L)) {
        value <- matrix[row, column]
        if (is.finite(value)) graphics::text(column, 6L - row,
          sprintf("%.2f", value), col = if (value > 0.55) "white" else "#17324d",
          cex = 0.8, font = 2)
      }
      graphics::box()
    })
    output$correlation_summary <- shiny::renderText({
      pillar_explorer_correlation_summary(
        pillar_explorer_correlation(index(), selected_year()), schema()$labels
      )
    })
    output$scatter_plot <- shiny::renderPlot({
      data <- pillar_explorer_scatter_data(
        index(), selected_year(), input$scatter_x, input$scatter_y
      )
      if (!nrow(data)) {
        plot.new()
        text(0.5, 0.5, "Not enough data for this comparison")
        return(invisible(NULL))
      }
      x_label <- schema()$labels[match(input$scatter_x, schema()$columns)]
      y_label <- schema()$labels[match(input$scatter_y, schema()$columns)]
      graphics::plot(data$x, data$y, pch = 19, col = "#2f8bc1",
        xlim = c(0, 100), ylim = c(0, 100), xlab = x_label, ylab = y_label)
      graphics::text(data$x, data$y, labels = data$country_name,
        pos = 3, cex = 0.65, col = "#53616c")
      graphics::grid(col = "#e8e8e8", lty = 1)
      graphics::points(data$x, data$y, pch = 19, col = "#2f8bc1")
    })
  })
}
