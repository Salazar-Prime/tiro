# Voxpen color and style variants

Each file is a 1024×1024 unmasked source master generated from `../voxpen.png` with the built-in image-generation tool.

## Variants

- **Night Signal** (`night-signal.png`) — Midnight navy, coral, ice, and aqua. Best balance of personality, clarity, and continuity with the app UI.
- **Cobalt Glass** (`cobalt-glass.png`) — Cobalt/indigo with icy glass and an acid-lime caret. The most expressive Liquid Glass direction.
- **Editorial Ink** (`editorial-ink.png`) — Parchment, oxblood, plum, and mustard. Warm, literary, and distinctive.
- **Phosphor** (`phosphor.png`) — Forest black, luminous mint, and amber. Focused and technical.
- **Phosphor Amber Channel** (`phosphor-amber-channel.png`) — A preserved Phosphor refinement: the mint nib remains while only its keyhole-shaped center channel is amber.
- **Ink Mono** (`ink-mono.png`) — Warm white, near-black, and vermilion. The most timeless and legible.

To make a variant the bundled app icon:

```sh
./Scripts/build-icon.sh Resources/AppIconConcepts/VoxpenVariants/night-signal.png
```

## Final prompt set

All prompts treated `../voxpen.png` as the edit target and preserved its symbol, proportions, placement, padding, and unmasked square canvas.

### Night Signal

> Recolor and restyle the Voxpen icon as “Night Signal.” Use a full-bleed deep midnight navy background (`#081522`), a warm coral Voxpen body (`#FF7569`), pale ice waveform cutouts and nib slit (`#EAFBF8`), and a bright aqua terminal caret (`#63E3D7`). Use a premium flat vector-like treatment with only a soft light-to-dark background gradient. Keep one centered icon with bold rounded geometry readable at 32 px. No text, border, corner mask, new symbols, mockup, watermark, photorealism, perspective, bevel, heavy gloss, or dramatic shadow.

### Cobalt Glass

> Restyle the Voxpen icon as “Cobalt Glass.” Use a full-bleed cobalt-to-indigo gradient (`#155EEF` to `#3422A8`), a pale icy-cyan Voxpen body with restrained translucency, deep indigo waveform bars and nib slit, and an acid-lime terminal caret (`#D9FF6A`). Use a simple frontal frosted-glass treatment suitable for Apple’s current layered icon language, with minimal controlled edge highlights. Keep the mark readable at 32 px. No text, border, corner mask, new symbols, mockup, watermark, chrome, hard bevel, heavy shadow, realistic perspective, or excessive refraction.

### Editorial Ink

> Restyle the Voxpen icon as “Editorial Ink.” Use a full-bleed warm parchment background (`#F1E5CE`), deep oxblood Voxpen body (`#7A263A`), near-black plum waveform bars and nib slit (`#21151B`), and a muted mustard terminal caret (`#E1A72E`). Use a sophisticated mid-century editorial print treatment with nearly flat inks and extremely subtle paper grain. Keep the silhouette crisp and readable at 32 px. No text, border, corner mask, new symbols, mockup, watermark, rough edges, heavy halftone, retro illustration, perspective, or thick shadows.

### Phosphor

> Recolor and restyle the Voxpen icon as “Phosphor.” Use a full-bleed near-black forest-green background (`#071C18`) with a barely perceptible radial lift, a luminous mint Voxpen body (`#9AF4C0`), matching dark waveform bars and nib slit, and a warm amber terminal caret (`#FFC857`). Use a bold flat signal-display treatment that feels polished and slightly technical. Keep the mark readable at 32 px. No text, border, corner mask, new symbols, mockup, watermark, neon halos, scan lines, pixel art, body gradients, perspective, or bevels.

### Ink Mono

> Recolor and restyle the Voxpen icon as “Ink Mono.” Use a full-bleed warm-white background (`#F7F5EF`), near-black Voxpen body (`#121212`), matching warm-white waveform bars and nib slit, and one vivid vermilion terminal caret (`#FF4E3D`). Use a timeless Swiss-modern treatment with crisp, flat, opaque fills. Keep the mark readable at 16–32 px. No text, border, corner mask, new symbols, mockup, watermark, gradients, glow, texture, shadows, perspective, or bevels.

### Phosphor Amber Channel refinement

> Change only the narrow central fountain-pen channel in `phosphor.png`. Recolor the round bulb/breather hole and the narrow vertical slit attached beneath it, continuing through the point and terminal extension, as one continuous warm amber (`#FFC857`) keyhole shape. Keep the full outer Voxpen body—including the complete broad pointed nib—mint (`#9AF4C0`). Preserve the dark forest (`#071C18`) background, five upper waveform bars, silhouette, waist, gradients, centering, scale, padding, and unmasked canvas. Do not fill the broad lower nib or make any other change.
