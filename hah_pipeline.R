# Hospital at Home Research Curation Pipeline (v2.4)
# Tightened query - substitutive acute care only
# v2.4: parses PubMed XML directly with xml2 (no easyPubMed dependency)

library(rentrez)
library(xml2)
library(dplyr)
library(stringr)
library(readr)

# Stop on any error
options(error = function() {
  message("\n*** SCRIPT HALTED ON ERROR ***")
})

# Session reset
setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)
setSessionTimeLimit(cpu = Inf, elapsed = Inf)
options(timeout = 3600)

set_entrez_key("8c74a596c604330a9ba915db1ba499a91b08")
setwd("C:/Users/schilg03/Desktop/research center")

# Search query (2020-present)
hah_query <- '(
    "Home Care Services, Hospital-Based"[MeSH Terms]
    OR "hospital at home"[Title/Abstract]
    OR "hospital-at-home"[Title/Abstract]
    OR "hospital in the home"[Title/Abstract]
    OR "hospital-in-the-home"[Title/Abstract]
    OR "home hospitalization"[Title/Abstract]
    OR "home hospitalisation"[Title/Abstract]
    OR "hospital-level care at home"[Title/Abstract]
    OR "hospital level care at home"[Title/Abstract]
    OR "acute hospital care at home"[Title/Abstract]
    OR "substitutive hospital"[Title/Abstract]
    OR "admission avoidance"[Title/Abstract]
    OR "acute care at home"[Title/Abstract]
    OR "HaH"[Title/Abstract]
    OR "HITH"[Title/Abstract]
  )
  NOT (
    "hospice care"[MeSH Terms]
    OR "palliative care"[MeSH Terms]
    OR "skilled nursing facilities"[MeSH Terms]
    OR "nursing homes"[MeSH Terms]
    OR "long-term care"[MeSH Terms]
    OR "post-acute"[Title/Abstract]
    OR "post acute"[Title/Abstract]
    OR "subacute care"[Title/Abstract]
    OR "sub-acute care"[Title/Abstract]
    OR "rehabilitation at home"[Title/Abstract]
    OR "early supported discharge"[Title/Abstract]
    OR "skilled nursing at home"[Title/Abstract]
    OR "home health agency"[Title/Abstract]
    OR "home health agencies"[Title/Abstract]
    OR "nursing home"[Title/Abstract]
    OR "care home"[Title/Abstract]
    OR "assisted living"[Title/Abstract]
  )
  AND (
    "2020"[Date - Publication] : "3000"[Date - Publication]
  )
  AND English[Language]
  AND humans[MeSH Terms]
  NOT (
    "editorial"[Publication Type]
    OR "letter"[Publication Type]
    OR "news"[Publication Type]
    OR "comment"[Publication Type]
    OR "newspaper article"[Publication Type]
  )'

# ------------------------------------------------------
# Fetch via rentrez (chunked) - download all chunks into memory
# ------------------------------------------------------
message("Starting PubMed fetch via rentrez...")
setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)

search_result <- entrez_search(
  db = "pubmed",
  term = hah_query,
  use_history = TRUE,
  retmax = 0
)
total_hits <- search_result$count
message("Total PubMed hits: ", total_hits)

if (total_hits == 0) stop("No hits returned.")

chunk_size <- 200
chunks <- list()

for (start in seq(0, total_hits - 1, by = chunk_size)) {
  setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)
  message("  fetching records ", start + 1, " to ", min(start + chunk_size, total_hits))
  fetched <- entrez_fetch(
    db = "pubmed",
    web_history = search_result$web_history,
    rettype = "xml",
    retmode = "xml",
    retstart = start,
    retmax = chunk_size
  )
  chunks[[length(chunks) + 1]] <- fetched
  Sys.sleep(0.4)
}

# ------------------------------------------------------
# Parse each chunk with xml2 and extract per-article fields
# ------------------------------------------------------
message("Parsing XML with xml2...")
setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)

# Helper: extract text from a child node (returns "" if missing)
node_text <- function(parent, xpath) {
  nodes <- xml_find_all(parent, xpath)
  if (length(nodes) == 0) return("")
  paste(xml_text(nodes), collapse = " ")
}

