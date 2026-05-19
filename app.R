library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)
library(readr)

# ------------------------------------------------------
# Load the most recent curated CSV from the app's directory
# ------------------------------------------------------
csv_files <- list.files(pattern = "hah_curated_.*\\.csv")
if (length(csv_files) == 0) {
  stop("No hah_curated_*.csv files found in the app directory. ",
       "Run the curation script first to generate one.")
}
latest_file <- csv_files[order(csv_files, decreasing = TRUE)][1]
message("Loading: ", latest_file)
data <- read_csv(latest_file, show_col_types = FALSE)

last_updated <- gsub("hah_curated_|\\.csv", "", latest_file)

# ------------------------------------------------------
# Backward compatibility: older CSVs used 'quality_tier'
# ------------------------------------------------------
if (!"sjr_range" %in% colnames(data) && "quality_tier" %in% colnames(data)) {
  tier_map <- c(
    "featured"   = "SJR 5.0+",
    "standard"   = "SJR 2.0-4.99",
    "lower_tier" = "SJR 0.5-1.99",
    "minimal"    = "SJR <0.5",
    "unmatched"  = "Not indexed"
  )
  data$sjr_range <- ifelse(data$quality_tier %in% names(tier_map),
                           tier_map[data$quality_tier],
                           data$quality_tier)
}

title_col <- if ("title.x" %in% colnames(data)) "title.x" else "title"
data$year <- suppressWarnings(as.numeric(data$year))

# ------------------------------------------------------
# Tag definitions
# ------------------------------------------------------
condition_tags <- c(
  "tag_heart_failure", "tag_copd", "tag_cellulitis", "tag_pneumonia",
  "tag_dvt_pe", "tag_uti", "tag_sepsis", "tag_diabetes",
  "tag_oncology", "tag_covid",
  "tag_pediatric", "tag_geriatric", "tag_psychiatric", "tag_surgical"
)

study_tags <- c(
  "tag_rct", "tag_systematic_review", "tag_cohort",
  "tag_qualitative", "tag_mixed_methods",
  "tag_cost", "tag_safety", "tag_implementation",
  "tag_patient_experience", "tag_equity", "tag_technology"
)

condition_tags <- condition_tags[condition_tags %in% colnames(data)]
study_tags <- study_tags[study_tags %in% colnames(data)]

pretty <- function(x) tools::toTitleCase(gsub("_", " ", gsub("tag_", "", x)))

sjr_range_choices <- c("SJR 5.0+", "SJR 2.0-4.99", "SJR 0.5-1.99", "SJR <0.5", "Not indexed")
sjr_range_choices <- sjr_range_choices[sjr_range_choices %in% unique(data$sjr_range)]

