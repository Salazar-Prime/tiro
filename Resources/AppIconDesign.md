# Tiro production app icon

The production icon is derived from the `Final` SVG composition in `Apple glass icon design/Voxpen App Icon.dc.html`.

## Canonical and generated files

- `AppIcon.svg` — canonical vector master extracted from the supplied design at its default `markScale` of `0.78` and `tipColor` of `#f0b845`.
- `AppIcon.png` — generated 1024×1024 RGBA render.
- `AppIcon.iconset/` — generated macOS size ladder from 16×16 through 512×512@2x.
- `AppIcon.icns` — generated icon bundle copied into the application resources.

Regenerate all raster assets and the `.icns` file with:

```sh
./Scripts/build-icon.sh
```

The concept images under `AppIconConcepts/` are retained for design history but are not used by the app build.
