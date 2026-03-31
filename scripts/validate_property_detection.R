#!/usr/bin/env Rscript

source("scripts/site_data_utils.R")

assert_equal <- function(actual, expected, label) {
  if (!identical(actual, expected)) {
    stop(sprintf("%s failed. Expected '%s' but got '%s'.", label, expected, actual), call. = FALSE)
  }
}

# DOI badge positive case
readme_doi <- paste(
  "[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10218647.svg)](https://doi.org/10.5281/zenodo.10218647)",
  "Some text",
  sep = "\n"
)
doi <- extract_doi_from_zenodo_badge_readme(readme_doi)
assert_equal(doi, "10.5281/zenodo.10218647", "DOI extraction")

# DOI negative case
readme_no_doi <- "[![badge](https://img.shields.io/badge/foo-bar-blue)](https://example.com)"
doi_none <- extract_doi_from_zenodo_badge_readme(readme_no_doi)
assert_equal(doi_none, "", "DOI no-hit")

# PCC badge positive case
readme_pcc <- paste(
  "[![Open App](https://img.shields.io/badge/Connect%20Cloud-Open%20App-blue)](https://example.share.connect.posit.cloud/)",
  "Other text",
  sep = "\n"
)
pcc <- extract_connect_cloud_url_from_readme(readme_pcc)
assert_equal(pcc, "https://example.share.connect.posit.cloud/", "PCC extraction")

# PCC negative case
readme_no_pcc <- "[![Open](https://img.shields.io/badge/GitHub-Open-black)](https://github.com)"
pcc_none <- extract_connect_cloud_url_from_readme(readme_no_pcc)
assert_equal(pcc_none, "", "PCC no-hit")

cat("Property detection validation passed.\n")
