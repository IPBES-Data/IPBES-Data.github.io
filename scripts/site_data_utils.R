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

  keep <- Reduce(
    f = `&`,
    x = lapply(required_cols, function(col) !is.na(df[[col]]) & nzchar(df[[col]]))
  )

  df[keep, , drop = FALSE]
}

load_site_inputs <- function(input_dir = "input") {
  assessments <- read_trimmed_csv(file.path(input_dir, "assessments.csv"))
  dir_map <- read_trimmed_csv(file.path(input_dir, "assessment_directory_map.csv"))
  tg_labels_fallback <- read_trimmed_csv(file.path(input_dir, "technical_guideline_labels.csv"))

  dir_map <- filter_required_nonempty(dir_map, c("abbreviation", "directory_path"))
  tg_labels_fallback <- filter_required_nonempty(tg_labels_fallback, c("repo_name", "title", "page_url"))

  list(
    assessments = assessments,
    dir_map = dir_map,
    tg_labels_fallback = tg_labels_fallback
  )
}

empty_repos <- function(include_description = FALSE) {
  if (isTRUE(include_description)) {
    return(data.frame(
      repo_name = character(0),
      description = character(0),
      url = character(0),
      archived = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(repo_name = character(0), repo_url = character(0), stringsAsFactors = FALSE)
}

empty_tg_labels <- function() {
  data.frame(repo_name = character(0), title = character(0), page_url = character(0), stringsAsFactors = FALSE)
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
    !is.na(repo_df$repoName) & !is.na(repo_df$url) & nzchar(repo_df$repoName) & nzchar(repo_df$url),
    ,
    drop = FALSE
  ]

  if (isTRUE(include_description)) {
    out <- data.frame(
      repo_name = repo_df$repoName,
      description = ifelse(is.na(repo_df$description), "", repo_df$description),
      url = repo_df$url,
      archived = rep(NA, nrow(repo_df)),
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
    gh::gh(
      "GET /orgs/:org/repos",
      org = org,
      type = "public",
      per_page = 100,
      .limit = Inf
    ),
    error = function(e) NULL
  )
}

is_public_repo <- function(repo) {
  isFALSE(repo$private) || is.null(repo$private)
}

get_org_repos_for_index <- function(org = "IPBES-Data", cache_path = "tree.rds") {
  repos_raw <- get_org_repos_raw(org = org)

  if (!is.null(repos_raw) && length(repos_raw) > 0) {
    repos_raw <- Filter(is_public_repo, repos_raw)
  }

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
    repos_raw <- Filter(is_public_repo, repos_raw)
  }

  if (!is.null(repos_raw) && length(repos_raw) > 0) {
    repos_live <- data.frame(
      repo_name = vapply(repos_raw, function(x) x$name, character(1)),
      description = vapply(repos_raw, function(x) ifelse(is.null(x$description), "", x$description), character(1)),
      url = vapply(repos_raw, function(x) x$html_url, character(1)),
      archived = vapply(repos_raw, function(x) isTRUE(x$archived), logical(1)),
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

get_assessment_abbreviations <- function(assessments_df) {
  if (is.null(assessments_df) || nrow(assessments_df) == 0 || !('abbreviation' %in% names(assessments_df))) {
    return(character(0))
  }

  unique(toupper(trimws(assessments_df$abbreviation)))
}

extract_ipbes_repo_token <- function(repo_name) {
  if (is.na(repo_name) || !nzchar(repo_name)) {
    return("")
  }

  match <- regexec("^IPBES_([A-Za-z0-9]+)(?:_|$)", repo_name, perl = TRUE)
  parsed <- regmatches(repo_name, match)[[1]]
  if (length(parsed) < 2) {
    return("")
  }

  toupper(parsed[2])
}

summarize_assessment_repositories <- function(repos_df, assessments_df, repo_name_col = "repo_name") {
  if (is.null(repos_df) || nrow(repos_df) == 0 || !(repo_name_col %in% names(repos_df))) {
    return(list(
      n_assessments = 0L,
      n_repositories = 0L,
      data = repos_df[0, , drop = FALSE]
    ))
  }

  assessment_abbrevs <- get_assessment_abbreviations(assessments_df)
  if (length(assessment_abbrevs) == 0) {
    return(list(
      n_assessments = 0L,
      n_repositories = 0L,
      data = repos_df[0, , drop = FALSE]
    ))
  }

  tokens <- vapply(repos_df[[repo_name_col]], extract_ipbes_repo_token, character(1))
  is_assessment_repo <- tokens %in% assessment_abbrevs

  matched <- repos_df[is_assessment_repo, , drop = FALSE]
  matched$assessment_abbreviation <- tokens[is_assessment_repo]

  list(
    n_assessments = as.integer(length(unique(matched$assessment_abbreviation))),
    n_repositories = as.integer(nrow(matched)),
    data = matched
  )
}
