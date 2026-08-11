# Voice Type

Voice Type is a tiny, native macOS voice-typing utility. Hold <kbd>Control</kbd> + <kbd>Option</kbd>, speak, and release: Voice Type pauses active media, mutes system output while it records, sends the completed recording to OpenAI, and inserts the transcript into the focused text field.

The app lives in the menu bar and shows a small signal capsule at the right edge of the active screen while it listens.

After the initial installation, Voice Type checks its signed GitHub update feed automatically. You can also choose **Check for Updates…** from the menu-bar icon.

## Shortcuts

| Gesture | Result |
| --- | --- |
| Hold <kbd>Control</kbd> + <kbd>Option</kbd> | Record while held; transcribe and insert on release |
| Double-tap <kbd>Control</kbd> + <kbd>Option</kbd> | Lock recording hands-free |
| Press <kbd>Control</kbd> + <kbd>Option</kbd> while locked | Stop, transcribe, and insert |
| <kbd>Control</kbd> + <kbd>Command</kbd> + <kbd>V</kbd> | Insert the last Voice Type transcript again |

Transcripts are saved in Voice Type's on-device history. Regular <kbd>Command</kbd> + <kbd>V</kbd> keeps working as usual, while <kbd>Control</kbd> + <kbd>Command</kbd> + <kbd>V</kbd> inserts the latest saved transcript. If direct Accessibility insertion is unavailable in the focused app, Voice Type briefly bridges the transcript through the macOS pasteboard, invokes the target app's native Paste command, and restores the prior pasteboard contents. The bridge is local-only and marked transient and auto-generated so compatible clipboard-history apps do not retain it.

Automatic insertion always uses the active application, focused text field, and cursor position when transcription finishes. Voice Type does not return to the field where recording started.

## Requirements

- macOS 14 or newer
- An OpenAI API key with API billing enabled
- Microphone and Accessibility permission

Voice Type uses the `gpt-4o-mini-transcribe` model with English language guidance and an editable transcription prompt. It uses the `/v1/audio/transcriptions` endpoint described in the [official OpenAI documentation](https://developers.openai.com/api/docs/guides/speech-to-text). The API key is stored in macOS Keychain and is never committed to the repository.

## Build and run

```sh
git clone https://github.com/Salazar-Prime/voice-type.git
cd voice-type
./Scripts/build-app.sh
open "dist/Voice Type.app"
```

On first launch:

1. Paste an OpenAI API key into the settings window and choose **Save**.
2. Grant Microphone access.
3. Grant Accessibility access. If macOS asks, relaunch Voice Type afterward.

For stable macOS privacy permissions, move `Voice Type.app` from `dist` into `/Applications` before granting access.

The build script uses the `VOICE_TYPE_SIGNING_IDENTITY` environment variable when supplied. On the primary development Mac it otherwise uses the local **Voice Type Local Signing** identity so Accessibility and microphone approvals survive updates. Public distribution should use an Apple Developer ID Application identity.

## Privacy behavior

- Recording starts only for the configured shortcut gesture.
- An active macOS Now Playing session is paused during recording and resumed only if Voice Type paused it. Output mute and volume controls—including aggregate-device subchannels—are restored to their exact previous values when recording stops or is cancelled.
- Audio is uploaded to OpenAI after recording stops; this first version does not stream partial audio.
- Each temporary `.m4a` recording is deleted after the request completes.
- Transcript history is stored on this Mac in the user's Application Support folder and can be copied, deleted individually, or cleared from the menu-bar app.
- Voice Type restores the prior system pasteboard after using it as a short-lived, local-only compatibility bridge in apps that reject direct Accessibility insertion. The temporary content is marked transient and auto-generated for clipboard-history apps.

## Development

```sh
swift test
swift build
```

Beta releases follow [APP_PUBLISH.md](APP_PUBLISH.md). To prepare a signed Sparkle archive and update the appcast after incrementing both bundle versions and writing `RELEASE_NOTES.md`:

```sh
./Scripts/prepare-update.sh
```

The app uses SwiftUI/AppKit, AVFoundation, the macOS Accessibility API, Security/Keychain, and Sparkle 2 for signed in-app updates.
