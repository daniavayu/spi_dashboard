spi_provider_functions <- function(preferred = "spiR", root = app_root()) {
  provider <- spi_select_provider(preferred)
  if (identical(provider, "spiR")) {
    return(list(
      name = provider,
      index = spiR::spi_index,
      indicators = spiR::spi_data,
      metadata = spiR::country_info,
      aggregates = spiR::spi_aggregates
    ))
  }

  app_source_local_provider(root)
  list(
    name = provider,
    index = spi_index,
    indicators = spi_data,
    metadata = country_info,
    aggregates = spi_aggregates
  )
}

spi_provider_snapshot <- function(
  year = NULL,
  preferred = "spiR",
  root = app_root(),
  load_details = TRUE,
  load_aggregates = TRUE
) {
  provider <- spi_provider_functions(preferred = preferred, root = root)
  index <- provider$index(year = year)
  metadata_raw <- provider$metadata(year = year)
  if (isTRUE(load_details)) {
    indicators <- provider$indicators(year = year)
    metadata <- metadata_raw
  } else {
    indicators <- data.frame()
    metadata <- data.frame()
  }
  if (isTRUE(load_aggregates)) {
    aggregates <- provider$aggregates(year = year)
  } else {
    aggregates <- data.frame(
      group_code = character(), group_name = character(), year = integer(),
      source_id = character(), score = numeric(),
      stringsAsFactors = FALSE
    )
  }

  list(
    provider = provider$name,
    index = spi_normalize_index(index, year = year),
    indicators = if (isTRUE(load_details)) {
      spi_normalize_indicators(indicators)
    } else {
      data.frame()
    },
    income_data = spi_normalize_income_data(
      index,
      metadata_raw,
      year = year
    ),
    metadata = if (isTRUE(load_details)) {
      spi_normalize_metadata(metadata)
    } else {
      data.frame()
    },
    aggregates = if (isTRUE(load_aggregates)) {
      spi_normalize_aggregates(aggregates, year = year)
    } else {
      aggregates
    },
    years = spi_available_years(index)
  )
}
