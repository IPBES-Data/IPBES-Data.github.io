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
      repo_id = integer(0),
      description = character(0),
      url = character(0),
      visibility = character(0),
      archived = logical(0),
      license_spdx = character(0),
      license_url = character(0),
      has_pages = logical(0),
      homepage = character(0),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    repo_name = character(0),
    repo_id = integer(0),
    repo_url = character(0),
    visibility = character(0),
    has_pages = logical(0),
    homepage = character(0),
    stringsAsFactors = FALSE
  )
}

empty_tg_labels <- function() {
  data.frame(repo_name = character(0), title = character(0), page_url = character(0), stringsAsFactors = FALSE)
}

extract_markdown_badge_links <- function(text) {
  if (is.null(text) || is.na(text) || !nzchar(text)) {
    return(data.frame(image_url = character(0), target_url = character(0), stringsAsFactors = FALSE))
  }

  pattern <- "\\[!\\[[^\\]]*\\]\\(([^)]+)\\)\\]\\s*\\(([^)]+)\\)"
  m <- gregexec(pattern, text, perl = TRUE)
  hits <- regmatches(text, m)[[1]]
  if (length(hits) == 0) {
    return(data.frame(image_url = character(0), target_url = character(0), stringsAsFactors = FALSE))
  }

  image_urls <- vapply(hits, function(x) if (length(x) >= 2) x[2] else "", character(1))
  target_urls <- vapply(hits, function(x) if (length(x) >= 3) x[3] else "", character(1))

  out <- data.frame(
    image_url = trimws(image_urls),
    target_url = trimws(target_urls),
    stringsAsFactors = FALSE
  )
  out[nzchar(out$image_url) & nzchar(out$target_url), , drop = FALSE]
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
      repo_id = rep(NA_integer_, nrow(repo_df)),
      description = ifelse(is.na(repo_df$description), "", repo_df$description),
      url = repo_df$url,
      visibility = rep("public", nrow(repo_df)),
      archived = rep(NA, nrow(repo_df)),
      license_spdx = rep("", nrow(repo_df)),
      license_url = rep("", nrow(repo_df)),
      has_pages = rep(NA, nrow(repo_df)),
      homepage = rep("", nrow(repo_df)),
      stringsAsFactors = FALSE
    )
  } else {
    out <- data.frame(
      repo_name = repo_df$repoName,
      repo_id = rep(NA_integer_, nrow(repo_df)),
      repo_url = repo_df$url,
      visibility = rep("public", nrow(repo_df)),
      has_pages = rep(NA, nrow(repo_df)),
      homepage = rep("", nrow(repo_df)),
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
      repo_id = vapply(repos_raw, function(x) as.integer(x$id), integer(1)),
      repo_url = vapply(repos_raw, function(x) x$html_url, character(1)),
      visibility = vapply(repos_raw, function(x) ifelse(is.null(x$visibility), "public", x$visibility), character(1)),
      has_pages = vapply(repos_raw, function(x) isTRUE(x$has_pages), logical(1)),
      homepage = vapply(repos_raw, function(x) ifelse(is.null(x$homepage), "", x$homepage), character(1)),
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
      repo_id = vapply(repos_raw, function(x) as.integer(x$id), integer(1)),
      description = vapply(repos_raw, function(x) ifelse(is.null(x$description), "", x$description), character(1)),
      url = vapply(repos_raw, function(x) x$html_url, character(1)),
      visibility = vapply(repos_raw, function(x) ifelse(is.null(x$visibility), "public", x$visibility), character(1)),
      archived = vapply(repos_raw, function(x) isTRUE(x$archived), logical(1)),
      license_spdx = vapply(repos_raw, function(x) {
        if (is.null(x$license) || is.null(x$license$spdx_id) || is.na(x$license$spdx_id)) "" else x$license$spdx_id
      }, character(1)),
      license_url = vapply(repos_raw, function(x) {
        if (is.null(x$license) || is.null(x$license$spdx_id) || is.na(x$license$spdx_id) || !nzchar(x$license$spdx_id)) "" else paste0("https://spdx.org/licenses/", x$license$spdx_id, ".html")
      }, character(1)),
      has_pages = vapply(repos_raw, function(x) isTRUE(x$has_pages), logical(1)),
      homepage = vapply(repos_raw, function(x) ifelse(is.null(x$homepage), "", x$homepage), character(1)),
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

infer_github_pages_url <- function(repo_name, homepage = "", org = "IPBES-Data") {
  if (!is.na(homepage) && nzchar(trimws(homepage))) {
    return(trimws(homepage))
  }

  paste0("https://", tolower(org), ".github.io/", repo_name, "/")
}

get_github_pages_repositories <- function(repos_df, org = "IPBES-Data") {
  if (is.null(repos_df) || nrow(repos_df) == 0 || !("repo_name" %in% names(repos_df))) {
    return(data.frame(
      repo_name = character(0),
      pages_url = character(0),
      description = character(0),
      archived = character(0),
      stringsAsFactors = FALSE
    ))
  }

  if (!("has_pages" %in% names(repos_df))) {
    return(data.frame(
      repo_name = character(0),
      pages_url = character(0),
      description = character(0),
      archived = character(0),
      stringsAsFactors = FALSE
    ))
  }

  has_pages <- !is.na(repos_df$has_pages) & repos_df$has_pages
  pages <- repos_df[has_pages, , drop = FALSE]
  if (nrow(pages) == 0) {
    return(data.frame(
      repo_name = character(0),
      pages_url = character(0),
      description = character(0),
      archived = character(0),
      stringsAsFactors = FALSE
    ))
  }

  homepage <- if ("homepage" %in% names(pages)) pages$homepage else rep("", nrow(pages))
  description <- if ("description" %in% names(pages)) pages$description else rep("", nrow(pages))
  archived <- if ("archived" %in% names(pages)) pages$archived else rep(NA, nrow(pages))

  out <- data.frame(
    repo_name = pages$repo_name,
    pages_url = vapply(
      seq_len(nrow(pages)),
      function(i) infer_github_pages_url(pages$repo_name[i], homepage[i], org = org),
      character(1)
    ),
    description = ifelse(is.na(description), "", description),
    archived = ifelse(is.na(archived), "Unknown", ifelse(archived, "Yes", "No")),
    stringsAsFactors = FALSE
  )

  out[order(tolower(out$repo_name)), , drop = FALSE]
}

empty_repo_doi_map <- function() {
  data.frame(
    repo_name = character(0),
    repo_id = integer(0),
    doi = character(0),
    doi_url = character(0),
    checked_at = character(0),
    stringsAsFactors = FALSE
  )
}

extract_doi_from_text <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) {
    return("")
  }

  m <- regexpr("10\\.[0-9]{4,9}/[-._;()/:A-Za-z0-9]+", x, perl = TRUE)
  if (m[1] == -1) {
    return("")
  }

  doi <- regmatches(x, m)[1]
  doi <- sub("\\.svg$", "", doi, ignore.case = TRUE)
  doi <- sub("[[:punct:]]+$", "", doi)
  doi
}

