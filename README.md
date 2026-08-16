<p align="center">
  <img src="Resources/AppIcon.png" width="144" alt="Tiro blueprint icon">
</p>

<h1 align="center">Tiro</h1>

<p align="center">
  <img
    src="https://readme-typing-svg.demolab.com?font=SF+Mono&amp;size=20&amp;duration=2800&amp;pause=900&amp;color=2F6B5D&amp;center=true&amp;vCenter=true&amp;width=720&amp;lines=Tiro+can+transcribe+for+you%E2%80%94wherever+you+type.;Hold+the+shortcut.+Speak.+Release.+Keep+typing."
    alt="Tiro can transcribe for you—wherever you type."
  >
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-public_beta-2f6b5d" alt="Public beta">
  <img src="https://img.shields.io/badge/macOS-14%2B-1f2937" alt="macOS 14 or newer">
  <img src="https://img.shields.io/badge/architecture-Apple_silicon-1f2937" alt="Apple silicon">
  <img src="https://img.shields.io/badge/Swift-6-f05138" alt="Swift 6">
</p>

<p align="center"><a href="https://github.com/Salazar-Prime/tiro/releases">Download the public beta</a></p>

Tiro is a native macOS menu-bar app that turns speech into text wherever your cursor is active. It briefly pauses active media and mutes system output while recording, transcribes the finished audio with OpenAI or locally with whisper.cpp, then inserts the result into the focused app.

Tiro can also capture the usable screen or a dragged selection from its menu-bar menu. Screenshots are saved as PNG files in `Pictures/Tiro screenshots`, pasted into the previously focused app when it accepts images, and saved in history as readable local paths. While the microphone is listening, press <kbd>S</kbd> by itself to append one or more screenshots to that transcript.

Screenshot paths are surrounded with single quotes by default. The Screenshots settings page can disable wrapping or replace the text before and after each path with any custom text.

## See it in action

<p align="center">
  <img src="docs/demos/voice-typing/voice-typing.gif" alt="Tiro transcribing speech directly into Sublime Text">
</p>

## Shortcuts

These are the defaults. Every route can be changed in Tiro’s Settings; voice typing can use either a modifier-only chord or modifiers plus a regular key.

Opening transcript history is also available as an optional global shortcut. Assign it from the Shortcuts page in Settings.

| Gesture | Result |
| --- | --- |
| Hold <kbd>Control</kbd> + <kbd>Option</kbd> | Record; release to transcribe and insert |
| Double-tap <kbd>Control</kbd> + <kbd>Option</kbd> | Lock recording hands-free |
| Press <kbd>Control</kbd> + <kbd>Option</kbd> while locked | Stop and insert |
| Press <kbd>S</kbd> while voice typing is active | Attach the usable screen to this transcript |
| <kbd>Command</kbd> + <kbd>Shift</kbd> + <kbd>2</kbd> | Capture and paste a dragged screen selection |
| <kbd>Control</kbd> + <kbd>Command</kbd> + <kbd>V</kbd> | Insert the last transcript again |

## Setup

You need macOS 14 or newer plus Microphone and Accessibility permission. Screenshot capture additionally requires Screen Recording permission. Choose a transcription engine in Settings:

- **OpenAI** uses `gpt-4o-mini-transcribe` and requires an API key with API billing enabled. The key stays in macOS Keychain.
- **On-device** uses [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and a one-time, roughly 60 MB English model download. It does not require an API key.

Public beta builds are Sparkle-signed but not yet Apple-notarized. On first launch, macOS may require you to Control-click Tiro and choose **Open**.

When installing from the DMG, drag `Tiro.app` to the Applications shortcut, then launch it from `/Applications`.

## Updates

Tiro uses Sparkle 2 for signed updates. It checks the GitHub-hosted update feed automatically, and you can run a manual check from **Check for Updates…** in the menu-bar menu.

## Build

```sh
git clone https://github.com/Salazar-Prime/tiro.git
cd tiro
./Scripts/build-app.sh
./Scripts/create-dmg.sh
open "dist/Tiro.app"
```

Move `Tiro.app` to `/Applications` before granting permissions so macOS can keep them stable across updates.

## Privacy

- Recording starts only when you use the shortcut.
- In OpenAI mode, Tiro sends the recording and any optional transcription instructions directly to OpenAI's `/v1/audio/transcriptions` endpoint using your API key. The current build uses `gpt-4o-mini-transcribe`, not the `whisper-1` model.
- In On-device mode, audio and transcription stay on your Mac. Tiro uses whisper.cpp 1.9.2 with the English `base.en` Q5 model. Optional offline vocabulary/context is an initial Whisper prompt, not post-processing.
- OpenAI handles these requests under its API data controls, which differ from ChatGPT's consumer data controls. Its current policy lists the transcription endpoint as not used for training, with no abuse-monitoring or application-state retention. See [OpenAI's API data controls](https://developers.openai.com/api/docs/guides/your-data#default-usage-policies-by-endpoint).
- Temporary audio on your Mac is deleted after the transcription request completes.
- Tiro does not send analytics, telemetry, crash reports, or application logs. Limited operational diagnostics stay in macOS's local unified log and do not include audio or transcript content.
- Transcript history stays on this Mac and can be searched, deleted, or cleared at any time.
- Screenshots are taken only when you choose a capture action and remain in your local `Pictures/Tiro screenshots` folder.
- Any temporary pasteboard content is restored and marked to keep it out of compatible clipboard-history apps.
- Sparkle contacts Tiro's GitHub-hosted update feed to check for new releases.

## Feature checklist

- [x] Paste the last transcript again with <kbd>Control</kbd> + <kbd>Command</kbd> + <kbd>V</kbd>
- [x] Browse, search, copy, delete, and clear local transcript history
- [x] Capture the visible screen without the menu bar or Dock, or drag a selection
- [x] Customize voice, paste, and screenshot shortcuts from Settings
- [x] Open searchable transcript history inside Settings or with a custom shortcut

## Development

```sh
swift test
swift build
```

Beta releases follow [APP_PUBLISH.md](APP_PUBLISH.md). Tiro uses SwiftUI/AppKit, AVFoundation, Security/Keychain, OpenAI transcription, whisper.cpp, and Sparkle 2.
