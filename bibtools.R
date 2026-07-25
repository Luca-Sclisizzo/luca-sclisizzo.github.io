# Render a BibTeX file as an APA reference list, grouped under year headings.
#
# Quarto/pandoc emit a single flat bibliography per document, so to get one
# formatted list per year we split the .bib by year and run each subset through
# pandoc --citeproc separately, then paste the HTML back together.

pandoc_bin <- function() {
  # Quarto ships its own pandoc; prefer it over anything on PATH.
  arch <- if (Sys.info()[["machine"]] == "arm64") "aarch64" else "x86_64"
  bundled <- file.path(
    "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools",
    arch, "pandoc"
  )
  if (file.exists(bundled)) bundled else Sys.which("pandoc")
}

# Split a .bib into a character vector of whole entries.
read_bib_entries <- function(path) {
  con <- file(path, encoding = "UTF-8")
  on.exit(close(con))
  txt <- paste(readLines(con, warn = FALSE), collapse = "\n")
  parts <- strsplit(txt, "\n(?=@)", perl = TRUE)[[1]]
  parts[grepl("^\\s*@", parts)]
}

entry_year <- function(entry) {
  m <- regmatches(entry, regexpr("year\\s*=\\s*[{\"]\\s*(\\d{4})", entry, perl = TRUE))
  if (length(m) == 0) {
    m <- regmatches(entry, regexpr("date\\s*=\\s*[{\"]\\s*(\\d{4})", entry, perl = TRUE))
  }
  if (length(m) == 0) return(NA_integer_)
  as.integer(regmatches(m, regexpr("\\d{4}", m)))
}

# Render one .bib to a bibliography HTML fragment via pandoc --citeproc.
bib_to_html <- function(entries, csl) {
  # useBytes avoids re-encoding UTF-8 content into the session locale, which
  # would mangle names like Elvsåshagen and Nærland on the way to pandoc.
  bib <- tempfile(fileext = ".bib")
  writeLines(enc2utf8(entries), bib, useBytes = TRUE)

  md <- tempfile(fileext = ".md")
  writeLines(c("---", "nocite: |", "  @*", "---", "", "::: {#refs}", ":::"), md)

  out <- system2(
    pandoc_bin(),
    c(shQuote(md), "--citeproc", paste0("--csl=", shQuote(csl)),
      paste0("--bibliography=", shQuote(bib)), "-t", "html"),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    stop("pandoc failed:\n", paste(out, collapse = "\n"))
  }
  # pandoc always emits UTF-8; tag it as such so R doesn't treat it as native.
  Encoding(out) <- "UTF-8"
  paste(out, collapse = "\n")
}

# Read the links sidecar: citekey,label,url. Returns a named list of data frames.
read_links <- function(path) {
  if (is.null(path) || !file.exists(path)) return(list())
  df <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  need <- c("citekey", "label", "url")
  if (!all(need %in% names(df))) {
    stop("links file must have columns: ", paste(need, collapse = ", "))
  }
  df <- df[nzchar(trimws(df$url)), , drop = FALSE]
  split(df, df$citekey)
}

esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

# Append badge links inside each .csl-entry div, matched on its ref-<citekey> id.
add_badges <- function(html, links) {
  matched <- character(0)
  if (!length(links)) return(list(html = html, matched = matched))

  for (key in names(links)) {
    rows <- links[[key]]
    # Leading space gives the browser a point to wrap the chips onto the next
    # line instead of overlapping a long, unbroken DOI that fills the line.
    badges <- paste0(
      " ",
      paste0('<a class="pub-badge" href="', esc(rows$url),
             '" target="_blank" rel="noopener">', esc(rows$label), '</a> ',
             collapse = "")
    )
    # Entry ids are the citation key. Locate the div by fixed string (keys can
    # contain regex metacharacters), then insert before its closing </div>.
    # csl-entry divs are not nested, so the first close is the right one.
    anchor <- paste0('<div id="ref-', key, '"')
    at <- regexpr(anchor, html, fixed = TRUE)
    if (at > 0) {
      rest <- substring(html, at)
      close_at <- regexpr("</div>", rest, fixed = TRUE)
      if (close_at > 0) {
        cut <- at + close_at - 2L
        html <- paste0(substring(html, 1, cut), badges, substring(html, cut + 1))
        matched <- c(matched, key)
      }
    }
  }
  list(html = html, matched = matched)
}

#' @param heading_level Markdown heading depth for the year labels.
#' @param links_path CSV of citekey,label,url appended as badges. NULL to skip.
render_by_year <- function(bib_path, csl = "apa.csl", heading_level = 3,
                           links_path = "links.csv") {
  # Quarto may launch R under the C locale, in which case cat() escapes
  # non-ASCII output (Nærland -> N<U+00E6>rland). Force a UTF-8 ctype.
  if (identical(Sys.getlocale("LC_CTYPE"), "C")) {
    Sys.setlocale("LC_CTYPE", "en_US.UTF-8")
  }

  entries <- read_bib_entries(bib_path)
  years <- vapply(entries, entry_year, integer(1))

  if (anyNA(years)) {
    warning(sum(is.na(years)), " entries have no year and were skipped.")
    entries <- entries[!is.na(years)]
    years <- years[!is.na(years)]
  }

  links <- read_links(links_path)
  used <- character(0)

  hashes <- strrep("#", heading_level)
  for (y in sort(unique(years), decreasing = TRUE)) {
    html <- bib_to_html(entries[years == y], csl)
    res <- add_badges(html, links)
    used <- c(used, res$matched)
    cat("\n", hashes, " ", y, "\n\n", sep = "")
    cat(res$html, "\n\n", sep = "")
  }

  orphans <- setdiff(names(links), used)
  if (length(orphans)) {
    # Deliberately NOT warning(): knitr captures warnings and renders them into
    # the published page, so a Zotero key change would print an error notice to
    # site visitors. Writing to stderr keeps it in the render console instead.
    cat("\n!! links.csv: ", length(orphans), " row(s) match no bibliography entry",
        " — citation keys may have changed in Zotero:\n     ",
        paste(orphans, collapse = ", "), "\n\n", sep = "", file = stderr())
  }
}
