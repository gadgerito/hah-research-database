# Hospital at Home Users Group Research Center

An automated, reproducible literature curation system for the Hospital at Home (HaH) care model. Pulls peer-reviewed publications from PubMed monthly, filters for relevance, tags by clinical condition and study type, and serves the results through an interactive R Shiny dashboard.

**Live dashboard:** [link to your deployed app]

---

## What this is

The HaH research literature is fragmented across multiple terminologies ("hospital at home," "hospital in the home," "admission avoidance," "substitutive hospital care") and easily confused with adjacent care models like post-acute home health, skilled nursing, and chronic home care. This repository contains the curation pipeline and dashboard used to maintain a focused, high-quality database of HaH-specific research.

The system is designed around three principles:
- **Reproducibility** — the same query produces the same results, and the methodology is documented in a Standard Operating Procedure
- **Specificity** — a two-stage relevance screen filters out adjacent-but-distinct care models
- **Transparency** — every inclusion and exclusion criterion is explicit; journal influence is shown as a descriptive range (SJR), not a value-laden ranking

---

## What's in this repo

| File | Purpose |
|---|---|
| `app.R` | R Shiny dashboard — the user-facing application |
| `hah_curated_YYYY-MM-DD.csv` | Latest curated literature dataset |
| `manifest.json` | Package dependency manifest for Posit Connect Cloud deployment |
| `README.md` | This file |

The curation pipeline script (`hah_pipeline_v2.R`) lives in a separate location and is not deployed with the dashboard — it runs locally on a monthly schedule to refresh the curated CSV.

---

## Methodology summary

### Search strategy

Articles are retrieved from PubMed using a structured query targeting substitutive acute care delivered in the home. The query includes both formal MeSH headings and title/abstract terms, with explicit exclusion of adjacent care models.

**Included:**
- Hospital at home / hospital-at-home / hospital in the home
- Home hospitalization (US and UK spellings)
- Hospital-level care at home / acute hospital care at home
- Admission avoidance (Cochrane terminology)
- Substitutive hospital care
- HaH and HITH abbreviations

**Excluded:**
- Hospice and palliative care
- Skilled nursing facilities, nursing homes, long-term care
- Post-acute and subacute care
- Rehabilitation at home, early supported discharge
- Chronic home health agency services
- Editorials, letters, news, comments

**Date range:** 2020 to present. **Language:** English. **Population:** Human studies.

### Two-stage relevance filter

Records returned by the PubMed query pass through a programmatic title/abstract screen that requires the presence of at least one HaH-specific signal phrase. This removes articles where an HaH MeSH term was indexed but the article itself is only tangentially relevant.

### Tagging

Each surviving article is auto-tagged using regular-expression matching across title, abstract, and MeSH terms. Tags fall into two categories:

**Clinical conditions:** heart failure, COPD, cellulitis/SSTI, pneumonia, DVT/PE/VTE, UTI/pyelonephritis, sepsis/bacteremia, diabetes/DKA, oncology, COVID-19, pediatric, geriatric, psychiatric, surgical/postoperative

**Study types & topics:** randomized controlled trial, systematic review/meta-analysis, cohort study, qualitative, mixed methods, cost/economic, safety, implementation, patient/caregiver experience, equity, technology/RPM

### Journal stratification

Articles are stratified by the SCImago Journal Rank (SJR) of their source journal:

- **SJR 5.0+** — High-influence journals (e.g., NEJM, JAMA, Lancet)
- **SJR 2.0–4.99** — Major specialty and general medicine journals
- **SJR 0.5–1.99** — Specialty and subspecialty journals
- **SJR <0.5** — Smaller-circulation journals
- **Not indexed** — Journal not present in the SCImago database

SJR is a journal-level metric, not an article-level quality measure. Important HaH work appears across the full range.

---

## Running the dashboard locally

If you want to run the dashboard on your own computer:

```r
# Install required packages (one time)
install.packages(c("shiny", "shinydashboard", "DT", "dplyr", "readr"))

# Set working directory to the repo location
setwd("path/to/this/repo")

# Launch
shiny::runApp("app.R")
```

The dashboard will open in your default web browser.

---

## Deployment

The dashboard is deployed on **Posit Connect Cloud**, which provides free hosting for public-data Shiny applications. Since all source data comes from PubMed (a public database), public hosting is appropriate.

Deployment is automatic: when a new curated CSV is pushed to this repo, Posit Connect Cloud rebuilds the app within a few minutes.

---

## Refresh cadence

The curated database is refreshed monthly. Refresh involves:

1. Running the curation pipeline locally against the current state of PubMed
2. Replacing the prior month's curated CSV with the new one in this repo
3. Posit Connect Cloud rebuilds the live app automatically

Major methodology updates (search term changes, new tag categories) are reviewed every six months.

---

## Documentation

The complete search strategy, inclusion/exclusion logic, tagging rules, and review cadence are documented in **SOP HAH-RC-001**, available from the Hospital at Home Users Group Research Center.

---

## Contact

For questions, suggestions for additional search terms or tags, or to report a relevant article that appears to be missing from the database, contact the HaH Users Group Research Center.

---

## License & data attribution

This repository contains application code released for reproducibility and reuse.

Source literature metadata is retrieved from **PubMed**, a service of the U.S. National Library of Medicine. Journal influence metrics are derived from **SCImago Journal & Country Rank** (scimagojr.com). Both sources are publicly available; please consult their respective terms of use for reuse of underlying data.
