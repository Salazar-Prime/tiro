# Voice Type icon concepts

These are retained 1024×1024 concept explorations. The production icon now comes from `../Apple glass icon design/Voxpen App Icon.dc.html`; its extracted vector master is `../AppIcon.svg`, and `../AppIcon.icns` is generated from that master.

## Concepts

- **Pip** (`pip.png`) — A small bat with oversized listening ears. Its echolocation waveform ends as a typing caret. This is the most distinctive, friendly direction.
- **Ibis** (`ibis.png`) — An ibis with a beak that suggests a pen nib, referencing Thoth and the long association between the ibis, language, and writing. Throat echo marks and a caret connect voice to text.
- **Voxpen** (`voxpen.png`) — A voice capsule and fountain-pen nib fused into one object. This is the clearest direction at a glance and became the basis of the production glass icon.

To switch the bundled icon:

```sh
./Scripts/build-icon.sh Resources/AppIconConcepts/ibis.png
```

## Name shortlist

1. **Pip** — Short, warm, and tied to a small sound and the bat concept.
2. **Amanu** — From *amanuensis*, a person who writes down dictated words.
3. **Ibis** — A compact lore-based name tied to language and writing.
4. **VoxScribe** — The clearest promise: voice in, writing out.
5. **Murmur** — Quiet, ambient, and appropriate for a menu-bar utility.
6. **Sotto** — Suggests speech and unobtrusiveness through *sotto voce*.
7. **Saywrite** — Plain-language and immediately understandable.
8. **Quillwave** — A more descriptive name for the pen-and-audio idea.

These are creative directions, not trademark, domain, or App Store availability clearances.

## Generation prompts

The images were generated with the built-in image-generation tool, then resized to Apple's 1024×1024 master size.

### Ibis

> Create an original app icon symbol for a voice-typing utility. The concept is an ibis, a subtle reference to Thoth and the history of language and writing: a simplified ibis head and curved neck in profile, with its long beak transforming cleanly into a fountain-pen nib. Two compact rounded sound-wave arcs near the throat convey voice input, and a single small vertical caret at the beak tip conveys typed output. Use crisp, vector-like, flat artwork on a full-bleed midnight graphite square, with coral for the ibis and aqua for the sound arcs and caret. Keep the mark centered, bold, rounded, simple, and readable at 32 px. Use flat opaque fills with no text, outer-corner mask, border, gloss, shadows, translucency, baked specular highlights, mockup, or watermark.

### Pip

> Create an original icon for a voice-typing utility featuring a tiny friendly bat called Pip. Use a simple face-and-ears silhouette rather than a full body: two very large rounded ears represent listening, two dot eyes, and a small mouth emits one compact aqua waveform that resolves into a vertical typing caret. The bat should feel like a clever nocturnal scribe familiar, charming but mature. Use crisp, vector-like, flat artwork on a full-bleed warm off-white square, with midnight graphite for the bat, coral for the inner ears, and aqua for the waveform and caret. Keep it centered, bold, frontal, simple, and readable at 32 px. Use flat opaque fills with no text, outer-corner mask, border, fur, fangs, gloss, shadows, translucency, baked specular highlights, mockup, or watermark.

### Voxpen

> Create an original app icon symbol for a voice-typing utility: one compact object that merges a voice-recorder capsule with a fountain-pen nib. The top is a broad rounded capsule with three bold waveform bars cut into it; the bottom tapers into a simplified pen nib whose slit ends as a small vertical typing caret. The transition should feel like speech physically turning into writing. Use crisp, vector-like, flat artwork on a full-bleed coral square, with warm off-white for the object, midnight graphite for the waveform cutouts and nib slit, and aqua for the caret. Keep it centered, bold, frontal, simple, and readable at 16–32 px. Use flat opaque fills with no text, outer-corner mask, border, gloss, shadows, translucency, baked specular highlights, mockup, or watermark.

## Apple-guideline decisions

- 1024×1024 square source artwork; the system owns the rounded mask.
- One centered symbol with breathing room and a strong small-size silhouette.
- Rounded, heavy geometry instead of thin lines or tiny sharp details.
- Flat, opaque source art so Icon Composer or the system can add material effects.
- No pre-rendered Liquid Glass, bevels, specular highlights, or drop shadows.
