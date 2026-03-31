news_path <- "NEWS.md"
site_dir <- "_site"
version_token <- "SITE_VERSION_TOKEN"
data_fetched_token <- "DATA_FETCHED_TOKEN"

if (!file.exists(news_path)) {
  stop("NEWS.md not found.")
}

news_lines <- readLines(news_path, warn = FALSE, encoding = "UTF-8")
date_heading_idx <- grep("^##\\s+[0-9]{4}-[0-9]{2}-[0-9]{2}\\s*$", news_lines)
if (length(date_heading_idx) == 0) {
  stop("Could not find any dated section header in NEWS.md (expected: ## YYYY-MM-DD).")
}

latest_heading <- trimws(news_lines[date_heading_idx[1]])
news_date <- sub("^##\\s+([0-9]{4})-([0-9]{2})-([0-9]{2})\\s*$", "\\1.\\2.\\3", latest_heading)
version <- paste0("v", news_date)
if (!nzchar(version)) {
  stop("Extracted version from NEWS.md is empty.")
}

data_fetched_utc <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%d %H:%M")

if (!dir.exists(site_dir)) {
  stop("_site directory not found.")
}

html_files <- list.files(site_dir, pattern = "\\.html$", recursive = TRUE, full.names = TRUE)
if (length(html_files) == 0) {
  stop("No HTML files found in _site.")
}

updated <- 0L
for (path in html_files) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  replaced <- gsub(version_token, version, lines, fixed = TRUE)
  replaced <- gsub(data_fetched_token, data_fetched_utc, replaced, fixed = TRUE)

  if (!identical(lines, replaced)) {
    writeLines(replaced, path, useBytes = TRUE)
    updated <- updated + 1L
  }
}

message("Injected footer version ", version, " and data fetched timestamp ", data_fetched_utc, " UTC into ", updated, " HTML file(s).")
