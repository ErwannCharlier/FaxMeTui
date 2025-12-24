#!/bin/sh
set -eu

REPO="https://github.com/ErwannCharlier/FaxMeTui"
BIN="fax-erwann"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac

case "$OS" in
  darwin) OS="darwin" ;;
  linux) OS="linux" ;;
  *) echo "unsupported os: $OS" >&2; exit 1 ;;
esac

ASSET="${BIN}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"

DEST="${DEST:-$HOME/.local/bin}"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
curl -fsSL "$URL" -o "$TMP/$ASSET"
tar -xzf "$TMP/$ASSET" -C "$TMP"
install -m 755 "$TMP/$BIN" "$DEST/$BIN"

echo "installed: $DEST/$BIN"
echo "run: $BIN"
