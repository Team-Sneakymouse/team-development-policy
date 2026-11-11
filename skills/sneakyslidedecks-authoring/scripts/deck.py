# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11", "numpy>=2", "playwright>=1.48", "pymupdf>=1.24"]
# ///
"""Build illustrated slide decks as PDFs whose colours are all Minecraft map colours.

Run with uv (it installs the dependencies listed above):  uv run deck.py <command> ...

  init DECK --title "Title"         new deck folder from the template
  bases                             list Minecraft's map hues (for `palette`)
  palette DECK HUE [HUE ...] [--ink NAME] [--shades 255,220,180,135]
                                    set the deck's colour set (every listed hue in those shades); keeps its roles
  task DECK [ID ...]                print the image-generation task for briefs (all briefs without a raw image)
  generate DECK [ID ...] [--dry-run]
                                    run that task with the Codex CLI (gpt-6.1-terra, reasoning effort medium)
  fit DECK [ID ...]                 fit raw images to their panels and the deck's colours (all briefs by default)
  check DECK                        every colour in art, theme and slides must be a map colour in the deck's set
  build DECK                        check, render previews, report layout problems, write the PDF, verify its art

DECK is a deck folder (see the skill's template/). Exit status is 1 when a check finds a problem.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SKILL = Path(__file__).resolve().parent.parent
MAP_DATA = json.loads((SKILL / "palette" / "minecraft-map.json").read_text(encoding="utf-8"))["colors"]
MAP = {c["hex"].upper(): c["name"] for c in MAP_DATA}
BY_NAME = {c["name"]: c["hex"].upper() for c in MAP_DATA}

CODEX_MODEL = "gpt-6.1-terra"  # pinned by the team: never substitute
CODEX_EFFORT = "medium"
INK_MARGIN = 0.07  # OKLab lightness above the ink colour that still counts as outline
PALETTE_BEGIN, PALETTE_END = "/* palette:begin (written by deck.py palette) */", "/* palette:end */"


# ---------------------------------------------------------------- colour maths

def rgb_of(hex_: str) -> tuple[int, int, int]:
    return int(hex_[1:3], 16), int(hex_[3:5], 16), int(hex_[5:7], 16)


def hex_of(rgb) -> str:
    return "#%02X%02X%02X" % tuple(int(v) for v in rgb)


def oklab(rgb) -> np.ndarray:
    """sRGB 0-255 (...x3) to OKLab, where plain distance matches how different colours look."""
    c = np.asarray(rgb, dtype=np.float64) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    return np.cbrt(c @ m1.T) @ m2.T


def luminance(hex_: str) -> float:
    r, g, b = [v / 255 for v in rgb_of(hex_)]
    f = lambda v: v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast(a: str, b: str) -> float:
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def nearest_map(hex_: str) -> str:
    keys = list(MAP)
    d = ((oklab([rgb_of(k) for k in keys]) - oklab([rgb_of(hex_)])) ** 2).sum(-1)
    return f"{keys[int(d.argmin())]} ({MAP[keys[int(d.argmin())]]})"


# ---------------------------------------------------------------- deck files

class Deck:
    def __init__(self, root: str | Path):
        self.root = Path(root).resolve()
        if not (self.root / "deck.json").exists():
            sys.exit(f"{self.root} has no deck.json; create a deck with `deck.py init`.")
        self.meta = json.loads((self.root / "deck.json").read_text(encoding="utf-8"))
        self.art = self.root / "art"
        self.build = self.root / "build"

    @property
    def palette(self) -> dict:
        return json.loads((self.art / "palette.json").read_text(encoding="utf-8"))

    def colours(self) -> dict[str, str]:
        return {n: h.upper() for n, h in self.palette["colors"].items()}

    def role_hex(self) -> dict[str, str]:
        cols = self.colours()
        return {role: cols.get(name, name).upper() for role, name in self.palette.get("roles", {}).items()}

    def ink(self) -> str:
        p = self.palette
        return self.colours().get(p.get("ink", ""), "") or min(self.colours().values(), key=lambda h: oklab(rgb_of(h))[0])

    def briefs(self) -> list[dict]:
        path = self.art / "briefs.json"
        return json.loads(path.read_text(encoding="utf-8")) if path.exists() else []

    def slide_files(self) -> list[Path]:
        return [self.root / "slides" / f"{sid}.html" for sid in self.meta["slides"]]


def pick(briefs: list[dict], ids: list[str]) -> list[dict]:
    if not ids:
        return briefs
    known = {b["id"]: b for b in briefs}
    missing = [i for i in ids if i not in known]
    if missing:
        sys.exit(f"no brief with id {', '.join(missing)} in art/briefs.json")
    return [known[i] for i in ids]


# ---------------------------------------------------------------- init / palette

def cmd_init(root: str, title: str) -> None:
    dst = Path(root)
    if dst.exists() and any(dst.iterdir()):
        sys.exit(f"{dst} exists and is not empty")
    shutil.copytree(SKILL / "template", dst, dirs_exist_ok=True)
    meta = json.loads((dst / "deck.json").read_text(encoding="utf-8"))
    meta["title"] = title
    (dst / "deck.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    write_tokens(Deck(dst))
    print(f"{dst}: new deck '{title}'. Next: pick its colours (`deck.py palette`), then write slides and art/briefs.json.")


def cmd_bases() -> None:
    print(" ".join(dict.fromkeys(c["name"].rsplit("_", 1)[0] for c in MAP_DATA)))


def cmd_palette(root: str, hues: list[str], ink: str | None, shades: list[int]) -> None:
    deck = Deck(root)
    path = deck.art / "palette.json"
    old = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    colours = {}
    for hue in hues:
        for s in shades:
            name = f"{hue}_{s}"
            if name not in BY_NAME:
                sys.exit(f"unknown map colour {name}; `deck.py bases` lists the hues")
            colours[name] = BY_NAME[name]
    data = {"note": "This deck's colour set. Art is snapped to it; theme.css uses its roles. Edit with `deck.py palette`.",
            "colors": colours, "ink": ink or old.get("ink", ""), "roles": old.get("roles", {})}
    path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    missing = {r: n for r, n in data["roles"].items() if n not in colours}
    print(f"{path}: {len(colours)} colours")
    for role, name in missing.items():
        print(f"    role {role} = {name} is not in the new set: pick another in palette.json")
    write_tokens(deck)


def write_tokens(deck: Deck) -> None:
    """Rewrite theme.css's palette block from the palette roles, and report text contrast."""
    theme = deck.root / "theme.css"
    if not (deck.art / "palette.json").exists() or not theme.exists():
        return
    roles = deck.role_hex()
    block = PALETTE_BEGIN + "\n:root {\n" + "".join(f"  --{r}: {h};\n" for r, h in roles.items()) + "}\n" + PALETTE_END
    css = theme.read_text(encoding="utf-8")
    css = re.sub(re.escape(PALETTE_BEGIN) + r".*?" + re.escape(PALETTE_END), lambda _: block, css, flags=re.S) \
        if PALETTE_BEGIN in css else block + "\n\n" + css
    theme.write_text(css, encoding="utf-8")
    paper = roles.get("paper")
    if paper:
        for role in ("ink", "ink-soft", "accent", "accent-2", "good", "bad", "muted"):
            if role in roles:
                c = contrast(roles[role], paper)
                note = "" if c >= 4.5 else "  (below 4.5: large text only)" if c >= 3 else "  (too low for text)"
                print(f"    --{role} on --paper: {c:.1f}:1{note}")


