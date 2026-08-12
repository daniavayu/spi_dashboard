app_ui <- function(request = NULL) {
  shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$title("SPI | Global Overview"),
      shiny::tags$style(shiny::HTML(
        paste(
          "* { box-sizing: border-box; }",
          "body { margin: 0; background: #f4f7f9; color: #17324d;",
          "font-family: Arial, sans-serif; }",
          ".spi-topbar { background: #17324d; color: white; padding: 14px 4%;",
          "display: flex; justify-content: space-between; align-items: center; }",
          ".spi-brand { font-size: 18px; font-weight: 700; letter-spacing: .02em; }",
          ".spi-nav { color: #cfe7f3; font-size: 12px; }",
          ".spi-shell { max-width: 1320px; margin: 0 auto; padding: 34px 4% 54px; }",
          ".spi-kicker { color: #0b9ed0; font-size: 11px; font-weight: 700;",
          "text-transform: uppercase; letter-spacing: .12em; }",
          ".spi-title { margin: 5px 0 4px; font-size: 34px; color: #17324d; }",
          ".spi-intro { color: #60788d; max-width: 620px; margin: 0 0 24px; }",
          ".spi-controls { display: flex; justify-content: flex-end; margin-top: -50px;",
          "margin-bottom: 26px; }",
          ".spi-controls .form-group { margin: 0; min-width: 150px; }",
          ".spi-controls label { color: #60788d; font-size: 11px; text-transform: uppercase; }",
          ".spi-controls select { border: 1px solid #c9d8e1; border-radius: 3px;",
          "height: 38px; background: white; font-weight: 700; color: #17324d; }",
          ".spi-kpis { display: grid; grid-template-columns: repeat(5, 1fr); gap: 14px;",
          "margin-bottom: 18px; }",
          ".spi-card { background: white; border: 1px solid #e0e8ed; border-radius: 7px;",
          "box-shadow: 0 2px 8px rgba(23,50,77,.05); }",
          ".spi-kpi { padding: 18px 20px; border-top: 3px solid #0b9ed0; min-height: 118px; }",
          ".spi-label { color: #6b8090; text-transform: uppercase; font-size: 10px;",
          "font-weight: 700; letter-spacing: .05em; }",
          ".spi-value { color: #17324d; font-size: 31px; font-weight: 700; margin: 8px 0 3px; }",
          ".spi-note { color: #27a36a; font-size: 11px; }",
          ".spi-main-grid { display: grid; grid-template-columns: minmax(0, 1fr);",
          "gap: 18px; margin-bottom: 18px; }",
          ".spi-bottom-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; }",
          ".spi-panel { padding: 20px; min-height: 290px; }",
          ".spi-panel h3 { font-size: 16px; margin: 0 0 3px; color: #17324d; }",
          ".spi-panel p { color: #7890a0; font-size: 11px; margin: 0 0 15px; }",
          ".spi-variation { margin-top: 16px; padding-top: 16px;",
          "border-top: 1px solid #d8e3e9; color: #7890a0; font-size: 11px; }",
          ".spi-variation-title { color: #60788d; font-size: 12px;",
          "margin-bottom: 8px; }",
          ".spi-map-panel { padding: 20px; margin-bottom: 18px; }",
          ".spi-map { min-height: 520px; background: #e3f2f8; border-radius: 4px;",
          "overflow: hidden; }",
          ".spi-map iframe { display: block; width: 100%; height: 520px; border: 0; }",
          ".spi-chart { width: 100%; height: 245px; }",
          ".spi-footer { margin-top: 24px; color: #7890a0; font-size: 11px; }",
          ".spi-tabs { border: 0; margin-top: 8px; }",
          ".spi-tabs > .nav-tabs { border-bottom: 1px solid #d8e3e9; margin-bottom: 26px; }",
          ".spi-tabs > .nav-tabs > li > a { border: 0; color: #60788d; font-size: 12px;",
          "font-weight: 700; padding: 12px 16px; }",
          ".spi-tabs > .nav-tabs > li.active > a { color: #0b9ed0; background: transparent;",
          "border-bottom: 3px solid #0b9ed0; }",
          ".spi-placeholder { min-height: 430px; display: flex; align-items: center;",
          "justify-content: center; text-align: center; background: white; border: 1px solid #e0e8ed;",
          "border-radius: 7px; box-shadow: 0 2px 8px rgba(23,50,77,.05); }",
          ".spi-placeholder h2 { color: #17324d; font-size: 22px; margin: 0 0 8px; }",
          ".spi-placeholder p { color: #7890a0; font-size: 13px; margin: 0; }",
          "@media (max-width: 900px) { .spi-kpis, .spi-main-grid, .spi-bottom-grid { grid-template-columns: 1fr 1fr; } .spi-main-grid { grid-column: span 2; } .spi-controls { margin-top: 0; justify-content: flex-start; } }",
          "@media (max-width: 620px) { .spi-kpis, .spi-main-grid, .spi-bottom-grid { grid-template-columns: 1fr; } .spi-main-grid { grid-column: auto; } .spi-title { font-size: 28px; } }",
          sep = "\n"
        )
      ))
    ),
    shiny::div(class = "spi-topbar",
      shiny::div(class = "spi-brand", "Statistical Performance Indicators"),
      shiny::div(class = "spi-nav", "WORLD BANK | DATA & ANALYTICS")
    ),
    shiny::div(class = "spi-shell",
      shiny::div(class = "spi-tabs",
        shiny::tabsetPanel(id = "main_nav", type = "tabs",
        shiny::tabPanel("Global Overview",
          shiny::div(class = "spi-kicker", "SPI dashboard"),
          shiny::h1(class = "spi-title", "Global Overview"),
          shiny::p(class = "spi-intro", "How well are national statistical systems performing worldwide? Explore SPI scores across economies and over time."),
          shiny::div(class = "spi-kpis",
        shiny::div(class = "spi-card spi-kpi", shiny::div(class = "spi-label", "Countries covered"), shiny::div(class = "spi-value", shiny::textOutput("kpi_countries", inline = TRUE)), shiny::div(class = "spi-note", "All available economies")),
        shiny::div(class = "spi-card spi-kpi", shiny::div(class = "spi-label", "Latest data year"), shiny::div(class = "spi-value", shiny::textOutput("kpi_years", inline = TRUE)), shiny::div(class = "spi-note", "Most recent valid SPI data")),
        shiny::div(class = "spi-card spi-kpi", shiny::div(class = "spi-label", "Global average score"), shiny::div(class = "spi-value", shiny::textOutput("kpi_average", inline = TRUE)), shiny::div(class = "spi-note", "Latest available year")),
          shiny::div(class = "spi-card spi-kpi", shiny::div(class = "spi-label", "Years with valid data"), shiny::div(class = "spi-value", shiny::textOutput("kpi_year_count", inline = TRUE)), shiny::div(class = "spi-note", shiny::textOutput("kpi_year_range", inline = TRUE))),
          shiny::div(class = "spi-card spi-kpi", shiny::div(class = "spi-label", "Median improvement since 2016"), shiny::div(class = "spi-value", shiny::textOutput("kpi_improvement", inline = TRUE)), shiny::div(class = "spi-note", "Points gained (median country)"))
          ),
          shiny::div(class = "spi-card spi-map-panel",
            shiny::h3("SPI Scores by Country"),
            shiny::p("Global SPI scores for the latest available year."),
            shiny::div(class = "spi-map", shiny::uiOutput("overview_flourish_map"))
          ),
          shiny::div(class = "spi-main-grid",
        shiny::div(class = "spi-card spi-panel", shiny::h3("Score Distribution"), shiny::p("Countries grouped by SPI score."), shiny::plotOutput("overview_distribution", height = "235px"))
          ),
          shiny::div(class = "spi-bottom-grid",
        shiny::div(class = "spi-card spi-panel", shiny::h3("Average SPI by Region"), shiny::p("Official aggregate scores for the latest available year."), shiny::plotOutput("overview_regions", height = "220px")),
        shiny::div(class = "spi-card spi-panel", shiny::h3("Average SPI by Income Group"), shiny::p("Country-level averages for the latest available year."), shiny::plotOutput("overview_groups", height = "220px"), shiny::div(class = "spi-variation", shiny::div(class = "spi-variation-title", "Within-group variation (IQR)"), shiny::textOutput("overview_income_variation", inline = FALSE)))
          ),
          shiny::div(class = "spi-footer", "Source: World Bank Statistical Performance Indicators (SPI). Data provider: ", shiny::textOutput("footer_provider", inline = TRUE))
        ),
        shiny::tabPanel("Country Explorer",
          shiny::div(class = "spi-placeholder", shiny::div(shiny::h2("Country Explorer"), shiny::p("Country-level exploration will be available in a future iteration.")))
        ),
        shiny::tabPanel("Country Profile",
          shiny::div(class = "spi-placeholder", shiny::div(shiny::h2("Country Profile"), shiny::p("Detailed country profiles will be available in a future iteration.")))
        ),
        shiny::tabPanel("Compare Countries",
          shiny::div(class = "spi-placeholder", shiny::div(shiny::h2("Compare Countries"), shiny::p("Country comparison tools will be available in a future iteration.")))
        ),
        shiny::tabPanel("Trends & Progress",
          shiny::div(class = "spi-card spi-panel", shiny::h2("Trends & Progress"), shiny::p("Regional trends from the official spiR visualization functions."), shiny::plotOutput("overview_region_history", height = "520px"))),
        shiny::tabPanel("Explore by Pillar",
          shiny::div(class = "spi-placeholder", shiny::div(shiny::h2("Explore by Pillar"), shiny::p("Pillar and dimension exploration will be available in a future iteration.")))
        ),
        shiny::tabPanel("Data & Downloads",
          shiny::div(class = "spi-placeholder", shiny::div(shiny::h2("Data & Downloads"), shiny::p("Data access tools will be available in a future iteration.")))
        )
      )
      )
    )
  )
}
