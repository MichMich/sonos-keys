# Sonos Keys

A native macOS menu bar app for Sonos playback, volume, and mute.
Use modified media keys or the controls in the click menu.
The app needs macOS 13 or later and reachable Sonos speakers.
It needs no Sonos cloud account, browser, Node, Python, or command-line runtime.

## Install and update

Download the universal app ZIP and its SHA-256 checksum from [GitHub Releases](https://github.com/MichMich/sonos-keys/releases).
The release app is signed and notarized. One download supports Intel and Apple Silicon.
Extract the ZIP and copy Sonos Keys to Applications before you grant permissions or enable launch at login.
For updates, replace the app with the new release.

Or install with Homebrew:

```sh
brew install --cask michmich/tap/sonos-keys
```

To update a Homebrew installation:

```sh
brew update
brew upgrade --cask sonos-keys
```

## First use and permissions

Allow Sonos Keys in System Settings → Privacy & Security → Accessibility and Input Monitoring.
If macOS requests local network access, allow it.
Choose a Sonos room in Settings, then enable Sonos keys in the menu.

If a required permission is absent, the app links to the relevant settings page.
After an Accessibility change, use **Retry media keys**.
After an Input Monitoring change, restart the app.
The app cannot grant these permissions itself.

## Media keys

By default, media keys control your Mac. Hold Command (⌘) to control Sonos.
Settings lets you choose Command, Option, Control, Shift, Fn / Globe, Caps Lock, or a combination.
All selected modifiers must be active. Extra modifiers do not cancel the shortcut.

Enable **Control Sonos by default** to reverse the route.
Media keys alone control Sonos. Hold all selected modifiers to control your Mac.
In this mode, the app removes the selected modifiers from the Mac media-key event.

| Media key | Sonos action |
| --- | --- |
| Play/Pause | Toggle playback |
| Previous | Restart after more than 3 seconds, or select the previous track when available |
| Next | Select the next track |
| Volume Up / Down | Change the selected room's volume by the configured step |
| Mute | Toggle the selected room's mute state |

Caps Lock uses its on/off state. Fn depends on your keyboard.
Option-volume can conflict with macOS sound settings.

Previous checks the source's available actions before a restart or previous-track command.
A restart requires a seek action and a position above 3 seconds.
The app reports **Track restarted** only after the same track returns near its start.
If restart fails, the app sends Previous only when available. Otherwise it reports **Previous unavailable**.

The media-key HUD appears below the menu bar icon without taking focus.
It shows results and a delayed loading indicator for slow commands.
Extra volume presses do not accumulate while a volume request is pending.

## Click menu and track info

The menu shows the selected Sonos room, the current Mac audio output, and their shortcuts.
It reads the Mac output name each time it opens. Long names have a tooltip.

One compact row contains Previous, Play/Pause, Next, Mute, and a volume slider.
Unsupported transport actions stay dimmed and disabled.
The menu reads room volume and mute on open and every 5 seconds while visible.
The slider sends `SetVolume` after release. Media keys use `SetRelativeVolume` for each volume adjustment.

Track info has separate switches for the HUD and menu. Both start off.
When enabled, the app shows the cover, title, and artist from Sonos. Radio can show station details.
Track info refreshes every 15 seconds in the background, on view opening, and every 5 seconds while its view is visible.
Both views share the track data. Turn both switches off to stop track updates.
With HUD track info enabled, Next, Previous, and restart results stay visible for 3 seconds.

The menu and HUD appear one at a time.
Each waits for the other panel's fade and shrink animation to finish before it appears.
Opening the menu also cancels delayed HUD feedback.

## Settings

Changes apply immediately and stay on your Mac.
Settings changes preserve the enabled or disabled media-key state. If you disable Sonos keys, the app discards commands that did not start.
Settings uses cards with right-aligned switches. Launch at login has its own card.
The scroll area keeps the Close button visible.

- Choose a discovered room. Use **Refresh** to repeat discovery.
- Choose a volume step from 1 to 20.
- Choose the modifiers and the default media-key route.
- Enable track info separately for the HUD and menu.
- Enable **Launch at login** to open the app when you sign in.

For a fixed speaker address, turn on **Manual**, enter any speaker's IPv4 address, then click **Refresh**.
A valid address applies immediately. An incomplete address leaves the previous address active.
If you turn Manual off, the app clears the stored address and uses automatic discovery.

## Local network behavior

Automatic discovery first uses SSDP, the local device discovery protocol.
If SSDP finds no usable speaker, the app tries Bonjour (`_sonos._tcp`) for up to 2.5 seconds.
Manual IP skips both discovery methods and reads the speaker directly over HTTP on TCP port 1400.
Devices without a Bonjour advertisement need SSDP or Manual IP.

Playback controls target the group's coordinator, the speaker that manages group playback.
Volume and mute target the selected room.
Your Mac must reach both that room and its coordinator on TCP port 1400.
Across VLANs, Bonjour needs an mDNS reflector or proxy. Routing and firewall rules must permit the HTTP connections.
For Manual IP, a DHCP reservation keeps the address stable.

The app caches discovered devices until a command error.
Group topology stays cached for 5 seconds, so group changes can take 5 seconds to appear.
Failed commands do not retry automatically.

## Build from source

Open `SonosKeys.xcodeproj` in Xcode. Select the SonosKeys scheme and My Mac, then press Command-R.
For a terminal build:

```sh
./build.sh
open "build/Sonos Keys.app"
```

The public project uses local ad hoc signing by default.
For a stable permission identity across builds, select your Apple Development certificate and team in Signing & Capabilities.
No certificate or private key is included. Ad hoc builds can require fresh permission approval.
Keep your app in Applications before you grant permissions or enable launch at login.

## Release setup

The [Release workflow](.github/workflows/release.yml) runs for version tags such as `v1.0.0`.
Use three numeric version parts. The tagged commit must belong to `main`.
The workflow builds a universal app, sets its version from the tag, signs it, and checks Apple's notarization result.
It staples the notarization ticket, publishes the ZIP and checksum, then updates [the Homebrew tap](https://github.com/MichMich/homebrew-tap).
An older run cannot downgrade the Homebrew cask.

Configure these repository secrets in GitHub Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded PKCS#12 file with the Developer ID Application certificate and private key |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | The PKCS#12 password |
| `APPLE_API_PRIVATE_KEY` | The App Store Connect team API key `.p8` contents |
| `APPLE_API_KEY_ID` | The API key ID |
| `APPLE_API_ISSUER_ID` | The API issuer ID |
| `HOMEBREW_TAP_TOKEN` | A fine-grained token for `MichMich/homebrew-tap` with Contents read and write access |

Use a dedicated team API key with the Developer role.
Keep credentials outside the repository. The workflow uses a temporary keychain and removes temporary credentials after the job.
Restrict the Homebrew token to the tap repository and renew it before expiry.

Before a release, check media-key routes, modifiers, discovery, grouped playback, volume, mute, permissions, and launch at login on a Mac.
Also check menu controls, track updates, and rapid menu/HUD transitions.
Commit the release code to `main`, then create and push its version tag.
After the workflow succeeds, check the downloaded app from Applications.
If the tagged source needs a fix, use a new version tag. Otherwise retry the failed run.
A repeated successful run replaces that tag's assets.
If the Homebrew step fails, the app release stays available. Correct the tap access or cask issue, then retry.

## Known limits

- Previous and Next depend on the playback source.
- Startup discovery can delay an early command. Slow networks can delay playback commands.
- A layout-recursion warning can appear once at startup. Its cause remains unresolved.
- Before release, check screen-edge placement, desktop clicks, Mission Control, and outside-menu dismissal on the signed app.

## About and license

The About window shows the app version, copyright, and license. Its Xonay Media button opens the website.

© 2026 Michael Teeuw, [Xonay Media](https://xonaymedia.nl).
Non-commercial use, modification, and redistribution require attribution and a copy of [LICENSE](LICENSE).
Commercial use requires separate permission.
