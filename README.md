# Sonos Keys

A small native macOS menu bar app that controls Sonos with modified media keys.

Normal media keys still control your Mac. Hold your selected modifier keys to control Sonos instead. Command (⌘) is the default.

## Controls

| Media key | Sonos action |
| --- | --- |
| Play/Pause | Toggle playback |
| Previous | Previous track |
| Next | Next track |
| Volume Up | Increase room volume |
| Volume Down | Decrease room volume |
| Mute | Toggle room mute |

The HUD appears below the menu bar icon. It shows confirmed results and a loading indicator for slow commands. Extra volume presses do not accumulate while a volume request is pending.

## Download

Download the app ZIP and its SHA-256 checksum from [GitHub Releases](https://github.com/MichMich/sonos-keys/releases).
The signed and notarized app supports Intel and Apple Silicon.
Extract the ZIP and copy Sonos Keys to Applications. Xcode is not required for the release download.

Or install the app with Homebrew:

```sh
brew install --cask michmich/tap/sonos-keys
```

See [the Homebrew tap](https://github.com/MichMich/homebrew-tap) for upgrades and installation notes.

## Requirements

- macOS 13 or later.
- Xcode for builds.
- Sonos speakers on the same local network, or reachable through the optional Speaker IP setting.

The app uses SwiftUI and native macOS frameworks. It has no external dependencies, browser interface, or cloud account requirement.

## Build

Version tags produce a signed and notarized app for Intel and Apple Silicon in [GitHub Releases](https://github.com/MichMich/sonos-keys/releases).
See [Release setup](docs/releases.md) for the workflow and required secrets.

Open SonosKeys.xcodeproj in Xcode. Select the SonosKeys scheme and My Mac, then press Command-R.

The public project defaults to local ad hoc signing. For stable permission identity across builds, select your own Apple Development certificate and team in Signing & Capabilities. No certificate or private key is included.

For a terminal build:

```sh
./build.sh
open "build/Sonos Keys.app"
```

Copy the app to Applications and keep it there before you grant permissions or enable launch at login.

## Permissions

Allow Sonos Keys in System Settings → Privacy & Security → Accessibility and Input Monitoring. If macOS requests local network access, allow it.

If a required permission is missing, the app opens the relevant settings page. Use Retry media keys after an Accessibility change. Restart the app after an Input Monitoring change.

Ad hoc builds can require new permission approval. Opening System Settings does not grant permission automatically.

## Settings

- Manual is off by default. Turn it on to show Speaker IP and its explanation.
- Enter any speaker's IPv4 address and click Refresh to load rooms without SSDP discovery.
- With Manual off, the app uses automatic discovery. Save clears the stored address when Manual is off.
- With Manual on, Save stores the address. Cancel leaves the saved address unchanged.
- Choose a discovered Sonos room. Use Refresh to repeat discovery.
- Drag the volume-step bar to select a step from 1 to 20.
- Choose Command, Option, Control, Shift, Fn / Globe, Caps Lock, or a combination.
- All selected modifiers must be active. Extra modifiers do not cancel the shortcut.
- Enable Launch at login to open the app when you sign in.

Caps Lock uses its on/off state. Fn depends on your keyboard. Option-volume can conflict with macOS sound settings.

Settings use local macOS UserDefaults. No personal room configuration is included in this repository.

## Local Sonos control

SSDP discovery finds device descriptions and service endpoints. ZoneGroupTopology identifies visible rooms and the group coordinator.

With Speaker IP set, the app reads that speaker's description and topology directly over HTTP on TCP port 1400.
Your Mac must also reach the selected speaker and its group coordinator. VLAN routing and firewall rules must permit these connections.
Use a DHCP reservation to keep the address stable. The setting accepts IPv4 addresses.

Playback targets the coordinator. Volume and mute target the selected room directly. Volume uses RenderingControl SetRelativeVolume, including negative adjustments. It does not read and set absolute volume.

The app discovers devices at startup and caches them until a command error. Playback topology stays cached for five seconds. Group changes can therefore take up to five seconds to appear.

Network work runs on a serial background queue. Failed commands are not retried automatically.

## About and license

© 2026 Michael Teeuw, [Xonay Media](https://xonaymedia.nl).

Non-commercial use, modification, and redistribution are permitted with attribution and a copy of the license. Commercial use requires separate permission. See [LICENSE](LICENSE).

This is publicly available source under a custom non-commercial license.

## Known limits

- Previous and next depend on the playback source.
- Startup discovery can delay an early command.
- Playback commands can queue on slow networks.
- A layout-recursion warning can appear once at startup. Its cause remains unresolved.
- The About panel requires a new build and visual check.

## Implementation

SwiftUI provides the views. AppKit provides the status item, windows, and HUD panel. CoreGraphics captures media keys. Foundation handles HTTP and XML. Darwin handles SSDP UDP.

The HUD does not take focus. It follows the status item, fades in and out, and uses a compact height for playback.

## Checks before a release

Check unmodified media-key behavior, modifier combinations, room discovery, grouped playback, volume, mute, all HUD states, permissions, and launch at login.

Next task: build the About panel and check the website link, then check the unresolved startup layout warning.
