news_path <- "NEWS.md"
site_dir <- "_site"
footer_token <- "SITE_VERSION_TOKEN"

if (!file.exists(news_path)) {
  stop("NEWS.md not found.")
}

if (!dir.exists(site_dir)) {
  stop("_site directory not found.")
}

news_lines <- readLines(news_path, warn = FALSE, encoding = "UTF-8")
version_line_idx <- grep("^-\\s+Current version:\\s+`[^`]+`\\.?\\s*$", news_lines)

if (length(version_line_idx) == 0) {
  stop("Could not find 'Current version' line in NEWS.md.")
}

version_line <- news_lines[version_line_idx[1]]
version <- sub("^-\\s+Current version:\\s+`([^`]+)`\\.?\\s*$", "\\1", version_line)
version <- trimws(version)

if (!nzchar(version)) {
  stop("Extracted version from NEWS.md is empty.")
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
