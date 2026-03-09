# NEWS

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
- Added a `VERSION` file to track the website source version.
- Current version: `0.2.0`.
- Added automatic version sync from `NEWS.md` to `VERSION` during render.
- Added website footer version display sourced from `NEWS.md` (shown as `Website version: 0.2.0`).

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