# ---------------------------------------------------------------- image generation

def gen_size(panel: str) -> str:
    w, h = map(int, panel.lower().split("x"))
    return "1024x1536" if w / h < 0.9 else "1536x1024" if w / h > 1.1 else "1024x1024"


def build_task(deck: Deck, briefs: list[dict], refs: list[Path], out_dir: str) -> str:
    """The image-generation task: look, palette, briefs, output paths, style anchors."""
    style = (deck.art / "style.md").read_text(encoding="utf-8").strip()
    groups: dict[str, list[str]] = {}
    for name, hex_ in deck.colours().items():
        groups.setdefault(name.rsplit("_", 1)[0], []).append(hex_)
    colours = "; ".join(f"{hue.lower().replace('_', ' ')} {' '.join(hs)}" for hue, hs in groups.items())
    lines = [
        f"Generate {len(briefs)} illustration(s) with your image generation tool, one per brief below, and save each "
        f"as a PNG at {out_dir}/<id>.png (create the folder). Generate at the size given per brief. Do not edit, crop "
        "or recolour afterwards; another tool fits them to the palette. Do not change any other files. This task needs "
        "only your image generation tool and file copies: skip repository setup, git and project instructions.", ""]
    if refs:
        lines += ["Match the style of these approved images exactly (line weight, shading, colours, angle): "
                  + ", ".join(str(r) for r in refs), ""]
    lines += ["Style for every image (keep it identical across all of them):", style, "",
              f"Use only these colours, as flat fills: {colours}.", "", "Briefs:", ""]
    for b in briefs:
        lines += [f"id: {b['id']}", f"size: {gen_size(b['panel'])}", f"shows: {b['shows']}"]
        if b.get("colours"):
            lines.append(f"colours: {b['colours']}")
        lines.append("")
    lines.append("When done, reply with the list of saved paths. If any image came out with text, numbers, lettering, "
                 "a border or cut-off objects, regenerate it before replying.")
    return "\n".join(lines)


