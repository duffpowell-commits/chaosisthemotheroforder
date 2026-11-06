# Style Guide

> The look of *Chaos Is the Mother of Order*, derived from the theme: a modern
> police state shot like war photojournalism, with color returning as people
> take their streets back. Every render and every screen gets checked against
> this page. UI values match the code (`game.gd`, `tactical.gd` color consts);
> faction ring colors are new and get added to the code in J1.

## 1. The idea in one line

**The regime is grey and faceless; the movement is the only warm color on the
street.** Color is a reward: it comes back as districts are liberated.

## 2. Three layers, three looks

| Layer | Look | Reference |
|---|---|---|
| **World** (streets, tactical map) | Low-poly 3D under the **Frontline** grade: near-monochrome, grain, crushed blacks, harsh sodium and flash light. Color returns with liberation. | Nachtwey, McCullin, Capa; XCOM's night maps |
| **Propaganda** (posters, state TV, pirate radio, menus) | **Woodcut**: paper, ink, two or three flat colors, hand-cut type. | Soviet and Spanish Civil War posters; Papers, Please |
| **Units** (tactical) | **Readable first** (Advance Wars): faction color, ring under each unit, chunky silhouette. If we fall back to sprites: **pixel**, 28 colors, 1px dark outline. | Advance Wars, FFT |

## 3. Palette

**Factions (must never be confused):**
- Regime: cold blue-grey. Uniform `#1A1F2B`, visor glint `#6A8CB3`, ring `#4F7FBF`.
- Movement: red. Bandana/armband `#9E1A14`, ring `#E05A46` (`C_RED`, tactical).
- Neutral civilians: desaturated brown/olive, no ring.

**UI (from the code):**
| Name | Hex | Use |
|---|---|---|
| `C_BG` | `#0E1013` | screen background |
| `C_PANEL` | `#171A1F` | panels, HUD bars |
| `C_LINE` | `#2C3139` | dividers |
| `C_FG` | `#E7E3DA` | main text |
| `C_MUTED` | `#9B988F` | secondary text, disabled |
| `C_ACCENT` | `#E2713B` | selected unit, the one thing to look at |
| `C_RED` | `#C8372D` (UI) / `#E05A46` (map) | danger, alarm, damage |
| `C_GOOD` | `#6FA36B` | success, exits, defections |
| `C_PAPER` / `C_INK` | `#E9E0CC` / `#1B1714` | woodcut propaganda layer |

**Map overlays:** move range blue `rgba(77,158,255,0.32)`, sneak violet
`rgba(158,107,255,0.36)`, exit green `rgba(115,217,115,0.30)`.

**Rules:**
- Accent orange means "your attention here." Use it once per screen.
- Red means danger or the movement. Never use it for decoration.
- In regime-held districts, everything except faction markers and UI stays
  near-grey. Liberation warms the grade, never the UI.

## 4. Type and touch
- One sans family for UI. Sizes: 18 body, 24 headers, 32+ titles and alerts.
- Woodcut screens use a heavy display face for headlines only.
- **Touch targets at least 48 px.** Nothing depends on hover.
- Text on the map always has an outline or a panel behind it.

## 5. Readability rules (the Advance Wars test)
1. **Every unit has a faction ring.** Units must read against crates, barrels
   and shadow at tactical zoom.
2. **Labels never stack.** When units bunch up, collapse names to pips or offset
   them. (Autoplay caught this on Nov 6.)
3. **Show the math before the commit:** hit %, outcome on hit, noise cost.
4. **Show the threat:** a tapped guard shows where he can move and shoot.
5. **The grade serves the board.** On the tactical map the grain and black
   crush are lighter than on the street renders.

## 6. Faces
- No modeled faces carry emotion. The regime wears helmets and visors; the
  movement wears bandanas, caps and respirators.
- Emotion lives in the **dialogue portraits** and the writing.

## 7. Motion
- Moves 0.12 s per tile (0.2 sneaking). Enemy turn about 1.5 s in total,
  skippable.
- Big moments (defection, broadcast airing, a death) get one beat of camera
  push-in, never more than a second.

## 8. How renders get checked
Before a visual change merges: real engine renders in `docs/renders/`, the
autoplay GIF for tactical changes, and the independent design review checks
them against sections 3–5 of this page.
