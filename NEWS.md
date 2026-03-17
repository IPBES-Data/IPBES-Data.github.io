# NEWS

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
- Kept `News` and `Contributors` available in the footer links.
- Ensured `news.qmd` and `contributors.qmd` remain in the Quarto render list so linked pages are generated.

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
- Added dedicated pages for `NEWS` and `Contributors` and linked them in the website navigation.

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
