# Example macOS app (Xcode)

This folder is a *reference* implementation of a menu bar app that:

- Holds a global hotkey (`Fn/Globe`) to record
- On release, transcribes via OpenAI
- Pastes into the currently focused text field
- Restores the clipboard after pasting

If `Fn/Globe` triggers a system action on your Mac, change **System Settings → Keyboard → “Press 🌐 key to”** to something that doesn’t conflict (for example, “Do Nothing”).

## Create the Xcode project

1. Open Xcode → **File → New → Project…**
2. Choose **macOS → App**
3. Product Name: `TranscribeHoldPaste`
4. Interface: **SwiftUI**, Language: **Swift**

## Add package + example files

1. Add this repo as a local package dependency in the Xcode project (or just open the package and add an app target).
2. Copy the Swift files from `Examples/MacApp/Sources/` into the app target.
3. Add `Examples/MacApp/Info.plist` as the app target’s `Info.plist`.

## Permissions you will need to grant

- Microphone: prompts automatically (requires `NSMicrophoneUsageDescription`)
- Input Monitoring: System Settings → Privacy & Security → Input Monitoring
- Accessibility: System Settings → Privacy & Security → Accessibility

## Configure API key

The example app stores your API key in the keychain under:

- service: `TranscribeHoldPaste`
- account: `openai_api_key`
