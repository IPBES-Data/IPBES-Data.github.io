read_version_from_news <- function(news_path = "NEWS.md") {
  if (!file.exists(news_path)) {
    stop("NEWS.md not found.")
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

  version
}
