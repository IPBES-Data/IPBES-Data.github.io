trim_char_columns <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return(df)
  }

  df[] <- lapply(df, function(x) if (is.character(x)) trimws(x) else x)
  df
}

read_trimmed_csv <- function(path) {
  trim_char_columns(read.csv(path, stringsAsFactors = FALSE))
}

filter_required_nonempty <- function(df, required_cols) {
  if (is.null(df) || nrow(df) == 0) {
    return(df)
  }

  for (col in required_cols) {
    if (!(col %in% names(df))) {
      df[[col]] <- ""
    }
  }

  keep <- rep(TRUE, nrow(df))
  for (col in required_cols) {
    keep <- keep & !is.na(df[[col]]) & nzchar(df[[col]])
  }

  df[keep, , drop = FALSE]
}

load_site_inputs <- function(input_dir = "input") {
  assessments <- read_trimmed_csv(file.path(input_dir, "assessments.csv"))
  dir_map <- read_trimmed_csv(file.path(input_dir, "assessment_directory_map.csv"))
  tg_labels_fallback <- read_trimmed_csv(file.path(input_dir, "technical_guideline_labels.csv"))
  shiny_apps_fallback <- read_trimmed_csv(file.path(input_dir, "shiny_apps_fallback.csv"))

  dir_map <- filter_required_nonempty(dir_map, c("abbreviation", "directory_path"))
  tg_labels_fallback <- filter_required_nonempty(tg_labels_fallback, c("repo_name", "title", "page_url"))

  list(
    assessments = assessments,
    dir_map = dir_map,
    tg_labels_fallback = tg_labels_fallback,
    shiny_apps_fallback = shiny_apps_fallback
  )
}

empty_repos <- function(include_description = FALSE) {
  if (isTRUE(include_description)) {
    return(data.frame(repo_name = character(0), description = character(0), url = character(0), stringsAsFactors = FALSE))
  }

  data.frame(repo_name = character(0), repo_url = character(0), stringsAsFactors = FALSE)
}

empty_tg_labels <- function() {
  data.frame(repo_name = character(0), title = character(0), page_url = character(0), stringsAsFactors = FALSE)
}

empty_shiny_apps <- function() {
  data.frame(name = character(0), title = character(0), url = character(0), status = character(0), stringsAsFactors = FALSE)
}

get_cached_repos <- function(path = "tree.rds", include_description = FALSE) {
  if (!file.exists(path) || !requireNamespace("data.tree", quietly = TRUE)) {
    return(empty_repos(include_description = include_description))
  }

  repo_tree <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(repo_tree)) {
    return(empty_repos(include_description = include_description))
  }

  fields <- c("repoName", "url")
  if (isTRUE(include_description)) {
    fields <- c(fields, "description")
  }

  repo_df <- tryCatch(
    do.call(data.tree::ToDataFrameTree, c(list(repo_tree), as.list(fields))),
    error = function(e) NULL
  )
  if (is.null(repo_df) || nrow(repo_df) == 0) {
    return(empty_repos(include_description = include_description))
  }

  repo_df <- repo_df[
    !is.na(repo_df$repoName) & !is.na(repo_df$url) &
      nzchar(repo_df$repoName) & nzchar(repo_df$url),
    ,
    drop = FALSE
  ]

  if (isTRUE(include_description)) {
    out <- data.frame(
      repo_name = repo_df$repoName,
      description = ifelse(is.na(repo_df$description), "", repo_df$description),
      url = repo_df$url,
      stringsAsFactors = FALSE
    )
  } else {
    out <- data.frame(
      repo_name = repo_df$repoName,
      repo_url = repo_df$url,
      stringsAsFactors = FALSE
    )
  }

  unique(out)
}

get_org_repos_raw <- function(org = "IPBES-Data") {
  if (!requireNamespace("gh", quietly = TRUE)) {
    return(NULL)
  }

  tryCatch(
    gh::gh("GET /orgs/:org/repos", org = org, per_page = 200),
    error = function(e) NULL
  )
}

get_org_repos_for_index <- function(org = "IPBES-Data", cache_path = "tree.rds") {
  repos_raw <- get_org_repos_raw(org = org)

  if (!is.null(repos_raw) && length(repos_raw) > 0) {
    repos_live <- data.frame(
      repo_name = vapply(repos_raw, function(x) x$name, character(1)),
      repo_url = vapply(repos_raw, function(x) x$html_url, character(1)),
      stringsAsFactors = FALSE
    )
    return(list(data = repos_live, source = "live"))
  }

  repos_cached <- get_cached_repos(path = cache_path, include_description = FALSE)
  if (nrow(repos_cached) > 0) {
    return(list(data = repos_cached, source = "cached"))
  }

  list(data = empty_repos(include_description = FALSE), source = "none")
}

