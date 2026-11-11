# Layout

## The deck folder

```
deck.json          title, slide order, Google Fonts css2 links, footer text ("{n}" and "{total}" are filled in)
theme.css          layouts and type; its palette block is written by `deck.py palette`
slides/<id>.html   one <section class="slide …" id="<id>"> per file, speaker notes in its <aside>
art/palette.json   the deck's colour set and roles
art/style.md       the deck's picture look
art/briefs.json    one brief per picture
art/raw/           generated images;  art/<id>.png  fitted pictures
build/             previews and the PDF (not committed)
```

The canvas is 1920 x 1080 px, the SneakySlideDecks 1080p screen, so pictures shown at their own size reach the maps
pixel for pixel. Paths in slides are relative to the deck folder (`src="art/hazards.png"`).

## Layouts

| Class on the section | Use | Picture |
|---|---|---|
| `cover` | first slide: kicker, title, lead, three short lines | right, 1000 x 1080 |
| `art-left` | the usual content slide | left, 840 x 1080 |
| `art-right` | the same, mirrored, for variety within a section | right, 840 x 1080 |
| `full` | text only: cards, a wider table | none |
| `statement` | one centred statement: openers, the decision, the close | none |

`examples/` has one slide per layout plus a table and a card row. Picture slides put `<img class="art">` first
(`art-left`) or last (`art-right`/`cover`), and the text in `<div class="text">`. `no-footer` on a section drops its
footer; `tight` on `.text` narrows the gaps for a slide that is just over.

## Writing slides

- **One idea per slide.** A slide whose body needs more than about 40 words beside a picture is two slides, or its
  detail belongs in the speaker notes.
- **Titles** are plain statements of what the slide shows ("What the current system costs players"), never catchy
  metaphors. At most two lines; break a two-line title with `<br>` where it reads best.
- **Body** is one of: numbered rows (`ol.rows`, 3-6 parallel lines), a lead sentence plus points (`ul.points`), a
  ruled table (`table.ruled`), or cards on text-only slides. Not cards beside a picture.
- **Type scale** (theme.css): kicker 24, body 30, lead 40, title 64, statement 72, cover 80. Emphasis by weight or the
  accent colour, never a new size. Nothing under 24 px: smaller text breaks up on maps.
- **Colours** only through the palette variables (`var(--ink)`, `var(--accent)`...). No opacity, gradients,
  box or text shadows: each blends in-between colours. `deck.py build` reports all of these.
- **Consistency:** slides of one kind share markup, so kicker and title sit at the same height on every content slide;
  keep the picture on the same side within a run, switching side only between sections.
- **Speaker notes** in the `<aside>`: what the presenter says. They are not printed.

## Looking at the previews

`deck.py build` already reports overflowing text, mid-word breaks, text past the bottom margin, text overlapping a
picture, text under 24 px, a title whose last line is one word, and blending CSS. After it exits 0, open every
`build/previews/<id>.png` and check what it can't:

- the picture and text read as one composition: balanced space, nothing crammed against an edge;
- kicker and title at the same height as on the neighbouring slides of the same layout;
- the picture makes the slide's point and matches the deck's other pictures;
- text breaks where it reads well (no awkward line ends in the title or the rows);
- the slide says one thing, and its notes cover what it leaves out.

Fix and rebuild until every preview passes.