extract_doi_from_zenodo_badge_readme <- function(readme_text) {
  links <- extract_markdown_badge_links(readme_text)
  if (nrow(links) == 0) {
    return("")
  }

  for (i in seq_len(nrow(links))) {
    image_url <- tolower(links$image_url[i])
    target_url <- links$target_url[i]
    if (!grepl("zenodo\\.org/badge", image_url, perl = TRUE)) {
      next
    }
    if (!grepl("doi\\.org/", tolower(target_url), perl = TRUE)) {
      next
    }
    doi <- normalize_doi(target_url)
    if (!nzchar(doi)) {
      doi <- normalize_doi(extract_doi_from_text(target_url))
    }
    if (!nzchar(doi)) {
      doi <- normalize_doi(extract_doi_from_text(links$image_url[i]))
    }
    if (nzchar(doi)) {
      return(doi)
    }
  }

  ""
}

is_connect_cloud_badge <- function(image_url) {
  if (is.null(image_url) || is.na(image_url) || !nzchar(image_url)) {
    return(FALSE)
  }
  u <- tolower(image_url)
  u <- gsub("%20", " ", u, fixed = TRUE)
  u <- gsub("\\+", " ", u)
  grepl("img\\.shields\\.io/badge/", u, perl = TRUE) &&
    grepl("connect[ _-]*cloud", u, perl = TRUE) &&
    grepl("open[ _-]*app", u, perl = TRUE)
}

extract_connect_cloud_url_from_readme <- function(readme_text) {
  links <- extract_markdown_badge_links(readme_text)
  if (nrow(links) == 0) {
    return("")
  }

  for (i in seq_len(nrow(links))) {
    if (!is_connect_cloud_badge(links$image_url[i])) {
      next
    }
    target_url <- trimws(links$target_url[i])
    if (!grepl("^https?://", target_url, ignore.case = TRUE)) {
      next
    }
    return(target_url)
  }

  ""
}

