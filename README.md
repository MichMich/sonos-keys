# Sonos Keys

A small native macOS menu bar app that controls Sonos with modified media keys.

By default, media keys control your Mac. Hold your selected modifier keys to control Sonos. Command (⌘) is the default.

Enable **Control Sonos by default** to reverse this behavior. Media keys alone control Sonos. Hold all selected modifiers to control your Mac.
In inverted mode, Mac media-key events omit the selected modifiers. Other modifiers remain unchanged.
The setting starts off. Changes apply immediately. Close dismisses the settings window.

## Controls

| Media key | Sonos action |
| --- | --- |
| Play/Pause | Toggle playback |
| Previous | Restart the track after more than 3 seconds, otherwise go to the previous track |
| Next | Next track |
| Volume Up | Increase room volume |
| Volume Down | Decrease room volume |
| Mute | Toggle room mute |

The menu flyout uses the native macOS popover material with transparency and background blur.
It has grouped actions and a separate error section.
A separate section lists the selected Sonos room and current Mac audio output beside their shortcuts.
The output name refreshes when the menu opens. Long names use a tooltip. Settings scroll within a compact window.

## Track info

Settings has separate switches for track info in the media-key HUD and the click menu. Both start off.
When enabled, the app shows the cover, title, and artist when Sonos provides them. Radio uses station details when available.
Track info refreshes every 15 seconds in the background, immediately when its view opens, and every 5 seconds while visible.
Both views share the same metadata cache. Requests run separately from media-key commands.
Turn both switches off to stop updates.

Previous reads the position from the group coordinator. After more than 3 seconds, it seeks to the track start.
The app checks the source's available actions before a restart or Previous command.
The HUD shows Track restarted only after the position returns near zero on the same track.
If restart fails, it sends Previous only when available. Otherwise the HUD shows Previous unavailable.
With track info enabled in the HUD, Next, Previous, and restart results stay visible for 3 seconds.

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
- With Manual off, the app uses automatic discovery and clears the stored address.
- With Manual on, a valid IPv4 address applies immediately. An incomplete address leaves the previous address active.
- Choose a discovered Sonos room. Use Refresh to repeat discovery.
- Drag the volume-step bar to select a step from 1 to 20.
- Choose Command, Option, Control, Shift, Fn / Globe, Caps Lock, or a combination.
- All selected modifiers must be active. Extra modifiers do not cancel the shortcut.
- Enable Launch at login to open the app when you sign in.

Caps Lock uses its on/off state. Fn depends on your keyboard. Option-volume can conflict with macOS sound settings.

Changes apply immediately and use local macOS UserDefaults. No personal room configuration is included in this repository.

## Local Sonos control

SSDP discovery finds device descriptions and service endpoints. ZoneGroupTopology identifies visible rooms and the group coordinator.

If SSDP finds no usable speaker, Bonjour searches `_sonos._tcp` for up to 2.5 seconds.
The app resolves advertised hosts and checks their Sonos device descriptions on HTTP port 1400.
Manual IP skips both discovery methods. Devices without a Bonjour advertisement still need SSDP or Manual IP.
Across VLANs, Bonjour requires an mDNS reflector or proxy. HTTP connections must also pass the firewall.

With Speaker IP set, the app reads that speaker's description and topology directly over HTTP on TCP port 1400.
Your Mac must also reach the selected speaker and its group coordinator. VLAN routing and firewall rules must permit these connections.
Use a DHCP reservation to keep the address stable. The setting accepts IPv4 addresses.

Playback targets the coordinator. Volume and mute target the selected room directly. Volume uses RenderingControl SetRelativeVolume, including negative adjustments. It does not read and set absolute volume.

The app discovers devices at startup and caches them until a command error. Playback topology stays cached for five seconds. Group changes can therefore take up to five seconds to appear.

Network work runs on a serial background queue. Failed commands are not retried automatically.

## About and license

The About window shows the app icon, version, copyright, and license in a centered layout.
The Xonay Media button opens the website.


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

### Settings layout

Settings use shared cards with right-aligned switches.
Launch at login has its own card.
The media-key card shows the selected room, Mac audio output, and key mappings.
Changes apply immediately. The scroll area keeps the Close button visible.

### Click menu controls

The click menu has one compact row with Previous, Play/Pause, Next, Mute, and a volume slider.
Unsupported actions stay dimmed and disabled.
The menu reads the selected room's volume and mute state. Transport actions use the group coordinator.
It refreshes on open and every five seconds while visible. It stops this timer on close.
The slider sends SetVolume after release. Media keys still use SetRelativeVolume.
The local Release build and 13 simulated SOAP checks passed. A sample preview checked layout, slider, and Pause callbacks.
Next check: test controls on an actual speaker. No new technical debt was identified.

### Panel transitions

The click menu and HUD wait for each other's close animation before presentation.
Both use a shared 0.25-second fade and shrink to 96%, anchored at the top center.
HUD feedback waits for the popover's close notification. Menu presentation waits for the HUD's animation completion.
New HUD feedback cancels older pending feedback. Opening the menu cancels delayed loading feedback.
The local animation checks cover deferred presentation, cancellation, completion order, and the fixed top-center anchor.
Next check: switch panels quickly with actual media keys. No new technical debt was identified.