get_org_repos_for_repos <- function(org = "IPBES-Data", cache_path = "tree.rds") {
  repos_raw <- get_org_repos_raw(org = org)

  if (!is.null(repos_raw) && length(repos_raw) > 0) {
    repos_live <- data.frame(
      repo_name = vapply(repos_raw, function(x) x$name, character(1)),
      description = vapply(repos_raw, function(x) ifelse(is.null(x$description), "", x$description), character(1)),
      url = vapply(repos_raw, function(x) x$html_url, character(1)),
      stringsAsFactors = FALSE
    )
    return(list(data = repos_live, source = "live GitHub API"))
  }

  repos_cached <- get_cached_repos(path = cache_path, include_description = TRUE)
  if (nrow(repos_cached) > 0) {
    return(list(data = repos_cached, source = "cached (tree.rds)"))
  }

  list(data = empty_repos(include_description = TRUE), source = "unavailable")
}

escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x <- gsub("'", "&#39;", x, fixed = TRUE)
  x
}

get_assessment_directory_path <- function(abbreviation, map_df) {
  hit <- which(tolower(map_df$abbreviation) == tolower(abbreviation))
  if (length(hit) == 0) {
    return("")
  }

  map_df$directory_path[hit[1]]
}

build_assessment_directory_link_html <- function(abbreviation, map_df, base_url = "https://ipbes-data.github.io/IPBES_Assessment_Directories") {
  directory_path <- get_assessment_directory_path(abbreviation, map_df)

  if (!nzchar(directory_path)) {
    return("<span class='assessment-repos-empty'>No published directory.</span>")
  }

  full_url <- paste0(base_url, "/", directory_path, "/index.html")
  paste0(
    "<a href='", escape_html(full_url), "' target='_blank' rel='noopener'>",
    "IPBES_Assessment_Directories/", escape_html(directory_path), "/index.html",
    "</a>"
  )
}

format_assessment_dir_link <- function(directory_path, base_url = "https://ipbes-data.github.io/IPBES_Assessment_Directories") {
  if (!nzchar(directory_path)) {
    return("No published directory")
  }

  paste0(
    "<a href='", base_url, "/", directory_path, "/index.html",
    "' target='_blank' rel='noopener'>IPBES_Assessment_Directories/", directory_path, "/index.html</a>"
  )
}

normalize_url <- function(url) {
  if (is.na(url) || !nzchar(url)) {
    return("")
  }

  if (grepl("^https?://", url)) {
    return(url)
  }

  if (startsWith(url, "/")) {
    return(paste0("https://ipbes-data.github.io", url))
  }

  paste0("https://ipbes-data.github.io/", url)
}

extract_repo_name_from_url <- function(url) {
  cleaned <- sub("/+$", "", url)
  parts <- strsplit(cleaned, "/", fixed = TRUE)[[1]]
  if (length(parts) == 0) {
    return("")
  }

  tail(parts, 1)
}

order_tg_labels <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }

  non_template <- !(
    grepl("TEMPLATE", df$repo_name, ignore.case = TRUE) |
      grepl("^\\s*TEMPLATE\\b", df$title, ignore.case = TRUE)
  )
  df <- df[non_template, , drop = FALSE]

  if (nrow(df) == 0) {
    return(df)
  }

  match <- regexec("^\\s*Part\\s*([0-9]+)\\s*([A-Za-z]?)\\b", df$title, ignore.case = TRUE)
  parsed <- regmatches(df$title, match)

  sort_group <- rep(1L, nrow(df))
  sort_num <- rep(9999L, nrow(df))
  sort_suffix <- rep(999L, nrow(df))

  for (i in seq_len(nrow(df))) {
    p <- parsed[[i]]
    if (length(p) >= 2) {
      sort_group[i] <- 0L
      sort_num[i] <- suppressWarnings(as.integer(p[2]))
      suffix <- if (length(p) >= 3) toupper(p[3]) else ""
      sort_suffix[i] <- if (nzchar(suffix)) match(suffix, LETTERS) else 0L
      if (is.na(sort_suffix[i])) {
        sort_suffix[i] <- 999L
      }
    }
  }

  df <- unique(df)
  df[order(sort_group, sort_num, sort_suffix, tolower(df$title)), , drop = FALSE]
}

