# Type sheet

Real lettering is set **after** generation by `tools/letter.py`, never painted
by the image generator. The generator leaves blank type areas; `letter.py`
writes a `*_lettered.png` beside each blank original and never overwrites the
blank one, so the engine can still letter the blank version itself (for
translations or changing copy).

Run: `python3 tools/letter.py` (all pieces) or `python3 tools/letter.py <out-path>`.

## Fonts

| Role | Font | File | License |
|---|---|---|---|
| Display (titles, poster headlines, news lower third) | **Anton** Regular, a condensed poster grotesque in the woodcut-poster tradition | `assets/fonts/anton/Anton-Regular.ttf` | SIL Open Font License 1.1, `assets/fonts/anton/OFL.txt` (Google Fonts) |

Rules: all caps, slightly tracked out; one ink colour per piece (ink `#1B1714`
on movement pieces, movement red `#9E1A14` only for movement headlines, regime
blue-grey `#1A1F2B` on regime pieces, never red on regime pieces); a light
"worn print" pass (speckle and soft edge) so type sits in the woodcut.

## Copy

**Final** copy comes from the project: the game title is the project name in
`project.godot`; "Continuity" and "Unbroken" are the poster names in
`docs/art-needs.md` / the file names. Lines marked **PLACEHOLDER** are
stand-ins for the writer to replace; change them here and rerun `letter.py`.

| Piece | Block | Copy | Status |
|---|---|---|---|
| itch banner | title | CHAOS IS THE MOTHER OF ORDER | final |
| itch cover | title | CHAOS IS THE / MOTHER OF ORDER | final |
| Regime poster | headline | CONTINUITY | final (art-needs) |
| Regime poster | subline | SAFE STREETS. STEADY HANDS. | PLACEHOLDER |
| Movement poster | headline | UNBROKEN | final (file name) |
| Movement poster | subline | WE SAW IT. WE FILMED IT. | PLACEHOLDER |
| CN24 news frame | lower third | CN24 • BREAKING: OPERATION AT RAIL YARDS HOUSING | PLACEHOLDER |

Stamps and icons carry no lettering by design (they must read at 128 px).
To letter a stamp or the livestream frame later, add a piece below.

## Machine-readable spec (read by `tools/letter.py`)

Boxes are `[x0, y0, x1, y1]` in the blank image's own pixels. Text is fitted
to the largest size that fits the box (capped by `max_size`).

```json
{
  "fonts": {"display": "assets/fonts/anton/Anton-Regular.ttf"},
  "colors": {"ink": "#1B1714", "red": "#9E1A14", "blue": "#1A1F2B", "paper": "#E9E0CC"},
  "pieces": [
    {"src": "assets/art/itch/banner_960x300.png", "out": "assets/art/itch/banner_960x300_lettered.png",
     "blocks": [{"box": [190, 16, 780, 92], "text": "CHAOS IS THE MOTHER OF ORDER", "color": "ink", "tracking": 0.06}]},
    {"src": "assets/art/itch/cover_630x500.png", "out": "assets/art/itch/cover_630x500_lettered.png",
     "blocks": [{"box": [24, 10, 606, 90], "text": "CHAOS IS THE\nMOTHER OF ORDER", "color": "ink", "tracking": 0.05, "line_gap": 0.08}]},
    {"src": "assets/ui/woodcut/poster_regime_continuity.png", "out": "assets/ui/woodcut/poster_regime_continuity_lettered.png",
     "blocks": [
       {"box": [130, 815, 640, 925], "text": "CONTINUITY", "color": "blue", "tracking": 0.12},
       {"box": [160, 935, 610, 980], "text": "SAFE STREETS. STEADY HANDS.", "color": "blue", "tracking": 0.08, "placeholder": true}]},
    {"src": "assets/ui/woodcut/poster_movement_unbroken.png", "out": "assets/ui/woodcut/poster_movement_unbroken_lettered.png",
     "blocks": [
       {"box": [70, 40, 698, 175], "text": "UNBROKEN", "color": "red", "tracking": 0.1},
       {"box": [120, 185, 648, 240], "text": "WE SAW IT. WE FILMED IT.", "color": "ink", "tracking": 0.08, "placeholder": true}]},
    {"src": "assets/ui/woodcut/report_frame_cn24.png", "out": "assets/ui/woodcut/report_frame_cn24_lettered.png",
     "blocks": [{"box": [220, 638, 1060, 684], "text": "CN24 \u2022 BREAKING: OPERATION AT RAIL YARDS HOUSING", "color": "blue", "tracking": 0.05, "placeholder": true}]}
  ]
}
```