def refs_for(deck: Deck, ids: set[str]) -> list[Path]:
    """Up to two of the deck's fitted pictures, as style anchors for new ones."""
    return [p for p in sorted(deck.art.glob("*.png")) if p.stem not in ids][:2]


def todo(deck: Deck, ids: list[str]) -> list[dict]:
    if not deck.briefs():
        sys.exit("art/briefs.json has no briefs yet; write one per picture (references/art.md)")
    briefs = pick(deck.briefs(), ids)
    return briefs if ids else [b for b in briefs if not (deck.art / "raw" / f"{b['id']}.png").exists()]


def cmd_task(root: str, ids: list[str]) -> None:
    deck = Deck(root)
    briefs = todo(deck, ids)
    if not briefs:
        sys.exit("every brief already has a raw image; name ids to regenerate them")
    print(build_task(deck, briefs, refs_for(deck, {b["id"] for b in briefs}), (deck.art / "raw").as_posix()))


def cmd_generate(root: str, ids: list[str], dry_run: bool) -> None:
    deck = Deck(root)
    briefs = todo(deck, ids)
    if not briefs:
        sys.exit("every brief already has a raw image; name ids to regenerate them")
    refs = refs_for(deck, {b["id"] for b in briefs})
    task = build_task(deck, briefs, [Path(r.name) for r in refs], "raw")
    cmd = ["codex", "exec", "-m", CODEX_MODEL, "-c", f'model_reasoning_effort="{CODEX_EFFORT}"',
           "-s", "workspace-write", "--skip-git-repo-check", "-C", str(deck.art)]
    for r in refs:
        cmd += ["-i", str(r)]
    cmd.append("-")
    if dry_run:
        print(" ".join(cmd), "<<TASK\n" + task + "\nTASK")
        return
    if not shutil.which("codex"):
        sys.exit("The Codex CLI is not installed. Install it, or run `deck.py task` and hand the task to your harness's "
                 f"Codex delegate with model {CODEX_MODEL}, reasoning effort {CODEX_EFFORT}.")
    (deck.art / "raw").mkdir(parents=True, exist_ok=True)
    result = subprocess.run(cmd, input=task, text=True, encoding="utf-8")
    made = [b["id"] for b in briefs if (deck.art / "raw" / f"{b['id']}.png").exists()]
    print(f"codex exited {result.returncode}; raw images present: {', '.join(made) or 'none'}")
    if len(made) < len(briefs) or result.returncode:
        sys.exit(1)


# ---------------------------------------------------------------- fitting art to the palette

def kmeans(lab: np.ndarray, k: int, rng: np.random.Generator, iters: int = 25) -> np.ndarray:
    sample = lab[rng.choice(len(lab), size=min(len(lab), 80_000), replace=False)]
    centres = [sample[rng.integers(len(sample))]]
    for _ in range(1, k):  # k-means++ seeding
        d = np.min(((sample[:, None, :] - np.array(centres)[None]) ** 2).sum(-1), axis=1)
        centres.append(sample[rng.choice(len(sample), p=d / d.sum())])
    centres = np.array(centres)
    for _ in range(iters):
        label = ((sample[:, None, :] - centres[None]) ** 2).sum(-1).argmin(1)
        for j in range(k):
            members = sample[label == j]
            if len(members):
                centres[j] = members.mean(0)
    return centres


