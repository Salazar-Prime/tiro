# Voice typing README demo

This folder contains the animated walkthrough used by the project README, its
cropped source video, and an editable OpenScreen project.

The demo was freshly recorded on September 13, 2026, using Tiro's mint pill and
Sublime Text. It shows the live Listening waveform, Transcribing state, and the
actual inserted transcript. [Watch the edited video](voice-typing.mp4) or
[view the GIF](voice-typing.gif).

## Re-export

Install Node.js, FFmpeg, and [OpenScreen](https://github.com/getopenscreen/openscreen),
then run this from the repository root:

```sh
node docs/demos/voice-typing/render.mjs
```

The script resolves the project's relative media path into a temporary project,
renders the camera animation with OpenScreen, saves the edited MP4, and optimizes
the looping GIF at 1280 × 720 and 30 fps. Pass an output path to preview without
replacing the README asset:

```sh
node docs/demos/voice-typing/render.mjs /tmp/tiro-preview.gif
```

Edit the two `zoomRegions` in `voice-typing.openscreen` to change the timing or
framing. If opening that project in OpenScreen's UI, relink its video to the
adjacent `voice-typing-source.mp4` when prompted. This OpenScreen version's CLI
does not resolve relative media paths itself; the render script handles that.

The source contains only two cropped areas of the actual recording—the pill and
Sublime's active text lines—repositioned on the editor's background. No desktop,
menu bar, Dock, purple window border, audio, or clipboard-history window is
included. The text insertion and pill animations come from the recording.

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
2. Make one direct one-second pan into a 3.5× close-up of the Sublime title and
   active text lines as the transcript appears.

Keep the regions one second apart so OpenScreen connects them with a smooth pan.
Move away before **Paste sent** so it does not distract from the text reveal.
Keep the final close-up fixed until the loop ends. Trim the result before any
menu or transcript-history window opens. Export at 30 fps to retain the
Listening waveform, Transcribing dots, and smooth camera movement.

### Recording a new take

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

If OpenScreen's CLI reports “Failed to get sources,” use macOS's
<kbd>Command</kbd> + <kbd>Shift</kbd> + <kbd>5</kbd> recorder for the source take,
then use OpenScreen for the edit and export. This demo used that fallback.
