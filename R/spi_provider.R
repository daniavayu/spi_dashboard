spi_provider_functions <- function(
  preferred = "spiR",
  root = app_root(),
  provider_functions = NULL
) {
  if (!is.null(provider_functions)) {
    required <- c("name", "index")
    missing <- setdiff(required, names(provider_functions))
    if (length(missing) > 0L) {
      stop(
        "Provider functions are missing: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
    optional <- c("indicators", "metadata", "aggregates")
    for (operation in setdiff(optional, names(provider_functions))) {
      provider_functions[operation] <- list(NULL)
    }
    return(provider_functions)
  }

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

spi_provider_normalize_optional <- function(call, normalizer, empty, ...) {
  if (!isTRUE(call$ok)) {
    return(list(
      value = empty,
      status = call[c("ok", "status", "error")]
    ))
  }
  value <- tryCatch(
    normalizer(call$value, ...),
    error = function(error) {
      list(
        value = empty,
        status = list(
          ok = FALSE,
          status = "error",
          error = conditionMessage(error)
        )
      )
    }
  )
  if (is.list(value) && "value" %in% names(value)) {
    return(value)
  }
  list(
    value = value,
    status = list(ok = TRUE, status = "ok", error = NULL)
  )
}

spi_provider_call <- function(provider, operation, year = NULL) {
  function_value <- provider[[operation]]
  if (!is.function(function_value)) {
    return(list(
      ok = FALSE,
      status = "unavailable",
      error = paste0("Provider operation is unavailable: ", operation),
      value = NULL
    ))
  }

  previous_timeout <- getOption("timeout")
  if (is.null(previous_timeout) || !is.numeric(previous_timeout) ||
    length(previous_timeout) != 1L || is.na(previous_timeout)) {
    previous_timeout <- 60
  }
  options(timeout = min(previous_timeout, 30))
  on.exit(options(timeout = previous_timeout), add = TRUE)
  result <- tryCatch(
    function_value(year = year),
    error = function(error) {
      list(
        ok = FALSE,
        status = "error",
        error = conditionMessage(error),
        value = NULL
      )
    }
  )
  if (is.list(result) && identical(result$ok, FALSE)) {
    return(result)
  }
  list(ok = TRUE, status = "ok", error = NULL, value = result)
}

spi_provider_snapshot <- function(
  year = NULL,
  preferred = "spiR",
  root = app_root(),
  load_details = TRUE,
  load_metadata = load_details,
  load_aggregates = TRUE,
  provider_functions = NULL
) {
  provider <- spi_provider_functions(
    preferred = preferred,
    root = root,
    provider_functions = provider_functions
  )
  index_call <- spi_provider_call(provider, "index", year = year)
  if (!isTRUE(index_call$ok)) {
    stop(index_call$error, call. = FALSE)
  }
  index_raw <- tryCatch(
    index_call$value,
    error = function(error) stop(conditionMessage(error), call. = FALSE)
  )
  index <- tryCatch(
    spi_normalize_index(index_raw, year = year),
    error = function(error) stop(conditionMessage(error), call. = FALSE)
  )

  operation_status <- list(
    index = list(ok = TRUE, status = "ok", error = NULL)
  )

  metadata_result <- if (isTRUE(load_metadata)) {
    metadata_call <- spi_provider_call(provider, "metadata", year = year)
    spi_provider_normalize_optional(
      metadata_call, spi_normalize_metadata, spi_empty_metadata()
    )
  } else {
    list(
      value = spi_empty_metadata(),
      status = list(
        ok = FALSE,
        status = "unavailable",
        error = "Operation was not requested"
      )
    )
  }
  metadata <- metadata_result$value
  operation_status$metadata <- metadata_result$status

  indicators_result <- if (isTRUE(load_details)) {
    indicators_call <- spi_provider_call(provider, "indicators", year = year)
    spi_provider_normalize_optional(
      indicators_call, spi_normalize_indicators, spi_empty_indicators()
    )
  } else {
    list(
      value = spi_empty_indicators(),
      status = list(
        ok = FALSE,
        status = "unavailable",
        error = "Operation was not requested"
      )
    )
  }
  indicators <- indicators_result$value
  operation_status$indicators <- indicators_result$status

  aggregates_result <- if (isTRUE(load_aggregates)) {
    aggregates_call <- spi_provider_call(provider, "aggregates", year = year)
    spi_provider_normalize_optional(
      aggregates_call, spi_normalize_aggregates, spi_empty_aggregates(),
      year = year
    )
  } else {
    list(
      value = spi_empty_aggregates(),
      status = list(
        ok = FALSE,
        status = "unavailable",
        error = "Operation was not requested"
      )
    )
  }
  aggregates <- aggregates_result$value
  operation_status$aggregates <- aggregates_result$status

  income_data <- if (nrow(metadata) > 0L) {
    spi_normalize_income_data(index_raw, metadata, year = year)
  } else {
    data.frame(
      country_code = character(), country_name = character(),
      year = integer(), income_group = character(), score = numeric(),
      stringsAsFactors = FALSE
    )
  }

  list(
    provider = provider$name,
    index = index,
    indicators = indicators,
    income_data = income_data,
    metadata = metadata,
    aggregates = aggregates,
    years = spi_available_years(index),
    operation_status = operation_status
  )
}
