# SmartMode

SmartMode switches macOS and Linux between light and dark mode from the sun and your room's brightness instead of a schedule. It lives in the menu bar (macOS) or the system tray (Linux).

<img width="373" height="351" alt="The SmartMode menu showing the current decision, the sun and the room reading" src="https://github.com/user-attachments/assets/0d432fcf-673d-4a06-a1b1-1c6664a1ca04" />

## How it works

- You enter a location by name or coordinates (the app does not directly access your location).
- When the angle of the sun drops to a certain point, dark mode is automatically enabled.
- Dense clouds make it get dark earlier, so we subtract from the angle of the sun based on the amount of cloud cover.
- During the day, we use the ambient light sensor on your Mac to switch to dark mode if the room appears to be dark.
- With no sensor reading (lid closed), the sun decides on its own. If you change the appearance by hand, SmartMode steps aside until its own decision next changes. The menu shows the current decision and why.

## Requirements

- An **Apple Silicon MacBook** (the ambient light sensor is read through a private, undocumented API, and this build is arm64 only)
- macOS 13 or later

Because the sensor API is undocumented, a macOS update could break sensor readings.

## Install

1. Download `SmartMode-<version>.zip` from the [latest release](https://github.com/hopskipnfall/SmartMode/releases/latest) and unzip it.
2. Move `SmartMode.app` to `/Applications`.
3. Open it. The app isn't notarized, so macOS blocks it the first time. Allow it in one of two ways:
   - **In System Settings (easiest):** open **Privacy & Security**, scroll down to the Security section, find the message saying SmartMode was blocked, click **Open Anyway** and confirm. Then open the app again. The exact wording differs a little between macOS versions.
   - **Or in Terminal:** run this once, then open the app:
     ```bash
     xattr -dr com.apple.quarantine /Applications/SmartMode.app
     ```
4. A half-filled circle appears in the menu bar. There is no Dock icon.
5. **Set a location.** Until you do, SmartMode does nothing: the menu-bar icon shows a warning triangle and the top of the menu says so. Choose **Set location…**, search for your city (English), or type coordinates such as `35.69, 139.69`.
6. The first time it switches, macOS asks whether SmartMode may control System Events. Click **Allow**; without that it can't change the appearance.

The first time it runs from `/Applications`, SmartMode adds itself to your login items so it starts automatically, and macOS shows a notification when that happens. Turn it off any time with the **Launch at login** toggle in the menu, and it stays off. macOS ties a login item to the app's location, which is why it only does this for a copy in `/Applications`.

## Linux

The Linux build is a tray icon (StatusNotifier / AppIndicator) with the same menu, and works the same way as on macOS. It is tested on Linux Mint (Cinnamon).

### Install

1. Open the latest run on the repo's Actions tab and download the `SmartMode-linux-<commit>` artifact (there is no Linux release download yet). It is a `.tar.gz` of one x86_64 binary built on Ubuntu 24.04, which matches Mint 22.
2. Unpack it somewhere stable, such as `~/.local/bin`, and run it:
   ```bash
   tar xzf SmartMode-linux-X64.tar.gz -C ~/.local/bin
   ~/.local/bin/SmartModeLinux
   ```
3. Set a location from the tray menu, as on macOS.

It needs `libgtk-3-0`, `libayatana-appindicator3-1`, libcurl and libxml2, which Mint already has. GNOME also needs the AppIndicator extension to show tray icons.

### How it differs from macOS

- **Desktops:** Cinnamon switches the Mint-Y GTK and Cinnamon themes (`Mint-Y` ↔ `Mint-Y-Dark`, keeping your accent) plus the system color scheme. Other desktops (GNOME and friends) switch `org.gnome.desktop.interface color-scheme`. It uses `gsettings`.
- **Ambient light sensor:** read from the kernel's IIO interface (`/sys/bus/iio/devices/*/in_illuminance_*`). Many machines have none; then the sun and clouds decide on their own. A closed lid (`/proc/acpi/button/lid`) counts as no reading.
- **Launch at login** writes `~/.config/autostart/smart-mode.desktop`. It is turned on the first time the app runs, except from a `.build` folder, and the **Launch at login** toggle turns it off for good. The entry points at wherever the binary was when you toggled it, so move the binary first.
- **No update check** yet.

### Building from source

Needs the Swift toolchain, `libgtk-3-dev` and `libayatana-appindicator3-dev`:

```bash
swift build -c release --product SmartModeLinux
.build/release/SmartModeLinux
```

## Location

Pick your place from the menu with **Set location…**: search for a city by name (English, via Open-Meteo) or type coordinates such as `35.69, 139.69`. SmartMode writes the result into the `location:` section of `~/.config/smart-mode/config.yaml`, so that file is the one place your location lives. You can also edit `latitude` and `longitude` there by hand. `locationName` is only shown in the menu; without it the menu shows the coordinates.

## Config

`~/.config/smart-mode/config.yaml` is created on first launch with every setting at its default and a comment where the name isn't enough, and it reloads when you save. If the file has an error, the menu says so and the app keeps using the last good settings.

## Updates and feedback

- **New versions:** once a day SmartMode asks GitHub for the latest release (one request to `api.github.com`, nothing sent but the request itself) and shows **New version available** in the menu when it's newer than yours. Turn this off with `checkForUpdates: false` in the config. Updating is manual: download the new zip from the releases page.
- **Problems and feedback:** **Report an issue…** in the menu opens a bug report form on GitHub with your SmartMode and macOS versions filled in. Your location and settings are not put in the link; the form asks you to paste them only if you want to share them.

## Building from source

```bash
./scripts/build-app.sh   # builds SmartMode.app
open SmartMode.app
```

Every CI run also attaches a `SmartMode-<commit>` artifact (a zip of `SmartMode.app`) to the run on the repo's Actions tab, kept for 30 days. Open it the same way as a release download.

Run the tests with:

```bash
swift test         # with full Xcode
./scripts/test.sh  # with only the Command Line Tools
```

## License

SmartMode is licensed under the [Apache License 2.0](LICENSE).
