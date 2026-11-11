---
name: sneakyslidedecks-authoring
description: "Use when making or restyling a slide deck or presentation, or illustrating slides. Produces a PDF for SneakySlideDecks map screens, with every colour a Minecraft map colour."
version: 0.1.0
author: Team-Sneakymouse
metadata:
  status: optional
---

# SneakySlideDecks authoring

Optional skill; not installed by this repository.

SneakySlideDecks shows decks in game on walls of maps: its upload page renders a PDF at 1920 x 1080, and the server
dithers every pixel into Minecraft's 244 map colours. A colour outside that palette turns into grain. Decks made here
are **palette-exact** at the source: the art and the slide colours are all map colours, so the dithering changes
nothing. The deck is plain HTML and CSS in a folder; `scripts/deck.py` turns it into the PDF.

Needs: `uv` (runs `deck.py` and installs its Python packages), Edge, Chrome or Playwright's Chromium for rendering,
and Codex for the pictures (see [art](references/art.md)). Run `uv run scripts/deck.py --help` for every command.

## Steps

1. **Set up the deck folder.** `uv run <skill>/scripts/deck.py init <dir> --title "<Title>"` copies `template/`.
   Done when `<dir>/deck.json` exists. An existing deck folder skips this step.
2. **Commit to a colour set** for this deck: a paper, an ink, one or two accent hues, and the hues its pictures need
   (skin, wood, foliage, metals...), each in all four shades:
   `deck.py palette <dir> QUARTZ COLOR_BLACK ... --ink COLOR_BLACK_255` (`deck.py bases` lists the hues). Then set
   `roles` in `art/palette.json` (`paper`, `panel`, `rule`, `muted`, `ink`, `ink-soft`, `accent`, `accent-2`, plus
   any the slides use) and run `palette` again to write them into `theme.css`. Done when every role the slides use
   exists and each text role reports 4.5:1 or better on paper (`muted`: large text only). Every deck picks its own
   set; `palette/examples/` shows earlier ones.
3. **Write the slides.** Outline first (one idea per slide), then one file per slide in `slides/`, listed in
   `deck.json` `slides`. Start each from a layout in `examples/`; titles are plain statements of what the slide shows,
   and speaker notes go in the slide's `<aside>`. Rules: [layout](references/layout.md). Done when every slide in the
   outline has a file and every picture slide has a brief in `art/briefs.json`.
4. **Make the pictures**: generate, fit, and review each one by eye, by [art](references/art.md). Done when every
   brief has a fitted `art/<id>.png` that passes that page's review list.
5. **Build and look.** `deck.py build <dir>` checks colours, renders `build/previews/`, reports layout problems,
   writes `build/<Title>.pdf` and verifies its pictures are still map colours. Fix everything it reports, then open
   every preview and check the [visual review list](references/layout.md#looking-at-the-previews). Done when the
   build exits 0 and every preview passes that list.
6. **Hand over** the PDF path. For upload: in game `/slides upload`, drop the PDF, and leave "Smaller file" off
   (JPEG compression shifts colours off the palette).

`<skill>` is this folder. Commit the deck folder if the project wants it; `build/` is ignored by the template.

## Extending

- New layout: add a class to the deck's `theme.css` (colours only through the palette variables), an example to
  `examples/` if it is reusable, and a line to the layouts table in [layout](references/layout.md).
- New check: `deck.py`'s `PROBE` (rendered layout) or `check_colours` (files). Keep each check reporting one line per
  problem, prefixed with the slide id.
- The map colour table is `palette/minecraft-map.json`, taken from Paper's `MapPalette` (identical in 1.21 and 26.2).