def nearest_centre(lab: np.ndarray, centres: np.ndarray) -> np.ndarray:
    out = np.empty(len(lab), dtype=np.int32)
    for i in range(0, len(lab), 200_000):
        out[i:i + 200_000] = ((lab[i:i + 200_000, None, :] - centres[None]) ** 2).sum(-1).argmin(1)
    return out


def smooth(img: np.ndarray, n: int, ink: tuple[int, ...]) -> np.ndarray:
    """Majority filter over non-ink pixels (N x N); ink is neither changed nor counted."""
    if n < 2:
        return img
    cols, idx = np.unique(img.reshape(-1, 3), axis=0, return_inverse=True)
    idx = idx.reshape(img.shape[:2])
    ink_i = next((i for i, c in enumerate(cols) if tuple(c) == ink), -1)
    h, w = idx.shape
    best, best_count = np.zeros(idx.shape, dtype=np.int64), np.full(idx.shape, -1.0)
    r = n // 2
    for k in range(len(cols)):
        if k == ink_i:
            continue
        integral = np.pad((idx == k).astype(np.float64), r + 1).cumsum(0).cumsum(1)
        count = integral[n:n + h, n:n + w] - integral[:h, n:n + w] - integral[n:n + h, :w] + integral[:h, :w]
        better = count > best_count
        best[better], best_count[better] = k, count[better]
    return cols[np.where(idx == ink_i, idx, best)].astype(np.uint8)


