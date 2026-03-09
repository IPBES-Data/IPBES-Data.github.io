news_path <- "NEWS.md"
site_dir <- "_site"
footer_token <- "SITE_VERSION_TOKEN"

source("scripts/version_utils.R")
version <- read_version_from_news(news_path = news_path)

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
  replaced <- gsub(footer_token, version, lines, fixed = TRUE)
  if (!identical(lines, replaced)) {
    writeLines(replaced, path, useBytes = TRUE)
    updated <- updated + 1L
  }
}

message("Injected footer version ", version, " into ", updated, " HTML file(s).")