normalize_doi <- function(doi) {
  if (is.null(doi) || is.na(doi) || !nzchar(doi)) {
    return("")
  }
  out <- trimws(doi)
  out <- sub("^https?://doi\\.org/", "", out, ignore.case = TRUE)
  out <- sub("\\.svg$", "", out, ignore.case = TRUE)
  out <- sub("[[:punct:]]+$", "", out)
  if (!grepl("^10\\.[0-9]{4,9}/", out, perl = TRUE)) {
    return("")
  }
  out
}

decode_base64_text <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) {
    return("")
  }

  x <- gsub("\\n", "", x)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return("")
  }
  raw <- tryCatch(jsonlite::base64_dec(x), error = function(e) raw())
  if (length(raw) == 0) {
    return("")
  }
  out <- tryCatch(rawToChar(raw), error = function(e) "")
  ifelse(is.na(out), "", out)
}

fetch_github_file_text <- function(repo_name, path, org = "IPBES-Data") {
  if (is.na(repo_name) || !nzchar(repo_name) || !requireNamespace("gh", quietly = TRUE)) {
    return("")
  }

  res <- tryCatch(
    gh::gh(
      "GET /repos/:owner/:repo/contents/:path",
      owner = org,
      repo = repo_name,
      path = path
    ),
    error = function(e) NULL
  )
  if (is.null(res)) {
    return("")
  }

  if (!is.null(res$content)) {
    return(decode_base64_text(res$content))
  }

  ""
}

fetch_repo_doi_from_github <- function(repo_name, org = "IPBES-Data") {
  readme <- fetch_github_file_text(repo_name = repo_name, path = "README.md", org = org)
  doi <- extract_doi_from_zenodo_badge_readme(readme)
  if (nzchar(doi)) {
    return(doi)
  }

  ""
}

fetch_repo_pcc_from_github <- function(repo_name, org = "IPBES-Data") {
  readme <- fetch_github_file_text(repo_name = repo_name, path = "README.md", org = org)
  extract_connect_cloud_url_from_readme(readme)
}

