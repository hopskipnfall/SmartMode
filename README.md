# SmartMode

A macOS menu-bar app that switches between light and dark mode from ambient signals instead of a schedule.

## How it decides

1. **Night is always dark.** The sun's elevation is computed offline from your coordinates and lowered by cloud cover (from Open-Meteo). When it's below the night cutoff, it's dark and the room sensor is ignored.
2. **Daytime starts light, and a dark room can switch it to dark.** The MacBook's ambient light sensor (a private API, Apple Silicon laptops only) goes dark at or below one brightness and back to light at or above a higher one.
3. **No sensor reading** (lid closed, external display): the sun decides alone, so light in the day and dark at night.

Changing the appearance by hand pauses auto-switching until the automatic decision next flips. The menu shows the current decision and why.

## Download a build

Every CI run attaches a `SmartMode-<commit>` artifact (a zip of `SmartMode.app`) to the run on the repo's Actions tab, kept for 30 days. The app is only ad-hoc signed, so macOS quarantines a downloaded copy. After unzipping, clear that once:

```bash
xattr -dr com.apple.quarantine SmartMode.app
```

## Build and run

```bash
./scripts/build-app.sh   # builds SmartMode.app
open SmartMode.app
```

The first switch asks for permission to control System Events. Use the menu's **Launch at login** toggle to start it automatically. macOS ties that to the app's location, so move `SmartMode.app` to `/Applications` first.

## Location

The sun's position needs to know roughly where you are. Pick your place from the menu with **Set location…**: search for a city by name (English, via Open-Meteo) or type coordinates such as `35.69, 139.69`. The choice is remembered in the app's preferences.

Until a location is set the app does nothing: the menu-bar icon turns into a warning triangle and the top of the menu asks you to set one.

To pin exact coordinates instead, put `latitude` and `longitude` in the config file. They override the menu's choice.

## Config

`~/.config/smart-mode/config.yaml` is created on first launch with every setting at its default and a comment where the name isn't enough, and it reloads when you save. If the file has an error, the menu says so and the app keeps using the last good settings.

## Tests

```bash
swift test         # with full Xcode
./scripts/test.sh  # with only the Command Line Tools
```

The light-sensor path uses undocumented private APIs and may break with a macOS update.
