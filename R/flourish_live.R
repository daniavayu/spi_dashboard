flourish_live_map_ui <- function(regions) {
  api_key <- Sys.getenv("FLOURISH_API_KEY", unset = "")
  if (!nzchar(api_key)) {
    return(shiny::tags$iframe(
      src = paste0(
        "https://flo.uri.sh/visualisation/",
        FLOURISH_VISUALISATION_ID,
        "/embed?auto=1"
      ),
      title = "SPI scores by country, 2024",
      loading = "lazy",
      allow = "fullscreen"
    ))
  }

  regions_json <- jsonlite::toJSON(
    regions,
    dataframe = "rows",
    auto_unbox = TRUE,
    na = "null"
  )
  api_key_json <- jsonlite::toJSON(api_key, auto_unbox = TRUE)
  visualisation_id_json <- jsonlite::toJSON(
    FLOURISH_VISUALISATION_ID,
    auto_unbox = TRUE
  )
  script <- paste0(
    "(function() {",
    "var target = document.getElementById('spi-flourish-map');",
    "var spiRegions = ", regions_json, ";",
    "var apiKey = ", api_key_json, ";",
    "var baseId = ", visualisation_id_json, ";",
    "var load = function() {",
    "fetch('https://public.flourish.studio/visualisation/' + baseId + '/visualisation-object.json')",
    ".then(function(response) { return response.json(); })",
    ".then(function(base) {",
    "base.data.regions = spiRegions;",
    "Object.keys(base.data).forEach(function(dataset) {",
    "(base.data[dataset] || []).forEach(function(row) {",
    "Object.keys(row).forEach(function(key) {",
    "if (row[key] === null || row[key] === undefined) row[key] = '';",
    "}); }); });",
    "new Flourish.Live({container: '#spi-flourish-map', api_key: apiKey,",
    "template: base.template, version: base.version, state: base.state,",
    "bindings: base.bindings, data: base.data, metadata: base.metadata});",
    "})",
    ".catch(function(error) { target.textContent = 'Unable to load the Flourish map.';",
    "console.error(error); }); };",
    "if (window.Flourish) load(); else {",
    "var script = document.createElement('script');",
    "script.src = 'https://cdn.flourish.rocks/flourish-live-v5.min.js';",
    "script.onload = load; document.head.appendChild(script); }",
    "})();"
  )

  shiny::tagList(
    shiny::div(id = "spi-flourish-map"),
    shiny::tags$script(shiny::HTML(script))
  )
}