def despeckle(img: np.ndarray) -> np.ndarray:
    h, w, _ = img.shape
    key = (img[..., 0].astype(np.int32) << 16) | (img[..., 1].astype(np.int32) << 8) | img[..., 2]
    pad = np.pad(key, 1, mode="edge")
    neigh = np.stack([pad[1 + dy:h + 1 + dy, 1 + dx:w + 1 + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx])
    out = key.copy()
    for y, x in zip(*np.nonzero((neigh != key).all(0))):
        vals, counts = np.unique(neigh[:, y, x], return_counts=True)
        out[y, x] = vals[counts.argmax()]
    return np.stack([(out >> 16) & 255, (out >> 8) & 255, out & 255], -1).astype(np.uint8)


def fit_image(src: Path, dst: Path, panel: str, palette: list[str], ink: str, crop: str = "center",
              colours: int = 32, smooth_n: int = 3) -> int:
    """Crop to the panel shape, resize to its exact pixels, reduce to flat colours, snap to the palette."""
    tw, th = map(int, panel.lower().split("x"))
    img = Image.open(src).convert("RGB")
    w, h = img.size
    if crop == "pad":  # keep the whole picture: scale it inside the panel, fill the rest with the image's corner colour
        scale = min(tw / w, th / h)
        inner = img.resize((round(w * scale), round(h * scale)), Image.Resampling.LANCZOS)
        img = Image.new("RGB", (tw, th), img.getpixel((2, 2)))
        img.paste(inner, ((tw - inner.width) // 2, (th - inner.height) // 2))
        w, h = img.size
    if w / h > tw / th:
        nw = round(h * tw / th)
        left = {"left": 0, "right": w - nw}.get(crop, (w - nw) // 2)
        img = img.crop((left, 0, left + nw, h))
    else:
        nh = round(w * th / tw)
        top = {"top": 0, "bottom": h - nh}.get(crop, (h - nh) // 2)
        img = img.crop((0, top, w, top + nh))
    pixels = np.asarray(img.resize((tw, th), Image.Resampling.LANCZOS)).reshape(-1, 3)
    pal_rgb = np.array([rgb_of(x) for x in palette], dtype=np.uint8)
    pal_lab = oklab(pal_rgb)
    ink_rgb = np.array(rgb_of(ink), dtype=np.uint8)
    lab = oklab(pixels)
    centres = kmeans(lab, colours, np.random.default_rng(7))
    snapped = pal_rgb[((centres[:, None, :] - pal_lab[None]) ** 2).sum(-1).argmin(1)]
    snapped[centres[:, 0] < oklab(ink_rgb)[0] + INK_MARGIN] = ink_rgb
    out = snapped[nearest_centre(lab, centres)].reshape(th, tw, 3)
    out = despeckle(smooth(out, smooth_n, tuple(int(v) for v in ink_rgb)))
    Image.fromarray(out).save(dst, optimize=True)
    return len(np.unique(out.reshape(-1, 3), axis=0))


def cmd_fit(root: str, ids: list[str]) -> None:
    deck = Deck(root)
    palette, ink = list(deck.colours().values()), deck.ink()
    for b in pick(deck.briefs(), ids):
        raw = deck.art / "raw" / f"{b['id']}.png"
        if not raw.exists():
            print(f"{b['id']}: no raw image yet ({raw})")
            continue
        n = fit_image(raw, deck.art / f"{b['id']}.png", b["panel"], palette, ink, b.get("crop", "center"),
                      int(b.get("flat_colours", 32)))
        print(f"{b['id']}: art/{b['id']}.png {b['panel']}, {n} colours")


# ---------------------------------------------------------------- colour check

def colours_in(path: Path) -> tuple[dict[str, int], int]:
    """Colours a file uses: {hex: pixel count} (count 0 for text files) and total opaque pixels."""
    if path.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
        img = np.asarray(Image.open(path).convert("RGBA"))
        opaque = img[img[..., 3] >= 128][:, :3]
        cols, counts = np.unique(opaque, axis=0, return_counts=True)
        return {hex_of(c): int(n) for c, n in zip(cols, counts)}, len(opaque)
    text = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8"), flags=re.S)
    found = {m.upper() if len(m) == 7 else "#" + "".join(ch * 2 for ch in m[1:]).upper()
             for m in re.findall(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b", text)}
    found |= {hex_of(m) for m in re.findall(r"rgba?\(\s*(\d+)[ ,]+(\d+)[ ,]+(\d+)", text)}
    return {c: 0 for c in found}, 0


def check_colours(deck: Deck) -> int:
    deck_set = set(deck.colours().values())
    files = [*sorted(p for p in deck.art.glob("*.png")), deck.root / "theme.css", *deck.slide_files()]
    problems = 0
    for name, hex_ in deck.role_hex().items():
        if hex_ not in deck_set:
            print(f"palette role {name} = {hex_} is not in the deck's colour set")
            problems += 1
    for p in files:
        if not p.exists():
            print(f"{p.relative_to(deck.root)}: missing")
            problems += 1
            continue
        found, total = colours_in(p)
        off = sorted(c for c in found if c not in MAP)
        outside = sorted(c for c in found if c in MAP and c not in deck_set)
        if off or outside:
            share = f" ({sum(found[c] for c in off) / total:.2%} of pixels)" if total else ""
            print(f"{p.relative_to(deck.root)}: {len(off)} off-palette{share}, {len(outside)} outside the deck set")
            for c in off[:8]:
                print(f"    {c} is not a map colour; nearest {nearest_map(c)}")
            for c in outside:
                print(f"    {c} ({MAP[c]}) is a map colour but not in this deck's set")
            problems += 1
    for slide in deck.slide_files():
        if slide.exists():
            for src in re.findall(r'<img[^>]*\ssrc="([^"]+)"', slide.read_text(encoding="utf-8")):
                if not (deck.root / src).exists():
                    print(f"{slide.stem}: picture {src} is missing (generate and fit it, see references/art.md)")
                    problems += 1
    print(f"colours: {len(files)} files checked, {'no problems' if not problems else f'{problems} with problems'}")
    return problems


def cmd_check(root: str) -> None:
    sys.exit(1 if check_colours(Deck(root)) else 0)


# ---------------------------------------------------------------- render, layout probe, PDF

PROBE = r"""
(limitWithFooter) => {
  const out = {};
  const textSel = 'h1, h2, h3, h4, p, li, td, th, pre, figcaption, span';
  for (const s of document.querySelectorAll('section.slide')) {
    const issues = [];
    const sr = s.getBoundingClientRect();
    const rel = r => ({x: r.left - sr.left, y: r.top - sr.top, w: r.width, h: r.height});
    const hasFooter = !!s.querySelector('.footer');
    const limit = hasFooter ? limitWithFooter : 952;
    const arts = [...s.querySelectorAll('img')].map(i => rel(i.getBoundingClientRect()));
    const say = (el, what) => issues.push(`${what}: "${el.textContent.trim().replace(/\s+/g, ' ').slice(0, 48)}"`);
    for (const el of s.querySelectorAll(textSel)) {
      if (!el.textContent.trim() || el.closest('aside')) continue;
      const cs = getComputedStyle(el), r = rel(el.getBoundingClientRect());
      if (el.matches('h1,h2,h3,h4,p,li,td,th,pre') && parseFloat(cs.fontSize) < 24) say(el, `text under 24px (${cs.fontSize})`);
      if (el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 1 && cs.overflow !== 'visible')
        say(el, 'text overflows its box');
      if (!el.closest('.footer') && r.y + r.h > limit + 1 && el.matches('h1,h2,h3,h4,p,li,td,th,pre'))
        say(el, `past the bottom margin (${Math.round(r.y + r.h)} > ${limit})`);
      if (el.matches('h1,h2,h3,h4,p,li,td,th,pre')) {
        for (const a of arts) {
          if (r.x < a.x + a.w && r.x + r.w > a.x && r.y < a.y + a.h && r.y + r.h > a.y) { say(el, 'text overlaps a picture'); break; }
        }
      }
      // words: mid-word breaks, and a heading's last line holding one word
      const words = [], range = document.createRange();
      const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const n = walker.currentNode, re = /\S+/g; let m;
        while ((m = re.exec(n.textContent))) {
          range.setStart(n, m.index); range.setEnd(n, m.index + m[0].length);
          const rects = range.getClientRects();
          if (rects.length > 1) say(el, `word breaks mid-word ("${m[0]}")`);
          if (rects.length) words.push(rects[0].top);
        }
      }
      if (el.matches('h1,h2') && words.length > 2) {
        const tops = [...new Set(words.map(t => Math.round(t)))];
        if (tops.length > 1 && words.filter(t => Math.round(t) === tops[tops.length - 1]).length === 1)
          say(el, 'last line of the title is a single word');
      }
      for (const prop of ['boxShadow', 'textShadow']) if (cs[prop] && cs[prop] !== 'none') say(el, `${prop} blends colours`);
    }
    for (const el of s.querySelectorAll('*')) {
      const cs = getComputedStyle(el);
      if (parseFloat(cs.opacity) < 1) issues.push(`opacity ${cs.opacity} on <${el.tagName.toLowerCase()}> blends colours`);
      if (cs.backgroundImage && cs.backgroundImage.includes('gradient')) issues.push(`gradient on <${el.tagName.toLowerCase()}> blends colours`);
    }
    out[s.id] = {issues: [...new Set(issues)],
                 art: [...s.querySelectorAll('img')].map(i => ({...rel(i.getBoundingClientRect()), loaded: i.naturalWidth > 0}))};
  }
  return out;
}
"""


def assemble(deck: Deck) -> str:
    fonts = "".join(f'<link rel="stylesheet" href="{u}">' for u in deck.meta.get("fonts", []))
    footer = deck.meta.get("footer", "")
    body = []
    for n, path in enumerate(deck.slide_files(), 1):
        html = path.read_text(encoding="utf-8").strip()
        if footer and "no-footer" not in html.split(">", 1)[0]:
            note = f'<p class="footer">{footer.replace("{n}", str(n)).replace("{total}", str(len(deck.slide_files())))}</p>'
            html = re.sub(r"(<aside\b|</section>)", note + r"\1", html, count=1)
        body.append(html)
    base = deck.root.as_uri() + "/"
    return (f'<!doctype html><html><head><meta charset="utf-8"><base href="{base}">'
            f'<title>{deck.meta["title"]}</title>{fonts}<link rel="stylesheet" href="theme.css"></head>'
            f'<body>{"".join(body)}</body></html>')


def launch(pw):
    for kwargs in ({"channel": "msedge"}, {"channel": "chrome"}, {}):
        try:
            return pw.chromium.launch(**kwargs)
        except Exception:
            continue
    sys.exit("No browser found for rendering. Run: uv run --with playwright playwright install chromium "
             "(on Linux add --with-deps).")


def verify_pdf(pdf: Path, layout: dict) -> list[str]:
    """Render the PDF at 1920 px wide, as the SneakySlideDecks upload page does, and check the pictures' pixels."""
    import pymupdf as fitz
    problems = []
    doc = fitz.open(pdf)
    for page, (sid, info) in zip(doc, layout.items()):
        scale = 1920 / page.rect.width
        pix = page.get_pixmap(matrix=fitz.Matrix(scale, scale))
        img = np.frombuffer(pix.samples, np.uint8).reshape(pix.height, pix.width, pix.n)[..., :3]
        for a in info["art"]:
            x, y = int(round(a["x"])) + 1, int(round(a["y"])) + 1  # 1 px inset: edges blend with the page
            region = img[y:y + int(a["h"]) - 2, x:x + int(a["w"]) - 2].reshape(-1, 3)
            if not len(region) or not a.get("loaded", True):
                continue
            cols, counts = np.unique(region, axis=0, return_counts=True)
            off = sum(int(n) for c, n in zip(cols, counts) if hex_of(c) not in MAP) / len(region)
            if off > 0.001:
                problems.append(f"{sid}: {off:.2%} of a picture's pixels left the map palette in the PDF")
    if len(doc) != len(layout):
        problems.append(f"PDF has {len(doc)} pages for {len(layout)} slides")
    return problems


def cmd_build(root: str) -> None:
    from playwright.sync_api import sync_playwright
    deck = Deck(root)
    status = 1 if check_colours(deck) else 0
    deck.build.mkdir(exist_ok=True)
    previews = deck.build / "previews"
    previews.mkdir(exist_ok=True)
    for old in previews.glob("*.png"):  # clear, not rmtree: Windows refuses to remove a folder a shell is in
        old.unlink()
    page_html = deck.root / ".deck.html"  # beside theme.css and art/, so relative paths resolve
    page_html.write_text(assemble(deck), encoding="utf-8")
    slug = re.sub(r"[^A-Za-z0-9]+", "-", deck.meta["title"]).strip("-") or "deck"
    pdf = deck.build / f"{slug}.pdf"
    try:
        with sync_playwright() as pw:
            browser = launch(pw)
            page = browser.new_page(viewport={"width": 1920, "height": 1080})
            page.goto(page_html.as_uri(), wait_until="networkidle")
            page.evaluate("document.fonts.ready")
            layout = page.evaluate(PROBE, 920)
            for sid in deck.meta["slides"]:
                page.locator(f"section.slide#{sid}").screenshot(path=str(previews / f"{sid}.png"))
            page.pdf(path=str(pdf), width="1920px", height="1080px", print_background=True,
                     prefer_css_page_size=True)
            browser.close()
    finally:
        page_html.unlink(missing_ok=True)
    missing = [sid for sid in deck.meta["slides"] if sid not in layout]
    for sid in missing:
        print(f"{sid}: slides/{sid}.html has no <section class=\"slide\" id=\"{sid}\">")
    issues = 0
    for sid, info in layout.items():
        for issue in info["issues"]:
            print(f"{sid}: {issue}")
            issues += 1
    pdf_problems = verify_pdf(pdf, layout)
    for p in pdf_problems:
        print(p)
    print(f"layout: {len(layout)} slides, {issues} problem(s); previews in {previews}")
    print(f"pdf: {pdf} ({pdf.stat().st_size // 1024} KB), {'pictures verified exact' if not pdf_problems else 'see above'}")
    sys.exit(1 if status or issues or pdf_problems or missing else 0)


# ---------------------------------------------------------------- command line

def main(argv: list[str]) -> None:
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return
    cmd, rest = argv[0], argv[1:]
    flags = {a: rest[i + 1] for i, a in enumerate(rest) if a.startswith("--") and i + 1 < len(rest)
             and not rest[i + 1].startswith("--") and a not in ("--dry-run",)}
    plain = [a for i, a in enumerate(rest) if not a.startswith("--") and not (i and rest[i - 1] in flags)]
    if cmd == "init" and len(plain) == 1 and "--title" in flags:
        cmd_init(plain[0], flags["--title"])
    elif cmd == "bases":
        cmd_bases()
    elif cmd == "palette" and len(plain) >= 2:
        cmd_palette(plain[0], plain[1:], flags.get("--ink"),
                    [int(s) for s in flags.get("--shades", "255,220,180,135").split(",")])
    elif cmd == "task" and plain:
        cmd_task(plain[0], plain[1:])
    elif cmd == "generate" and plain:
        cmd_generate(plain[0], plain[1:], "--dry-run" in rest)
    elif cmd == "fit" and plain:
        cmd_fit(plain[0], plain[1:])
    elif cmd == "check" and len(plain) == 1:
        cmd_check(plain[0])
    elif cmd == "build" and len(plain) == 1:
        cmd_build(plain[0])
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