get_repo_doi_map <- function(repos_df, cache_path = "input/cache/repo_doi_map.csv", stale_hours = 24) {
  if (is.null(repos_df) || nrow(repos_df) == 0 || !("repo_name" %in% names(repos_df)) || !("repo_id" %in% names(repos_df))) {
    return(empty_repo_doi_map())
  }

  rows <- repos_df[!is.na(repos_df$repo_name) & nzchar(repos_df$repo_name), c("repo_name", "repo_id"), drop = FALSE]
  if (nrow(rows) == 0) {
    return(empty_repo_doi_map())
  }
  rows <- unique(rows)

  cache <- empty_repo_doi_map()
  if (file.exists(cache_path)) {
    cache <- tryCatch(read_trimmed_csv(cache_path), error = function(e) empty_repo_doi_map())
    needed <- c("repo_name", "repo_id", "doi", "doi_url", "checked_at")
    for (col in needed) {
      if (!(col %in% names(cache))) {
        cache[[col]] <- ""
      }
    }
    cache <- cache[, needed, drop = FALSE]
    cache$repo_id <- suppressWarnings(as.integer(cache$repo_id))
    cache$doi <- vapply(cache$doi, normalize_doi, character(1))
    cache$doi_url <- ifelse(nzchar(cache$doi), paste0("https://doi.org/", cache$doi), "")
    cache$checked_at <- ifelse(is.na(cache$checked_at), "", cache$checked_at)
  }

  cache_key <- paste(cache$repo_name, cache$repo_id)
  now_utc <- as.POSIXct(Sys.time(), tz = "UTC")
  out <- vector("list", nrow(rows))

  for (i in seq_len(nrow(rows))) {
    repo_name <- rows$repo_name[i]
    repo_id <- suppressWarnings(as.integer(rows$repo_id[i]))
    key <- paste(repo_name, repo_id)
    cached_idx <- which(cache_key == key)

    use_cached <- FALSE
    if (length(cached_idx) > 0) {
      checked <- suppressWarnings(as.POSIXct(cache$checked_at[cached_idx[1]], tz = "UTC"))
      if (!is.na(checked)) {
        age_hours <- as.numeric(difftime(now_utc, checked, units = "hours"))
        cached_has_doi <- !is.na(cache$doi[cached_idx[1]]) && nzchar(cache$doi[cached_idx[1]])
        ttl <- if (cached_has_doi) stale_hours else 1
        use_cached <- is.finite(age_hours) && age_hours <= ttl
      }
    }

    if (use_cached) {
      row <- cache[cached_idx[1], c("repo_name", "repo_id", "doi", "doi_url", "checked_at"), drop = FALSE]
      row$doi <- normalize_doi(row$doi[1])
      row$doi_url <- ifelse(nzchar(row$doi[1]), paste0("https://doi.org/", row$doi[1]), "")
      out[[i]] <- row
      next
    }

    doi <- fetch_repo_doi_from_github(repo_name = repo_name, org = "IPBES-Data")
    doi <- normalize_doi(doi)
    doi_url <- if (nzchar(doi)) paste0("https://doi.org/", doi) else ""

    out[[i]] <- data.frame(
      repo_name = repo_name,
      repo_id = repo_id,
      doi = doi,
      doi_url = doi_url,
      checked_at = format(now_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      stringsAsFactors = FALSE
    )
  }

  doi_map <- do.call(rbind, out)
  doi_map <- unique(doi_map)

  cache_dir <- dirname(cache_path)
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  tryCatch(
    write.csv(doi_map, cache_path, row.names = FALSE, quote = TRUE),
    error = function(e) NULL
  )

  doi_map
}

empty_repo_pcc_map <- function() {
  data.frame(
    repo_name = character(0),
    repo_id = integer(0),
    pcc_url = character(0),
    checked_at = character(0),
    stringsAsFactors = FALSE
  )
}

get_repo_pcc_map <- function(repos_df, cache_path = "input/cache/repo_pcc_map.csv", stale_hours = 24) {
  if (is.null(repos_df) || nrow(repos_df) == 0 || !("repo_name" %in% names(repos_df)) || !("repo_id" %in% names(repos_df))) {
    return(data.frame(repo_name = character(0), pcc_url = character(0), stringsAsFactors = FALSE))
  }

  rows <- repos_df[!is.na(repos_df$repo_name) & nzchar(repos_df$repo_name), c("repo_name", "repo_id"), drop = FALSE]
  if (nrow(rows) == 0) {
    return(data.frame(repo_name = character(0), pcc_url = character(0), stringsAsFactors = FALSE))
  }
  rows <- unique(rows)

  cache <- empty_repo_pcc_map()
  if (file.exists(cache_path)) {
    cache <- tryCatch(read_trimmed_csv(cache_path), error = function(e) empty_repo_pcc_map())
    needed <- c("repo_name", "repo_id", "pcc_url", "checked_at")
    for (col in needed) {
      if (!(col %in% names(cache))) {
        cache[[col]] <- ""
      }
    }
    cache <- cache[, needed, drop = FALSE]
    cache$repo_id <- suppressWarnings(as.integer(cache$repo_id))
    cache$pcc_url <- ifelse(is.na(cache$pcc_url), "", trimws(cache$pcc_url))
    cache$checked_at <- ifelse(is.na(cache$checked_at), "", cache$checked_at)
  }

  cache_key <- paste(cache$repo_name, cache$repo_id)
  now_utc <- as.POSIXct(Sys.time(), tz = "UTC")
  out <- vector("list", nrow(rows))

  for (i in seq_len(nrow(rows))) {
    repo_name <- rows$repo_name[i]
    repo_id <- suppressWarnings(as.integer(rows$repo_id[i]))
    key <- paste(repo_name, repo_id)
    cached_idx <- which(cache_key == key)

    use_cached <- FALSE
    if (length(cached_idx) > 0) {
      checked <- suppressWarnings(as.POSIXct(cache$checked_at[cached_idx[1]], tz = "UTC"))
      if (!is.na(checked)) {
        age_hours <- as.numeric(difftime(now_utc, checked, units = "hours"))
        cached_has_pcc <- !is.na(cache$pcc_url[cached_idx[1]]) && nzchar(cache$pcc_url[cached_idx[1]])
        ttl <- if (cached_has_pcc) stale_hours else 1
        use_cached <- is.finite(age_hours) && age_hours <= ttl
      }
    }

    pcc_url <- ""
    if (use_cached) {
      pcc_url <- cache$pcc_url[cached_idx[1]]
    } else {
      pcc_url <- fetch_repo_pcc_from_github(repo_name = repo_name, org = "IPBES-Data")
    }

    out[[i]] <- data.frame(
      repo_name = repo_name,
      repo_id = repo_id,
      pcc_url = ifelse(is.na(pcc_url), "", trimws(pcc_url)),
      checked_at = format(now_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      stringsAsFactors = FALSE
    )
  }

  pcc_map <- do.call(rbind, out)
  pcc_map <- unique(pcc_map)

  cache_dir <- dirname(cache_path)
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  tryCatch(
    write.csv(pcc_map, cache_path, row.names = FALSE, quote = TRUE),
    error = function(e) NULL
  )

  pcc_map[pcc_map$pcc_url != "", c("repo_name", "pcc_url"), drop = FALSE]
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
