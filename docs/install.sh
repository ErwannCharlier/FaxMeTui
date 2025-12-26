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
  linux)  OS="linux" ;;
  *) echo "unsupported os: $OS" >&2; exit 1 ;;
esac

ASSET="${BIN}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"

if [ -z "${DEST+x}" ]; then
  if [ "$(id -u)" -eq 0 ] || [ -w "/usr/local/bin" ] 2>/dev/null; then
    DEST="/usr/local/bin"
  else
    DEST="$HOME/.local/bin"
  fi
fi

mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/$ASSET"
tar -xzf "$TMP/$ASSET" -C "$TMP"

FOUND="$(find "$TMP" -maxdepth 5 -type f -name "$BIN" 2>/dev/null | head -n 1)"
if [ -z "$FOUND" ]; then
  FOUND="$(find "$TMP" -type f -name "$BIN" 2>/dev/null | head -n 1)"
fi

if [ -z "$FOUND" ]; then
  echo "binary not found in archive: $ASSET" >&2
  exit 1
fi

install -m 755 "$FOUND" "$DEST/$BIN"

add_path_line() {
  file="$1"
  line="$2"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file"
  grep -qsF "$line" "$file" || printf '\n%s\n' "$line" >> "$file"
}

if [ "$DEST" = "$HOME/.local/bin" ]; then
  PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
else
  PATH_LINE="export PATH=\"$DEST:\$PATH\""
fi

case ":$PATH:" in
  *":$DEST:"*) : ;;
  *)
    add_path_line "$HOME/.profile" "$PATH_LINE"
    [ -f "$HOME/.zshrc" ]  && add_path_line "$HOME/.zshrc"  "$PATH_LINE" || true
    [ -f "$HOME/.bashrc" ] && add_path_line "$HOME/.bashrc" "$PATH_LINE" || true
  ;;
esac

echo "installed: $DEST/$BIN"
echo "running now..."
echo "note: for next terminals, 'fax-erwann' will work (or run: . ~/.profile)"
exec "$DEST/$BIN"
