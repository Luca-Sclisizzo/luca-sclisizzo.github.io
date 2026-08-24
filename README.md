# Personal academic website

A Quarto website whose publication list is generated from a Zotero BibTeX export, with per-paper links to data, code, preregistrations, preprints, and open-access versions.

Live at <https://luca-sclisizzo.github.io>. Template taken from <https://dsquintana.com>

## Requirements

- [Quarto](https://quarto.org)
- R, with the `knitr` package

Quarto also ships bundled with RStudio. If it isn't on the PATH, either open the project in RStudio and use **Build → Render Website**, or add it:

``` sh
export PATH="/Applications/RStudio.app/Contents/Resources/app/quarto/bin:$PATH"
```

## Building

``` sh
quarto render                    # the whole site
quarto render publications.qmd   # a single page
quarto preview                   # local server with live reload
```

Run `quarto render` and `quarto preview` one at a time. Running both concurrently corrupts the shared SASS cache and the preview serves an error page.

## Deploying

The site is served by GitHub Pages, published by a GitHub Actions workflow that triggers on every push to `main`/`master`. The workflow doesn't render anything itself — it just uploads the already-committed `_site/` folder as a Pages artifact (`actions/upload-pages-artifact`) and publishes it (`actions/deploy-pages`).

GitHub's Actions runners don't include R either, and `publications.qmd` renders through knitr, so — same constraint as before — the site is built locally and the rendered output committed. This is why `_site/` is tracked rather than ignored.

``` sh
quarto render
git add -A && git commit -m "Update site"
git push
```

Or run `./deploy.sh`, which does the same three commands in one shot. If it does not work, it is likely due to missing execute permissions. In that case, run:

``` bash
chmod +x deploy.sh
```

Render before pushing. The workflow deploys whatever `_site/` contains at push time, so an unrendered push deploys the previous build.

## The publication list

`publications.qmd` generates its reference list from `publications.bib`, a Zotero BibTeX export. The logic lives in `bibtools.R`, which splits the bibliography by year, formats each year through pandoc and `apa.csl` (APA 7th), and emits the entries newest year first under year headings.

Quarto and pandoc produce a single flat bibliography per document, which is why the year grouping is handled in R rather than by configuration.

### Updating

1.  In Zotero: right-click the collection → **Export Collection → BibTeX**.
2.  Save over `publications.bib`.
3.  Run `quarto render`.

New papers appear under the correct year automatically; no other file needs editing.

Note that `quarto preview` keys its cache on the `.qmd` rather than the `.bib`, so it may not pick up a bibliography change. Use `quarto render` after updating.

## Per-paper links

The labelled links after each reference come from `links.csv`, not from the bibliography. A bibliography can only render fields present in the BibTeX, and there is no standard field for a data or code repository, so these are kept in a sidecar file joined on citation key.

``` csv
citekey,label,url
Smith2024,Data & code,https://osf.io/xxxxx/
Smith2024,Preregistration,https://osf.io/yyyyy/
Doe2023,Preprint,https://doi.org/10.1000/example
```

| Column | Meaning |
|------------------------------------|------------------------------------|
| `citekey` | The citation key from `publications.bib` — the `@article{THIS_BIT,` part |
| `label` | Link text. Existing labels: `Data & code`, `Code`, `Preregistration`, `Preprint`, `Web app`, `Open access article` |
| `url` | Destination. One row per link; a paper may have several rows |

To add a link, find the paper's citation key in `publications.bib` and add a row.

### When a link stops appearing

Links are matched to papers by citation key. A routine Zotero re-export preserves keys, so links persist across updates. If Better BibTeX regenerates its keys — for example after a change to its key-format setting — a row may no longer match any entry.

The link is then omitted silently, and the render reports the affected rows:

```         
!! links.csv: 1 row(s) match no bibliography entry — citation keys may have
   changed in Zotero:
     someOldKey2021
```

Update the `citekey` in that row to the paper's current key.

## Repository layout

## Repository structure

``` text
.
├── site-pages/
│   ├── index.qmd
│   ├── publications.qmd
│   ├── talks.qmd
│   ├── unpublished.qmd
│   ├── software.qmd
│   ├── about.qmd
│   └── cv.qmd
│
├── files/
│   ├── *.jpg                         # Images
│   ├── CV_Sclisizzo.html             # AcademiCV output
│   └── Bayesian-Statistics_project.html  # Project page
│
├── icons/
│   └── ...                           # Icon assets
│
├── .github/
│   └── workflows/
│       └── ...                       # GitHub Pages deployment
│
├── _quarto.yml                       # Site configuration
├── bibtools.R                        # Publication list generation
├── publications.bib                  # Zotero export
├── links.csv                         # Per-paper links
├── apa.csl                           # APA 7th citation style
├── styles.css                        # Shared styling
├── theme-light.scss                  # Light theme
├── theme-dark.scss                   # Dark theme
├── deploy.sh                         # GitHub deployment script
└── _site/                            # Rendered site output
```

`ORCID-iD_icon_BW_vector.svg` (in `icons/`) is referenced from `styles.css` rather than from any page, so it is declared under `resources:` in `_quarto.yml` to ensure it is published.

## Licence

Code is [MIT licensed](LICENSE). Written content is [CC BY 4.0](LICENSE-CONTENT.md). The profile photograph is not licensed for reuse — see `LICENSE-CONTENT.md` for the full breakdown.
