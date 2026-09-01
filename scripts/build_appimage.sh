#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="pingtunnel-client"
APP_DIR="${ROOT_DIR}/app"
VERSION="${VERSION:-}"
ARCH="${ARCH:-}"
SKIP_BUILD="${SKIP_BUILD:-0}"

if [[ -z "${VERSION}" && -f "${APP_DIR}/pubspec.yaml" ]]; then
  VERSION="$(awk -F': ' '/^version:/ {print $2; exit}' "${APP_DIR}/pubspec.yaml")"
fi
if [[ -z "${VERSION}" ]]; then
  VERSION="0.1.0"
fi
VERSION="${VERSION//+/-}"

if [[ -z "${ARCH}" ]]; then
  case "$(uname -m)" in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) ARCH="x86_64" ;;
  esac
fi

case "${ARCH}" in
  x86_64) FLUTTER_ARCH="x64" ;;
  aarch64) FLUTTER_ARCH="arm64" ;;
  *) FLUTTER_ARCH="x64" ;;
esac

if [[ "${SKIP_BUILD}" != "1" ]]; then
  "${ROOT_DIR}/scripts/bootstrap_flutter.sh"
  (cd "${APP_DIR}" && flutter build linux --release)
fi

BUNDLE_DIR="${APP_DIR}/build/linux/${FLUTTER_ARCH}/release/bundle"
if [[ ! -d "${BUNDLE_DIR}" ]]; then
  echo "Bundle not found: ${BUNDLE_DIR}" >&2
  exit 1
fi

TOOLS_DIR="${ROOT_DIR}/.linuxdeploy-tools"
install -d "${TOOLS_DIR}"

LINUXDEPLOY="${TOOLS_DIR}/linuxdeploy-${ARCH}.AppImage"
if [[ ! -x "${LINUXDEPLOY}" ]]; then
  echo "Fetching linuxdeploy..."
  curl -fsSL -o "${LINUXDEPLOY}" \
    "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${ARCH}.AppImage"
  chmod +x "${LINUXDEPLOY}"
fi

GTK_PLUGIN="${TOOLS_DIR}/linuxdeploy-plugin-gtk.sh"
if [[ ! -x "${GTK_PLUGIN}" ]]; then
  echo "Fetching linuxdeploy-plugin-gtk..."
  curl -fsSL -o "${GTK_PLUGIN}" \
    "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh"
  chmod +x "${GTK_PLUGIN}"
fi

# GitHub-hosted runners (and some other CI/containers) don't have FUSE
# enabled, which linuxdeploy's own AppImage needs to mount itself - extract
# and run instead, which works everywhere FUSE does not.
export APPIMAGE_EXTRACT_AND_RUN=1

STAGE_DIR="${ROOT_DIR}/dist/appimage-${ARCH}"
rm -rf "${STAGE_DIR}"
APPDIR="${STAGE_DIR}/AppDir"
install -d "${APPDIR}/usr/bin"

cp -a "${BUNDLE_DIR}/." "${APPDIR}/usr/bin/"
mv "${APPDIR}/usr/bin/app" "${APPDIR}/usr/bin/${APP_NAME}"

install -d "${APPDIR}/usr/share/applications"
install -m 644 "${ROOT_DIR}/scripts/linux/${APP_NAME}.desktop" \
  "${APPDIR}/usr/share/applications/${APP_NAME}.desktop"

ICON_SRC="${APP_DIR}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
install -d "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
if [[ -f "${ICON_SRC}" ]]; then
  install -m 644 "${ICON_SRC}" \
    "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png"
else
  echo "Icon not found at ${ICON_SRC}" >&2
  exit 1
fi

cd "${STAGE_DIR}"
NO_STRIP=1 "${LINUXDEPLOY}" \
  --appdir "${APPDIR}" \
  --desktop-file "${APPDIR}/usr/share/applications/${APP_NAME}.desktop" \
  --icon-file "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png" \
  --plugin gtk \
  --output appimage

install -d "${ROOT_DIR}/dist"
BUILT_APPIMAGE=$(find "${STAGE_DIR}" -maxdepth 1 -iname "*.AppImage" | head -1)
if [[ -z "${BUILT_APPIMAGE}" ]]; then
  echo "linuxdeploy did not produce an AppImage" >&2
  exit 1
fi
FINAL_PATH="${ROOT_DIR}/dist/${APP_NAME}-${VERSION}-${ARCH}.AppImage"
mv "${BUILT_APPIMAGE}" "${FINAL_PATH}"
chmod +x "${FINAL_PATH}"
echo "Built ${FINAL_PATH}"
