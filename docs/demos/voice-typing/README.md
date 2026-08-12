# Voice typing README demo

This folder contains the animated walkthrough used by the project README.

## Walkthrough

The demo should show one complete Tiro interaction in about 8–12 seconds:

1. Start with a blank Sublime Text document focused.
2. Hold <kbd>Control</kbd> + <kbd>Option</kbd> to begin recording.
3. Say one short sentence.
4. Release the shortcut.
5. Leave the inserted transcript visible for two seconds.

## Capture with OpenScreen

Use OpenScreen's app to record the entire display containing Sublime Text. Tiro's
recording indicator is a separate window, so a Sublime-only window capture may
leave it out. The published composition must crop out the macOS menu bar, Dock,
desktop, and every app other than Sublime Text.

Use two connected OpenScreen zoom regions:

1. Isolate Tiro's pill on the editor's clean dark background and open at 5×.
   Keep this shot fixed from **Listening** through **Transcribing**; do not show
   Sublime's purple window edge.
2. Make one direct one-second pan into a 2.2× close-up of the Sublime title and
   active text lines as the transcript appears.

Keep the regions one second apart so OpenScreen connects them with a smooth pan.
Freeze the last **Transcribing** pill frame during that pan so the intermediate
**Paste sent** state does not distract from the text reveal. Trim the result
before any menu or transcript-history window opens, then export it as
`voice-typing.gif` in this folder using the medium size at 30 fps. The higher
frame rate keeps the Listening waveform, Transcribing dots, and camera pan
smooth.

### CLI alternative

The installed OpenScreen app includes a command-line recorder and GIF exporter:

```sh
OPENSCREEN="/Applications/Openscreen.app/Contents/MacOS/Openscreen"

"$OPENSCREEN" record \
  --display 0 \
  --duration 15 \
  --project /tmp/tiro-voice-typing.openscreen \
  --json

"$OPENSCREEN" export \
  /tmp/tiro-voice-typing.openscreen \
  --out docs/demos/voice-typing/voice-typing.gif \
  --gif-fps 30 \
  --gif-size medium \
  --json
```

Before recording, give OpenScreen Screen Recording and Accessibility access in
System Settings. Keep the final GIF under 10 MB so the README remains quick to
load.