# Helper: extract one article's fields as a named list
parse_article <- function(article_node) {
  list(
    pmid       = node_text(article_node, ".//PMID[1]"),
    title      = node_text(article_node, ".//ArticleTitle"),
    abstract   = node_text(article_node, ".//Abstract/AbstractText"),
    journal    = node_text(article_node, ".//Journal/Title"),
    journal_iso= node_text(article_node, ".//Journal/ISOAbbreviation"),
    year       = node_text(article_node, ".//JournalIssue/PubDate/Year"),
    issn       = node_text(article_node, ".//Journal/ISSN"),
    mesh_terms = paste(xml_text(xml_find_all(article_node, ".//MeshHeading/DescriptorName")), collapse = "; "),
    pub_type   = paste(xml_text(xml_find_all(article_node, ".//PublicationType")), collapse = "; "),
    authors    = paste(xml_text(xml_find_all(article_node, ".//Author/LastName")), collapse = ", "),
    doi        = node_text(article_node, ".//ArticleId[@IdType='doi']")
  )
}

# Parse each chunk and collect article records
all_articles <- list()
for (i in seq_along(chunks)) {
  setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)
  doc <- read_xml(chunks[[i]])
  article_nodes <- xml_find_all(doc, "//PubmedArticle")
  message("  chunk ", i, ": ", length(article_nodes), " articles")
  for (node in article_nodes) {
    all_articles[[length(all_articles) + 1]] <- parse_article(node)
  }
}

article_df <- bind_rows(all_articles)
article_df$pmid <- as.character(article_df$pmid)
article_df <- article_df[!duplicated(article_df$pmid), ]
message("Articles retrieved (deduplicated): ", nrow(article_df))

if (nrow(article_df) == 0) stop("No articles parsed.")

# ------------------------------------------------------
# Relevance filter
# ------------------------------------------------------
setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)

strong_signals <- paste(
  "hospital at home",
  "hospital-at-home",
  "hospital in the home",
  "hospital-in-the-home",
  "home hospitali",
  "hospital-level care at home",
  "hospital level care at home",
  "acute hospital care at home",
  "acute care at home",
  "substitutive hospital",
  "admission avoidance",
  "\\bhith\\b",
  "\\bhah\\b",
  sep = "|"
)

article_df$ta_text <- tolower(paste(
  ifelse(is.na(article_df$title), "", article_df$title),
  ifelse(is.na(article_df$abstract), "", article_df$abstract)
))

article_df$hah_signal <- grepl(strong_signals, article_df$ta_text)
message("Articles passing relevance filter: ", sum(article_df$hah_signal), " of ", nrow(article_df))
article_df <- article_df[article_df$hah_signal, ]

if (nrow(article_df) == 0) stop("No articles passed the relevance filter.")

# ------------------------------------------------------
# Clean journal names for SJR matching
# ------------------------------------------------------
clean_journal <- function(x) {
  x <- tolower(x)
  x <- gsub("&amp;", "&", x)
  x <- gsub("\\(.*?\\)", "", x)
  x <- gsub(":.*", "", x)
  x <- gsub("=.*", "", x)
  trimws(x)
}
article_df$journal_clean <- clean_journal(article_df$journal)

# SJR data
sjr_data <- read_delim("scimagojr 2025.csv",
                       delim = ";",
                       locale = locale(decimal_mark = ","),
                       show_col_types = FALSE)
sjr_clean <- data.frame(
  title  = sjr_data$Title,
  issn   = gsub(" ", "", sjr_data$Issn),
  sjr    = sjr_data$SJR,
  hindex = sjr_data$`H index`
)
sjr_clean$title_clean <- clean_journal(sjr_clean$title)

# Quality tiers
tiered <- left_join(article_df, sjr_clean, by = c("journal_clean" = "title_clean"))
tiered$quality_tier <- ifelse(
  is.na(tiered$sjr), "unmatched",
  ifelse(tiered$sjr >= 5,   "featured",
  ifelse(tiered$sjr >= 2,   "standard",
  ifelse(tiered$sjr >= 0.5, "lower_tier", "minimal")))
)

message("tiered created with ", nrow(tiered), " rows")

# Build searchable text
title_col <- if ("title.x" %in% colnames(tiered)) tiered$title.x else tiered$title

tiered$searchtext <- tolower(paste(
  ifelse(is.na(title_col),         "", title_col),
  ifelse(is.na(tiered$abstract),   "", tiered$abstract),
  ifelse(is.na(tiered$mesh_terms), "", tiered$mesh_terms)
))

