# Style anchor

Two close-up crops of approved sprite brushwork and outlines. They show the line
weight, painted shading, crosshatching and muted palette, with no face, no
identity details and no text:

- `assets/art/source/style_anchor_jacket_outline.png`: jacket sleeve, hand, shirt
  buttons and zip (cropped from `assets/characters/source/teodor_front.jpg`).
- `assets/art/source/style_anchor_trousers_boots.png`: cargo trousers, turn-ups and
  leather boots (cropped from `assets/characters/source/operative_b_back.jpg`).

Attach **one or both** to every new scene, still, ending or prop prompt, after
any character identity refs (`docs/art/identity/<name>.md`) and before any
layout reference.

## Standard scene preamble (paste at the top of every scene prompt)

```
Match ONLY the painting technique and palette of the attached style-anchor crops: semi-realistic painted graphic-novel / comic art, dark ink outlines slightly heavier on silhouettes, diagonal hatching in shadows and crosshatching in deep shadows, realistic painted shading, muted desaturated olive, brown, charcoal and blue-grey colour, light from the upper left. Do NOT copy any character, clothing, prop, object or composition from the style-anchor crops. Treat any attached photo reference as layout and perspective only: do not copy its people, faces, vehicles, signage, logos, text or colours. Setting: an ordinary present-day American city (see the prop bible). Movement red #9E1A14 is the only warm accent and stays small. No readable text, letters, numbers or logos anywhere. No weapons.
```

Then describe the scene, then list the props using only the approved list in
`docs/art/prop-bible.md`.

## After generation

- Check the result against the prop bible's banned list and palette notes;
  redraw on any failure.
- Run the ink pass (`ink.py`, described in `docs/art-notes.md` section 12) on
  painted scenes before resizing to 1280x720. Don't run it on woodcuts or sprites.
