# HoldSpeak

Hold a global hotkey, speak, release to transcribe, then paste into the currently focused text field (clipboard is restored after paste).

## Defaults (MVP)

- Hotkeys (global):
  - Normal: hold `Control + Option + Space` → release → paste transcript
  - Prompted: hold `Control + Option + Command + Space` → release → prompt + paste result
- Behavior: record while held → transcribe on release → paste once
- Default models:
  - Transcription: `gpt-4o-mini-transcribe`
  - Prompt: `gpt-4.1-nano`

Your OpenAI API key is stored in the **macOS Keychain** on the machine where you configure it.

## Quick start (core package)

```bash
swift build
swift run TranscribeHoldPasteCLI --help
```

## Build the macOS app bundle

```bash
./scripts/build-macos-app.sh
open ./build/HoldSpeak.app
```

## Install to /Applications (recommended for permissions)

```bash
./scripts/install-to-applications.sh
open /Applications/HoldSpeak.app
```

## Package for a friend

```bash
./scripts/package-for-friend.sh
```

This creates `dist/HoldSpeak-friend.zip`. Include `docs/FRIEND-INSTALL.md` (it’s also bundled as `INSTALL.md` in the zip).

## Permissions (avoid re-granting every rebuild)

macOS stores Microphone / Accessibility / Input Monitoring permissions based on the app’s **bundle identifier + code signature**.

Right now `./scripts/build-macos-app.sh` uses **ad-hoc signing** by default, which often causes macOS to treat each rebuild as a “new app” and ask again.

For a production-like workflow:

1. Use a stable bundle id and a real signing identity:
   - `BUNDLE_ID="com.yourcompany.TranscribeHoldPaste"`
   - `SIGNING_IDENTITY="Apple Development: …"` (dev) or `Developer ID Application: …` (distribution)
2. Install the signed app to `/Applications`:
   - `./scripts/install-to-applications.sh`

## Sharing

See `docs/SHARING.md`.