# ------------------------------------------------------
# UI
# ------------------------------------------------------
ui <- dashboardPage(
  dashboardHeader(title = "Hospital at Home Users Group Research Center",
  titleWidth = 500
),
  dashboardSidebar(
    sidebarMenu(
      menuItem("How to Use", tabName = "howto", icon = icon("info-circle")),
      menuItem("Browse Articles", tabName = "browse", icon = icon("search")),
      menuItem("Summary", tabName = "summary", icon = icon("chart-bar"))
    ),
    # NOTE: defaults are now "All" / "any" so the app loads with no filtering.
    # Users choose what they want from the dropdowns themselves.
    selectInput("sjr_range", "Journal SJR Range:",
                choices = c("All", sjr_range_choices),
                selected = "All", multiple = TRUE),
    selectInput("condition", "Clinical Condition:",
                choices = c("Any" = "any", setNames(condition_tags, pretty(condition_tags))),
                selected = "any", multiple = TRUE),
    selectInput("study", "Study Type:",
                choices = c("Any" = "any", setNames(study_tags, pretty(study_tags))),
                selected = "any", multiple = TRUE),
    sliderInput("year", "Year:",
                min = 2020,
                max = as.numeric(format(Sys.Date(), "%Y")),
                value = c(2020, as.numeric(format(Sys.Date(), "%Y"))),
                step = 1, sep = "")
  ),
  dashboardBody(
    tags$head(tags$style(HTML("
      .howto-section h3 { color: #1F3864; margin-top: 25px; }
      .howto-section h4 { color: #2E75B6; margin-top: 18px; }
      .howto-section p, .howto-section li { font-size: 14px; line-height: 1.6; }
      .howto-section ul { margin-bottom: 12px; }
      .howto-callout {
        background: #F2F7FC;
        border-left: 4px solid #2E75B6;
        padding: 12px 18px;
        margin: 15px 0;
        border-radius: 4px;
      }
      .howto-callout strong { color: #1F3864; }
    "))),
    tabItems(
      # -------- HOW TO USE TAB --------
      tabItem(tabName = "howto",
        fluidRow(
          box(width = 12, status = "primary", solidHeader = TRUE,
              title = paste("How to Use This Database  -  Last updated:", last_updated),
              div(class = "howto-section",
                h3("Welcome to the Hospital at Home Users Group Research Database"),
                p("This database contains peer-reviewed literature on the Hospital at Home (HaH) ",
                  "care model, automatically curated from PubMed and refreshed monthly. ",
                  "Every article has passed a two-stage relevance screen and is tagged ",
                  "by clinical condition and study type to support fast filtering."),
                div(class = "howto-callout",
                  strong("Quick start: "),
                  "Click ",
                  strong("Browse Articles"),
                  " on the left, then use the filters in the sidebar to narrow results. ",
                  "Click ",
                  strong("View"),
                  " on any row to open the full record in PubMed."
                ),

                h3("What's in the database"),
                p("This database contains articles published from 2020 to the present that meet ",
                  "all of the following criteria:"),
                tags$ul(
                  tags$li("Indexed in PubMed"),
                  tags$li("Published in English"),
                  tags$li("Reports on hospital-at-home, hospital-in-the-home, home hospitalization, ",
                          "admission avoidance, or substitutive acute care"),
                  tags$li("Confirmed relevance via second-pass screen on title and abstract")
                ),
                p(strong("Excluded by design: "),
                  "hospice and palliative care, skilled nursing facility care, post-acute ",
                  "rehabilitation, early supported discharge, chronic home health, long-term care, ",
                  "and non-research publication types (editorials, letters, news, comments)."),

                h3("Using the filters"),

                h4("Journal SJR Range"),
                p("SJR (SCImago Journal Rank) is a measure of journal influence based on citation patterns. ",
                  "It is shown here as a range, not a ranking:"),
                tags$ul(
                  tags$li(strong("SJR 5.0+ "), "- High-influence journals (e.g., NEJM, JAMA, Lancet)"),
                  tags$li(strong("SJR 2.0-4.99 "), "- Major specialty and general medicine journals"),
                  tags$li(strong("SJR 0.5-1.99 "), "- Specialty and subspecialty journals"),
                  tags$li(strong("SJR <0.5 "), "- Smaller-circulation journals"),
                  tags$li(strong("Not indexed "), "- Journal not in the SCImago database; manual review recommended")
                ),
                div(class = "howto-callout",
                  strong("Note: "),
                  "SJR is a journal-level metric, not an article-level quality measure. ",
                  "Important HaH work appears across the full range. Use SJR to filter and prioritize, ",
                  "not to judge individual articles."
                ),

                h4("Clinical Condition"),
                p("Filters articles to those whose title, abstract, or MeSH terms reference a specific ",
                  "clinical condition. Selecting multiple conditions returns articles tagged with ",
                  strong("any"), " of them (OR logic), not all."),
                p(em("Example: "),
                  "Selecting ", strong("Heart Failure"), " and ", strong("COPD"),
                  " returns articles tagged with either condition."),

                h4("Study Type"),
                p("Filters by methodology (RCT, cohort, systematic review, qualitative, etc.) ",
                  "or topical focus (cost, safety, implementation, patient experience, equity, technology). ",
                  "Like Condition filters, multiple selections use OR logic."),

                h4("Year"),
                p("Limits results by year of publication. The default range is 2020 to present."),

                h3("Search tips"),
                tags$ul(
                  tags$li(strong("Start broad, then narrow. "),
                          "Begin with no filters except a high SJR range, scan the results, ",
                          "then add condition or study-type filters as needed."),
                  tags$li(strong("Free-text search the results table. "),
                          "Once articles are displayed, the search box above the table searches ",
                          "across all visible columns. Useful for author names, specific phrases, ",
                          "or institution names."),
                  tags$li(strong("Sort by SJR. "),
                          "Click any column header to sort. Default sort is by SJR descending so ",
                          "highest-impact journals appear first."),
                  tags$li(strong("Download what you find. "),
                          "Use the ", strong("Download CSV"), " button to export the filtered results. ",
                          "Useful for citation managers, sharing with colleagues, or appendix tables.")
                ),

                h3("Common workflows"),

                h4("Preparing for a grant or manuscript"),
                tags$ol(
                  tags$li("Set SJR Range to ", strong("SJR 5.0+"), " and ", strong("SJR 2.0-4.99")),
                  tags$li("Select your specific condition(s) of interest"),
                  tags$li("Filter Study Type to ", strong("Systematic Review"), ", ",
                          strong("Meta Analysis"), ", and ", strong("RCT")),
                  tags$li("Download CSV and import into your reference manager")
                ),

                h4("Scoping the implementation literature"),
                tags$ol(
                  tags$li("Leave SJR Range as ", strong("All")),
                  tags$li("Filter Study Type to ", strong("Implementation"), " and ", strong("Qualitative")),
                  tags$li("Add a condition filter if you have a specific clinical focus")
                ),

                h4("Building a journal club list"),
                tags$ol(
                  tags$li("Filter to ", strong("SJR 5.0+")),
                  tags$li("Restrict Year to the last 12 months"),
                  tags$li("Download CSV; review titles and abstracts as a group")
                ),

                h3("Frequently asked questions"),

                h4("How current is this data?"),
                p("The database is refreshed monthly from PubMed. The current data was last updated on ",
                  strong(last_updated),
                  ". PubMed itself has a typical indexing lag of 1-4 weeks after publication, so very ",
                  "recent articles may not yet appear."),

                h4("Why don't I see [specific paper] I know exists?"),
                p("Possible reasons, in order of likelihood:"),
                tags$ul(
                  tags$li("Published before 2020 (outside the date range)"),
                  tags$li("Not yet indexed in PubMed"),
                  tags$li("Doesn't use HaH-specific terminology in title or abstract"),
                  tags$li("Excluded as an editorial, letter, or comment"),
                  tags$li("Discusses post-acute or transitional care rather than substitutive acute care")
                ),
                p("If you believe a paper is being incorrectly excluded, contact the research center ",
                  "with the PMID and we can review the exclusion logic."),

                h4("What does 'Not indexed' mean for a journal?"),
                p("It means the journal isn't currently in the SCImago database used for SJR scoring. ",
                  "This can happen with very new journals, regional journals, or journals that have ",
                  "recently changed names. These articles are still included in the database and should ",
                  "be reviewed on their merits."),

                h4("Can I suggest a new tag or search term?"),
                p("Yes. Suggestions for additional ",
                  "clinical conditions, study types, or terminology should be sent to the Hospital at Home Users Group Program Manager: Gabrielle Schiller gabrielle.schiller@mssm.edu."),

                h3("Methodology"),
                p("The full search strategy, including the PubMed query, inclusion and exclusion terms, ",
                  "and tagging logic, is documented in ",
                  strong("SOP HAH-RC-001"),
                  ". Request a copy from the research center if you need it for a manuscript methods ",
                  "section or grant application."),

                hr(),
                p(em("Questions, feedback, or article suggestions? Contact the Hospital at Home Users Group Program Manager: Gabrielle Schiller gabrielle.schiller@mssm.edu."),
                  style = "color: #595959; font-size: 13px;")
              )
          )
        )
      ),

      # -------- BROWSE TAB --------
      tabItem(tabName = "browse",
        fluidRow(
          valueBoxOutput("total_box", width = 4),
          valueBoxOutput("high_sjr_box", width = 4),
          valueBoxOutput("rct_box", width = 4)
        ),
        fluidRow(
          box(width = 12, title = "Filtered Articles", status = "primary", solidHeader = TRUE,
              downloadButton("download", "Download CSV"),
              br(), br(),
              DTOutput("articles_table"))
        )
      ),

      # -------- SUMMARY TAB --------
      tabItem(tabName = "summary",
        fluidRow(
          box(width = 6, title = "SJR Ranges", status = "primary", tableOutput("sjr_summary")),
          box(width = 6, title = "Conditions", status = "primary", tableOutput("condition_summary"))
        ),
        fluidRow(
          box(width = 12, title = "Study Types", status = "primary", tableOutput("study_summary"))
        )
      )
    )
  )
)

# ------------------------------------------------------
# Server
# ------------------------------------------------------
server <- function(input, output, session) {

  filtered <- reactive({
    df <- data

    # SJR range: skip filter if "All" is selected or nothing is selected
    if (length(input$sjr_range) > 0 && !"All" %in% input$sjr_range) {
      df <- df[df$sjr_range %in% input$sjr_range, ]
    }

    # Year filter
    year_ok <- !is.na(df$year) & df$year >= input$year[1] & df$year <= input$year[2]
    df <- df[year_ok, ]

    # Condition filter
    real_conditions <- setdiff(input$condition, "any")
    if (length(real_conditions) > 0) {
      condition_match <- rowSums(df[, real_conditions, drop = FALSE], na.rm = TRUE) > 0
      df <- df[condition_match, ]
    }

    # Study type filter
    real_studies <- setdiff(input$study, "any")
    if (length(real_studies) > 0) {
      study_match <- rowSums(df[, real_studies, drop = FALSE], na.rm = TRUE) > 0
      df <- df[study_match, ]
    }

    df
  })

  output$total_box <- renderValueBox({
    valueBox(nrow(filtered()), "Articles", icon = icon("file-alt"), color = "blue")
  })
  output$high_sjr_box <- renderValueBox({
    valueBox(sum(filtered()$sjr_range == "SJR 5.0+", na.rm = TRUE), "SJR 5.0+",
             icon = icon("star"), color = "yellow")
  })
  output$rct_box <- renderValueBox({
    valueBox(sum(filtered()$tag_rct, na.rm = TRUE), "RCTs",
             icon = icon("flask"), color = "green")
  })

  output$articles_table <- renderDT({
    df <- filtered()
    df$PubMed <- paste0("<a href='https://pubmed.ncbi.nlm.nih.gov/", df$pmid,
                        "' target='_blank'>View</a>")
    display_df <- df[, c(title_col, "journal", "year", "sjr", "sjr_range", "PubMed")]
    colnames(display_df) <- c("Title", "Journal", "Year", "SJR", "SJR Range", "Link")
    datatable(display_df, escape = FALSE,
              options = list(pageLength = 25, scrollX = TRUE,
                             order = list(list(3, "desc"))),
              rownames = FALSE)
  })

  output$download <- downloadHandler(
    filename = function() paste0("hah_filtered_", Sys.Date(), ".csv"),
    content = function(file) write_csv(filtered(), file)
  )

  output$sjr_summary <- renderTable({
    counts <- table(filtered()$sjr_range)
    order_vec <- c("SJR 5.0+", "SJR 2.0-4.99", "SJR 0.5-1.99", "SJR <0.5", "Not indexed")
    order_vec <- order_vec[order_vec %in% names(counts)]
    data.frame(
      `SJR Range` = order_vec,
      Count = as.integer(counts[order_vec]),
      check.names = FALSE
    )
  })

  output$condition_summary <- renderTable({
    df <- filtered()
    data.frame(
      Condition = pretty(condition_tags),
      Count = sapply(condition_tags, function(t) sum(df[[t]], na.rm = TRUE))
    )
  })

  output$study_summary <- renderTable({
    df <- filtered()
    data.frame(
      Type = pretty(study_tags),
      Count = sapply(study_tags, function(t) sum(df[[t]], na.rm = TRUE))
    )
  })
}

shinyApp(ui, server)
