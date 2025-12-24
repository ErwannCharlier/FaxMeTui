#!/bin/sh
set -eu

REPO="ErwannCharlier/FaxMeTui"
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
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/$ASSET"
tar -xzf "$TMP/$ASSET" -C "$TMP"

FOUND="$(find "$TMP" -type f -name "$BIN" -maxdepth 5 2>/dev/null | head -n 1)"
if [ -z "$FOUND" ]; then
  FOUND="$(find "$TMP" -type f -name "$BIN" 2>/dev/null | head -n 1)"
fi

if [ -z "$FOUND" ]; then
  echo "binary not found in archive: $ASSET" >&2
  exit 1
fi

install -m 755 "$FOUND" "$DEST/$BIN"

echo "installed: $DEST/$BIN"
echo "run: $BIN"
echo ""
if ! command -v "$BIN" >/dev/null 2>&1; then
  echo "If command not found, add to PATH:"
  echo "  echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.zshrc"
  echo "  source ~/.zshrc"
fi
