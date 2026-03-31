# IPBES-Data.github.io

This repo contains the source code for the website of the IPBES Data & Knowledge Technical Support Unit.

The website is hosted on GitHub Pages. The website is available at [https://ipbes-data.github.io/](https://ipbes-data.github.io/).

## Project Metadata

- Version: derived from latest `NEWS.md` date as `vYYYY.MM.DD`
- Change log: see `NEWS.md`
- Development notes: see `DEVELOPMENT.md`

## Build

- Render locally with `quarto render`
- Website pages are generated into `_site/`
- Validate heuristic parser logic with `Rscript scripts/validate_property_detection.R`

## Property Detection

Repository publication properties are detected from repository `README.md` badges:

- DOI: Zenodo badge + DOI target link
- Posit Connect Cloud: Connect Cloud "Open App" shield badge + target link
- Cache records also include source fields (`doi_source`, `pcc_source`) for traceability.

Documentation page: `Propertydetection.qmd` (included under About in the website navbar).

## Automation

- Deploy workflow: `.github/workflows/deploy-pages.yml` (every 6 hours)
- QA workflow: `.github/workflows/qa.yml` (pull requests + manual run)
