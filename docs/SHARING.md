# Sharing the app

## Best way (recommended)

If you want your friend to have the smoothest experience (no scary warnings, permissions stick across updates), distribute a **signed + notarized** build:

- **Developer ID signed** app
- **Notarized** DMG (or ZIP)

This requires an Apple Developer account.

## Friend-ready (works without Apple Developer account)

You can share an unsigned/ad-hoc build, but your friend will see Gatekeeper prompts and needs to right‑click → Open.

Use:

```bash
./scripts/package-for-friend.sh
```

It generates:

- `dist/HoldSpeak-friend.zip`

Send that ZIP file to your friend (AirDrop, iCloud Drive, Google Drive/Dropbox, etc.).

If your friend gets stuck on Gatekeeper warnings, the most reliable first-run is:

- Right‑click the app → **Open** → **Open**

Optional (advanced): remove quarantine after moving to `/Applications`:

```bash
xattr -dr com.apple.quarantine /Applications/HoldSpeak.app
```
