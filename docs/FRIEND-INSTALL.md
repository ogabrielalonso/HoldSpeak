# HoldSpeak (Friend Install)

This app is a **menu bar** app. You provide your own OpenAI API key.

Notes:
- The API key is stored in the **macOS Keychain** on your Mac.
- You are responsible for any OpenAI API costs on your account.

## Install

1. Unzip the download.
2. Drag `HoldSpeak.app` into your `Applications` folder.
3. First launch:
   - Right‑click `HoldSpeak.app` → **Open** → **Open**
   - (You may need to repeat this once depending on macOS Gatekeeper.)

## Configure

1. Open the menu bar icon → **Settings…**
2. Paste your OpenAI API key into Settings → **Save**
3. Click **Enable hotkey** (the hotkeys only work when enabled)

## Required macOS permissions

System Settings → Privacy & Security:

- **Microphone**: allow `HoldSpeak`
- **Accessibility**: allow `HoldSpeak`

If something still doesn’t paste, quit and re-open the app after granting permissions.

## Use

- Hold `Control + Option + Space` → speak → release → paste transcript
- Hold `Control + Option + Command + Space` → speak → release → prompt + paste result

## Troubleshooting

- If transcription fails, re-open Settings and confirm the API key is saved (and valid).
- If paste fails, the app will copy the result to your clipboard; then you can paste manually.
