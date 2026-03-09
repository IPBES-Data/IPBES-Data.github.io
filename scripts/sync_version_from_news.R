news_path <- "NEWS.md"
version_path <- "VERSION"

source("scripts/version_utils.R")
version <- read_version_from_news(news_path = news_path)

writeLines(version, version_path, useBytes = TRUE)

message("Synced version from NEWS.md: ", version)