# ------------------------------------------------------
# Clinical condition tags
# ------------------------------------------------------
tiered$tag_heart_failure <- grepl("heart failure|cardiac failure|\\bchf\\b|hfref|hfpef|decompensated", tiered$searchtext)
tiered$tag_copd          <- grepl("\\bcopd\\b|chronic obstructive|emphysema|aecopd|chronic bronchitis", tiered$searchtext)
tiered$tag_cellulitis    <- grepl("cellulitis|skin and soft tissue|\\bssti\\b|soft tissue infection|erysipelas|skin abscess", tiered$searchtext)
tiered$tag_pneumonia     <- grepl("pneumonia|community-acquired pneumonia|\\bcap\\b|lower respiratory tract infection|\\blrti\\b", tiered$searchtext)
tiered$tag_dvt_pe        <- grepl("deep vein thrombosis|\\bdvt\\b|pulmonary embolism|\\bpe\\b|venous thromboembolism|\\bvte\\b|anticoagulation|thromboembolic", tiered$searchtext)
tiered$tag_uti           <- grepl("urinary tract infection|\\buti\\b|pyelonephritis|urosepsis", tiered$searchtext)
tiered$tag_sepsis        <- grepl("sepsis|septicemia|bacteremia|bloodstream infection", tiered$searchtext)
tiered$tag_diabetes      <- grepl("diabet|hyperglycemia|\\bdka\\b|ketoacidosis", tiered$searchtext)
tiered$tag_oncology      <- grepl("cancer|oncolog|chemotherapy|malignancy|tumor|neoplasm|febrile neutropenia", tiered$searchtext)
tiered$tag_covid         <- grepl("covid|sars-cov-2|coronavirus", tiered$searchtext)
tiered$tag_pediatric     <- grepl("pediatric|paediatric|children|infant|neonatal", tiered$searchtext)
tiered$tag_geriatric     <- grepl("geriatric|elderly|older adult|frailty|aged|dementia", tiered$searchtext)
tiered$tag_psychiatric   <- grepl("psychiatric|mental health|depression|anxiety|substance use", tiered$searchtext)
tiered$tag_surgical      <- grepl("postoperative|post-operative|surgical|post-surgical", tiered$searchtext)

# ------------------------------------------------------
# Study type tags
# ------------------------------------------------------
tiered$tag_rct                <- grepl("randomized controlled trial|randomised controlled trial|randomized clinical trial|\\brct\\b", tiered$searchtext)
tiered$tag_systematic_review  <- grepl("systematic review|meta-analysis|meta analysis", tiered$searchtext)
tiered$tag_cohort             <- grepl("cohort study|cohort analysis|prospective cohort|retrospective cohort", tiered$searchtext)
tiered$tag_qualitative        <- grepl("qualitative|interview|focus group|thematic analysis|ethnograph", tiered$searchtext)
tiered$tag_mixed_methods      <- grepl("mixed methods|mixed-methods", tiered$searchtext)
tiered$tag_cost               <- grepl("cost-effectiveness|cost effective|economic evaluation|healthcare cost|cost analysis|cost-utility|\\bqaly\\b", tiered$searchtext)
tiered$tag_safety             <- grepl("adverse event|patient safety|medication error|\\bharm\\b|escalation|unplanned transfer", tiered$searchtext)
tiered$tag_implementation     <- grepl("implementation|workflow|quality improvement|operational|scale-up|scaling|consolidated framework", tiered$searchtext)
tiered$tag_patient_experience <- grepl("patient experience|patient satisfaction|patient-reported|caregiver experience|caregiver burden", tiered$searchtext)
tiered$tag_equity             <- grepl("equity|disparit|underserved|access to care|social determinants", tiered$searchtext)
tiered$tag_technology         <- grepl("remote monitoring|\\brpm\\b|telemedicine|telehealth|wearable|digital health", tiered$searchtext)

# ------------------------------------------------------
# Summary
# ------------------------------------------------------
message("--------------------------------------")
message("Quality tier distribution:")
print(table(tiered$quality_tier))
message("--------------------------------------")
message("Tag distribution:")
print(colSums(tiered[, grep("^tag_", colnames(tiered))]))
message("--------------------------------------")

# Export
output_file <- paste0("hah_curated_", Sys.Date(), ".csv")
write_csv(tiered, output_file)
message("Saved: ", output_file)
message("Total articles: ", nrow(tiered))
