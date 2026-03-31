# NEWS

## 2026-03-31

### Navigation and Naming
- Renamed the contributors page and source files to development naming:
  - `contributors.qmd` -> `development.qmd`
  - `CONTRIBUTORS.md` -> `DEVELOPMENT.md`
- Updated footer navigation label and links to `Development`.

### Landing Page
- Removed the top-right `Assessments` metric pill from the landing page hero metrics.
- Included latest manual content updates in the About page source.

### Repository Explorer
- Re-enabled column filters for `License`, `Published`, and `Properties`.
- Added searchable hidden text tokens behind icons so those three filters work with terms such as `MIT`, `DOI`, `GHP`, `PCC`, `Archived`, `Public`, and `Private`.
- Updated visibility icon tooltip text to show `Public` or `Private` (instead of generic `Visibility`).
- Added refreshed timestamp display in the repository source line:
  - `Repository source: <source> (refreshed: YYYY-MM-DD HH:MM UTC)`.

### Data Refresh
- Refreshed repository DOI/PCC cache snapshots after parser and rendering updates.

## 2026-03-24

### Automation
- Changed scheduled deployment cadence from every 3 hours to every 6 hours (`0 */6 * * *` UTC).
- Added QA workflow `.github/workflows/qa.yml`:
  - runs on pull requests,
  - validates README property heuristics,
  - renders the site,
  - checks internal links in `_site/**/*.html` (offline mode).

### Property Detection Hardening
- Added source tracking fields in cache outputs:
  - `doi_source` in `input/cache/repo_doi_map.csv`,
  - `pcc_source` in `input/cache/repo_pcc_map.csv`.
- Added parser validation script `scripts/validate_property_detection.R` with positive/negative fixture checks for DOI and PCC badges.
- Expanded property detection documentation in `Propertydetection.qmd` with source fields, freshness behavior, and validation reference.

### Repository Cleanup
- Removed obsolete DOI algorithm markdown file and replaced it with a rendered website page: `Propertydetection.qmd`.
- Added `Propertydetection.qmd` to the website render pipeline and About navigation menu.
- Removed unused helper code from `scripts/site_data_utils.R`.
- Removed the repository-page "On this page" TOC panel by disabling page TOC for `repos.qmd`.

### Property Detection
- Finalized README-based heuristics for repository property discovery:
  - DOI detection from Zenodo DOI badge links in `README.md`.
  - Posit Connect Cloud detection from Connect Cloud "Open App" shield badge links in `README.md`.
- Removed dependency on `input/connect_cloud_apps.csv` from the live site data pipeline.

### Documentation
- Updated `README.md` with build and property-detection notes aligned with current implementation.

## 2026-03-17

### Versioning
- Switched from numeric versioning to date-based versioning derived from NEWS headings.
- Version format is now `vYYYY.MM.DD`.
- `VERSION` file removed as redundant.
- Footer version now resolves directly from the latest `## YYYY-MM-DD` heading in `NEWS.md`.

### Repository Listings
- Reworked repository listings to use sortable and filterable `DT` tables for:
  - assessment-related repositories,
  - technical guidelines,
  - other repositories.
- Added an `Archived` column to all repository listing tables (`Yes`/`No`/`Unknown`).
- Updated Technical Guidelines table columns to `Name`, `Repository`, `Description`, and `Archived`.
- Removed row-number columns from repository tables.

### Landing Page Metrics
- Updated hero metrics to report:
  - number of assessments,
  - number of assessment-related repositories,
  - number of technical guidelines,
  - number of other repositories.
- Added the "Other repositories" metric card below the Technical Guidelines metric set.

### Data and Deployment Refresh
- Updated scheduled GitHub Pages refresh from daily to every 3 hours (`0 */3 * * *` UTC).
- Added footer timestamp for last data/render update (`Data fetched: YYYY-MM-DD HH:MM UTC`).
- Continued deployment target to the `gh-pages` branch via GitHub Actions.

### Navigation and Footer
- Kept `News` and `Development` available in the footer links.
- Ensured `news.qmd` and `development.qmd` remain in the Quarto render list so linked pages are generated.

### Simplification
- Removed obsolete home content files no longer used by the current hero-only landing layout.
- Cleaned old landing-layout CSS selectors that were no longer referenced.
- Simplified script utilities and removed redundant sync script logic.
- Removed obsolete Shiny Apps discovery remnants from scripts, workflow settings, and input fallback data.

## 2026-03-09

### Shiny Apps Integration
- Added dynamic Shiny app discovery for account `ipbes-data` using `rsconnect::applications()`.
- Added API credentials support via environment variables:
  - `SHINYAPPS_ACCOUNT` (default: `ipbes-data`)
  - `SHINYAPPS_TOKEN`
  - `SHINYAPPS_SECRET`
- Added fallback data source `input/shiny_apps_fallback.csv` for builds without API credentials.
- Added Shiny Apps section to the landing page with:
  - dynamic app cards,
  - app status labels,
  - search/filter box and result counter.
- Added Shiny Apps section to the repository page with dynamic table output.

### Automation and Build
- Updated deploy workflow to install `rsconnect`.
- Updated render step to pass ShinyApps credentials from GitHub Secrets.
- Confirmed scheduled publishing remains daily at `00:00` UTC to `gh-pages`.

### UI and Robustness
- Separated Technical Guideline and Shiny App card classes to keep filters independent.
- Hardened app field mapping to tolerate column name differences returned by `rsconnect`.

### Versioning
- Added website footer version display sourced from `NEWS.md`.

### Simplification
- Refactored shared site data logic into reusable scripts to reduce duplicated code in page source files.
- Refactored shared version-parsing logic for render scripts.
- Simplified CSS selector duplication with no visual or functional change.

## 2026-03-06

### Website and Navigation
- Reworked the landing page with structured sections, responsive layout, and improved styling.
- Added data-driven content blocks for assessments and technical guidelines.
- Added dedicated pages for `NEWS` and `Development` and linked them in the website navigation.

### Assessment Directories
- Switched assessment links to published GitHub Pages under `IPBES_Assessment_Directories`.
- Added explicit assessment-directory mapping via `input/assessment_directory_map.csv`.
- Updated Transformative Change abbreviation from `TfC` to `TCA`.
- Missing directory mappings now show "No published directory" with no link.

### Technical Guidelines
- Switched Technical Guideline links to published GitHub Pages.
- Loaded guideline titles from the published TG Directory page (with CSV fallback).
- Sorted guidelines by part number (`Part 1`, `Part 2`, ..., `Part 12A/B/C`) and excluded `TEMPLATE`.
- Added a search box for Technical Guidelines on the landing page.

### Publishing and Automation
- Changed Quarto output from `docs/` to `_site/`.
- Added scheduled GitHub Actions deployment workflow to `gh-pages` branch (daily at `00:00` UTC).
- Added `/docs/` and `/_site/` to `.gitignore`.
- Removed `docs/` from git tracking while keeping it in the working copy.