get_tg_labels_from_site <- function(directory_url = "https://ipbes-data.github.io/IPBES_TG_Directory/") {
  if (!requireNamespace("rvest", quietly = TRUE)) {
    return(empty_tg_labels())
  }

  page <- tryCatch(rvest::read_html(directory_url), error = function(e) NULL)
  if (is.null(page)) {
    return(empty_tg_labels())
  }

  anchors <- rvest::html_elements(page, "a")
  href <- rvest::html_attr(anchors, "href")
  title <- trimws(rvest::html_text2(anchors))

  href <- vapply(href, normalize_url, character(1))
  repo_name <- vapply(href, extract_repo_name_from_url, character(1))

  out <- data.frame(
    repo_name = repo_name,
    title = title,
    page_url = href,
    stringsAsFactors = FALSE
  )

  out <- out[
    grepl("^IPBES_TG_", out$repo_name) & nzchar(out$title) & nzchar(out$page_url),
    ,
    drop = FALSE
  ]

  if (nrow(out) == 0) {
    return(empty_tg_labels())
  }

  order_tg_labels(out)
}

load_tg_labels <- function(fallback_df, directory_url = "https://ipbes-data.github.io/IPBES_TG_Directory/") {
  live <- get_tg_labels_from_site(directory_url = directory_url)
  if (nrow(live) > 0) {
    return(list(data = live, source = "live website"))
  }

  if (nrow(fallback_df) > 0) {
    return(list(data = order_tg_labels(fallback_df), source = "fallback csv"))
  }

  list(data = empty_tg_labels(), source = "none")
}

pick_first_column <- function(df, candidates, fallback = "") {
  hit <- candidates[candidates %in% names(df)]
  if (length(hit) == 0) {
    return(rep(fallback, nrow(df)))
  }

  out <- df[[hit[1]]]
  if (is.null(out)) {
    return(rep(fallback, nrow(df)))
  }

  out
}

sanitize_shiny_apps <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return(empty_shiny_apps())
  }

  out <- data.frame(
    name = pick_first_column(df, c("name", "application_name", "app_name")),
    title = pick_first_column(df, c("title", "display_name", "name", "application_name")),
    url = pick_first_column(df, c("url", "application_url", "app_url")),
    status = pick_first_column(df, c("status", "application_status", "state")),
    stringsAsFactors = FALSE
  )

  out <- trim_char_columns(out)
  out$title <- ifelse(is.na(out$title) | !nzchar(out$title), out$name, out$title)
  out$status <- ifelse(is.na(out$status), "", out$status)

  out <- out[!is.na(out$url) & nzchar(out$url), , drop = FALSE]
  if (nrow(out) == 0) {
    return(empty_shiny_apps())
  }

  out <- unique(out)
  out[order(tolower(out$title), tolower(out$name)), , drop = FALSE]
}

get_shiny_apps_from_api <- function(account_name = Sys.getenv("SHINYAPPS_ACCOUNT", unset = "ipbes-data")) {
  if (!requireNamespace("rsconnect", quietly = TRUE)) {
    return(empty_shiny_apps())
  }

  token <- Sys.getenv("SHINYAPPS_TOKEN", unset = "")
  secret <- Sys.getenv("SHINYAPPS_SECRET", unset = "")
  if (!nzchar(token) || !nzchar(secret)) {
    return(empty_shiny_apps())
  }

  connected <- tryCatch({
    rsconnect::setAccountInfo(
      name = account_name,
      token = token,
      secret = secret,
      server = "shinyapps.io"
    )
    TRUE
  }, error = function(e) FALSE)

  if (!connected) {
    return(empty_shiny_apps())
  }

  apps_raw <- tryCatch(
    rsconnect::applications(account = account_name, server = "shinyapps.io"),
    error = function(e) NULL
  )

  sanitize_shiny_apps(apps_raw)
}

load_shiny_apps <- function(fallback_df, account_name = Sys.getenv("SHINYAPPS_ACCOUNT", unset = "ipbes-data")) {
  live <- get_shiny_apps_from_api(account_name = account_name)
  if (nrow(live) > 0) {
    return(list(data = live, source = "shinyapps api"))
  }

  fallback <- sanitize_shiny_apps(fallback_df)
  if (nrow(fallback) > 0) {
    return(list(data = fallback, source = "fallback csv"))
  }

  list(data = empty_shiny_apps(), source = "none")
}
