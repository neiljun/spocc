spocc_inat_obs <- function(query=NULL, taxon = NULL, quality=NULL, geo=TRUE, 
                           year=NULL, month=NULL, day=NULL, bounds=NULL, 
                           date_start = NULL, date_end = NULL,
                           maxresults=100, page=NULL, callopts) {
  
  # input parameter checks
  if (!is.null(quality)) quality <- match.arg(quality, c("casual","research"))
  if (!is.null(year)) {
    if (length(year) > 1) {
      stop("can only filter results by 1 year; enter only 1 value for year", 
           call. = FALSE)
    }
  }
  if (!is.null(month)) {
    month <- as.numeric(month)
    if (is.na(month)) {
      stop("please enter a month as a number between 1 and 12, not as a word", 
           call. = FALSE)
    }
    if (length(month) > 1) {
      stop("can only filter results by one month; enter only 1 value for month", 
           call. = FALSE)
    }
    if (month < 1 || month > 12) {
      stop("Please enter a valid month between 1 and 12", call. = FALSE)
    }
  }
  if (!is.null(day)) {
    day <- as.numeric(day)
    if (is.na(day)) {
      stop("please enter a day as a number between 1 and 31, not as a word", 
           call. = FALSE)
    }
    if (length(day) > 1) {
      stop("can only filter results by one day; enter only one value for day", 
           call. = FALSE)
    }
    if (day < 1 || day > 31) stop("Please enter a valid day between 1 and 31", 
                                  call. = FALSE)
  }
  if (!is.null(bounds)) {
    if (length(bounds) != 4) {
      stop("bounding box specifications must have 4 coordinates", call. = FALSE)
    }
  }
  
  args <- sc(list(q = query, quality_grade = quality, taxon_name = taxon, 
                  `has[]` = if (!is.null(geo) && geo) "geo" else NULL, 
                  year = year, month = month, day = day, 
                  d1 = date_start, d2 = date_end))
  bounds <- list(swlat = bounds[1], swlng = bounds[2], nelat = bounds[3], 
                 nelng = bounds[4])
  args <- sc(c(args, bounds))

  q_path <- "observations.csv"
  ping_path <- "observations.json"
  
  if (!is.null(page)) {
    page_query <- c(args, per_page = maxresults, page = page)
    cli <- crul::HttpClient$new(url = inat_base_url(), opts = callopts)
    res <- cli$get(path = q_path, query = page_query)
    
    total_res <- as.numeric(res$headers$`x-total-entries`)
    res <- spocc_inat_handle(res)
    data_out <- if (is.na(res)) NA else utils::read.csv(textConnection(res), 
                                                 stringsAsFactors = FALSE)
  } else {
    ping_query <- c(args, page = 1, per_page = 1)
    cli <- crul::HttpClient$new(url = inat_base_url(), opts = callopts)
    out <- cli$get(path = ping_path, query = ping_query)
    out$raise_for_status()
    total_res <- as.numeric(out$response_headers$`x-total-entries`)
    
    if (total_res == 0) {
      stop("no results; either no records or entered an invalid search", 
           call. = FALSE)
    }
    
    page_query <- c(args, per_page = 200, page = 1)
    data <- cli$get(path = ping_path, query = page_query)
    data <- spocc_inat_handle(data)
    data_out <- jsonlite::fromJSON(data, flatten = TRUE)
    data_out$photos <- NULL
    data_out$tag_list <- sapply(data_out$tag_list, function(x) {
      if (length(x) == 0) "" else paste0(x, collapse = ", ")
    })
    
    if (total_res < maxresults) maxresults <- total_res
    if (maxresults > 200) {
      for (i in 2:ceiling(maxresults/200)) {
        page_query <- c(args, per_page = 200, page = i)
        data <- cli$get(path = q_path, query = page_query)
        data <- spocc_inat_handle(data)
        data_out2 <- jsonlite::fromJSON(data, flatten = TRUE)
        data_out2$photos <- NULL
        data_out2$tag_list <- sapply(data_out2$tag_list, function(x) {
          if (length(x) == 0) "" else paste0(x, collapse = ", ")
        })
        data_out <- rbind(data_out, data_out2)
      }
    }
    
    if (is.data.frame(data_out)) {
      if (maxresults < dim(data_out)[1]) {
        data_out <- data_out[1:maxresults,]
      }
    }
  }
  
  list(meta = list(found = total_res, returned = NROW(data_out)), 
       data = data_out)
}

spocc_inat_handle <- function(x){
  res <- x$parse("UTF-8")
  if (!x$response_headers$`content-type` == 'application/json; charset=utf-8' || 
      x$status_code > 202 || 
      nchar(res) == 0 
    ) {
    if (!x$response_headers$`content-type` == 
        'application/json; charset=utf-8') {
      warning(
        "Conent type incorrect, should be 'application/json; charset=utf-8'")
      NA
    }
    if (x$status_code > 202) {
      warning(sprintf("Error: HTTP Status %s", data$status_code))
      NA
    }
    if (nchar(res) == 0) {
      warning("No data found")
      NA
    }
  } else { 
    res 
  }
}

spocc_get_inat_obs_id <- function(id, callopts = list()) {
  q_path <- paste("observations/", as.character(id), ".json", sep = "")
  cli <- crul::HttpClient$new(url = inat_base_url(), opts = callopts)
  res <- cli$get(path = q_path)
  res$raise_for_status()
  jsonlite::fromJSON(res$parse("UTF-8"))
}

inat_base_url <- function() "http://www.inaturalist.org/"
