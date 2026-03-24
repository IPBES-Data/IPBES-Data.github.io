# DOI and PCC Detection Algorithm

This document describes how DOI and Posit Connect Cloud (PCC) publication links are identified for repositories in this site.

## Purpose

Create repository-level publication signals for public repositories in `IPBES-Data`, without changing repository contents:

- DOI (from Zenodo DOI badge in README)
- PCC app URL (from Connect Cloud badge in README)

## Inputs

- Repository list from GitHub API (including `repo_name`, `repo_id`)
- Optional caches:
  - `input/cache/repo_doi_map.csv`
  - `input/cache/repo_pcc_map.csv`

## DOI Heuristic

Per repository:

1. Read `README.md` from GitHub contents API.
2. Parse markdown badge links of form:
   - `[![...](IMAGE_URL)](TARGET_URL)`
3. Keep only badge links where:
   - `IMAGE_URL` contains `zenodo.org/badge`
   - `TARGET_URL` contains `doi.org/`
4. Extract DOI from `TARGET_URL`, normalize it, and store:
   - `doi`
   - `doi_url = https://doi.org/<doi>`

If no matching Zenodo badge DOI is found, DOI is empty.

## PCC Heuristic

Per repository:

1. Read `README.md` from GitHub contents API.
2. Parse markdown badge links of form:
   - `[![...](IMAGE_URL)](TARGET_URL)`
3. Keep only badge links where `IMAGE_URL` is a Connect Cloud badge from `img.shields.io` and includes:
   - `Connect Cloud`
   - `Open App`
4. Use `TARGET_URL` as `pcc_url`.

## Cache Logic

Both DOI and PCC maps use the same policy:

- Row with value found: cache valid for `24h`
- Row without value: cache valid for `1h`

This reduces API load while allowing fast recovery from false negatives.

## Outputs Used by Site

- Hero pills/counts (`Have DOIs`, `Published on PCC`)
- Repository explorer table (`Published` column icons and links)
- Scope filters (`Have DOIs`, `Published on PCC`)

## Implementation Reference

Implemented in:

- `scripts/site_data_utils.R`
  - `extract_markdown_badge_links()`
  - `extract_doi_from_zenodo_badge_readme()`
  - `extract_connect_cloud_url_from_readme()`
  - `get_repo_doi_map()`
  - `get_repo_pcc_map()`
