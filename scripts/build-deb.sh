#!/usr/bin/env bash
# Builds smart-mode_<version>_<arch>.deb from the release build of SmartModeLinux.
# Pass --static-swift-stdlib (CI does) so the package needn't depend on a Swift runtime.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
case "$(dpkg --print-architecture)" in
  amd64) ARCH=amd64 ;;
  arm64) ARCH=arm64 ;;
  *) echo "unsupported architecture $(dpkg --print-architecture)" >&2; exit 1 ;;
esac

swift build -c release --product SmartModeLinux "$@"
BIN="$(swift build -c release --product SmartModeLinux --show-bin-path "$@")/SmartModeLinux"

PKG="smart-mode"
ROOT="$(mktemp -d)/$PKG"
install -D -m 0755 "$BIN" "$ROOT/usr/bin/smart-mode"
strip --strip-unneeded "$ROOT/usr/bin/smart-mode"
install -D -m 0644 packaging/linux/smart-mode.desktop "$ROOT/usr/share/applications/smart-mode.desktop"
install -D -m 0644 packaging/linux/copyright "$ROOT/usr/share/doc/$PKG/copyright"
install -D -m 0644 README.md "$ROOT/usr/share/doc/$PKG/README.md"

# Debian policy wants a changelog; this one is generated from the version and points at the real notes.
MAINTAINER="SmartMode contributors <hopskipnfall@users.noreply.github.com>"
{
  echo "$PKG ($VERSION) unstable; urgency=medium"
  echo
  echo "  * Release $VERSION. See https://github.com/hopskipnfall/SmartMode/releases"
  echo
  echo " -- $MAINTAINER  $(date -R -u -d "@${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || date +%s)}")"
} | gzip -9n > "$ROOT/usr/share/doc/$PKG/changelog.Debian.gz"
chmod 0644 "$ROOT/usr/share/doc/$PKG/changelog.Debian.gz"

INSTALLED_SIZE="$(du -sk "$ROOT/usr" | cut -f1)"
mkdir -p "$ROOT/DEBIAN"
cat > "$ROOT/DEBIAN/control" <<CONTROL
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Depends: libc6, libgtk-3-0t64 | libgtk-3-0, libayatana-appindicator3-1, libcurl4t64 | libcurl4, libxml2, libglib2.0-bin, xdg-utils
Homepage: https://github.com/hopskipnfall/SmartMode
Description: Switch light and dark mode from the sun and room brightness
 SmartMode lives in the system tray and switches the desktop between light
 and dark mode using the sun's position at your location, cloud cover, and
 the ambient light sensor when the machine has one. It supports Cinnamon
 (Linux Mint) and GNOME-style desktops.
CONTROL

OUT="${PKG}_${VERSION}_${ARCH}.deb"
# --root-owner-group: files belong to root without needing fakeroot.
dpkg-deb --root-owner-group --build -Zxz "$ROOT" "$OUT"
echo "Built $OUT"
