# Art

One illustration per slide that explains something; none on statement, decision or table-heavy slides.

## The look

The deck's look lives in `art/style.md` (the template's is the house default: flat-shaded isometric objects, bold ink
outlines, plain paper background). Every picture in a deck uses the same look; a deck may rewrite `style.md` once,
before its first picture.

Why that look: each map hue has four shades (255, 220, 180, 135), which work as lit, left, right and shadow faces.
Flat fills with outlines snap to the palette cleanly; gradients, soft shadows and textures turn into grain.

## Briefs

`art/briefs.json` is a list, one entry per picture:

```json
{"id": "hazards", "panel": "840x1080", "crop": "bottom",
 "shows": "A wooden market counter with a long crack along its top. Coins slide across it, drop through the crack and over the edge, and land scattered on the floor."}
```

- `id`: the slide's picture, fitted to `art/<id>.png`.
- `panel`: its exact pixel size on the slide (840x1080 for picture-left/right slides, 1000x1080 for a cover).
- `crop` (optional): how the generated image becomes the panel's shape. `center` (default), `top`, `bottom`, `left`
  or `right` cut it, keeping that part; `pad` keeps the whole image, scaled inside the panel with paper around it
  (for a subject that fills the generated image edge to edge).
- `shows`: one concrete scene that makes the slide's point at a glance. Name the objects, what they do, and their
  colours by hue. Draw the thing itself, not a pun on it; few objects, drawn large.
- `colours` (optional), `flat_colours` (optional, default 32: how many flat colours the fit keeps).

## Generating

The pictures are made by Codex with model **gpt-6.1-terra** at reasoning effort **medium**. The team pinned both:
never substitute another model or effort; if that combination fails, report it.

`deck.py task <dir> [id ...]` prints the complete task (look, palette, briefs, output paths, and up to two existing
fitted pictures as style anchors). By default it covers every brief without a raw image. How it runs depends on the
harness:

- **A harness with its own Codex delegate** (for example T3 Code's `delegate_task`, target provider `codex`, model
  `gpt-6.1-terra`, option `reasoningEffort: medium`): send the task text as the delegate's task.
- **Any harness with a shell** (Hermes, Claude Code, Cursor): `deck.py generate <dir> [id ...]` runs the same task
  through the Codex CLI (`codex exec`, pinned model and effort, writing only inside `art/`). `--dry-run` shows the
  command.
- **Codex itself**: run the task directly with its image generation tool, on the pinned model and effort.

Raw images land in `art/raw/<id>.png`. Generated sizes may differ from the request (for example 1254x1254 for
square); the fit step handles that.

## Fitting

`deck.py fit <dir> [id ...]` crops each raw image to its panel's shape, resizes it to the panel's exact pixels,
reduces it to its main flat colours, snaps those to the deck's colour set, turns near-black into pure ink so outlines
stay clean, and removes stray specks. Resizing happens before snapping, so no in-between colours come back.

## Review

Open every fitted `art/<id>.png`. Regenerate (same pinned model and effort, `deck.py task` or `generate` with its id)
any picture that:

- contains letters, numbers, signs or a logo;
- has a frame, border bars, or a subject cut off by the edge (try `pad` or another `crop` first);
- drifts from the look of the deck's other pictures (line weight, angle, shading);
- has mushy or blotchy areas;
- doesn't make the slide's point at a glance.

Two retries per picture; after that, keep the best one and tell the user what is still wrong with it. Approved
pictures in `art/` become style anchors for the next ones automatically.
