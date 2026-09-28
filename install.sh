#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

red()  { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
grn()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }

REPO_URL="https://github.com/azrialwork/my-termux-setup.git"
RAW_BASE="https://raw.githubusercontent.com/azrialwork/my-termux-setup/main"

# --- sanity ---------------------------------------------------------------

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
  red "Harus dijalankan di dalam Termux."
  exit 1
fi

ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ]; then
  red "Hanya mendukung aarch64, terdeteksi: $ARCH"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- 1. packages ----------------------------------------------------------

say "Update repositori paket..."
pkg update -y

say "Download packages.txt & install..."
curl -fsSL -o "$TMP_DIR/packages.txt" "$RAW_BASE/packages.txt"
pkg install -y $(grep -vE '^\s*(#|$)' "$TMP_DIR/packages.txt")

# --- 2. git config --------------------------------------------------------

exec 3>&1
GIT_VALS=$(dialog --clear --title "Git Config" \
  --form "Isi identitas Git:\n\nGunakan panah ↑↓ untuk pindah field, Tab untuk next, Enter untuk OK." \
  0 0 0 \
  "Nama"        1 1 ""  1 15 40 0 \
  "Email"       2 1 ""  2 15 40 0 \
  "Branch"      3 1 "main" 3 15 40 0 \
  2>&1 1>&3)
exec 3>&-

GIT_NAME=$(echo "$GIT_VALS" | sed -n '1p' | xargs)
GIT_EMAIL=$(echo "$GIT_VALS" | sed -n '2p' | xargs)
GIT_BRANCH=$(echo "$GIT_VALS" | sed -n '3p' | xargs)

[ -n "$GIT_NAME" ]   && git config --global user.name "$GIT_NAME"
[ -n "$GIT_EMAIL" ]  && git config --global user.email "$GIT_EMAIL"
[ -n "$GIT_BRANCH" ] && git config --global init.defaultBranch "$GIT_BRANCH"

grn "Git config: $(git config --global user.name 2>/dev/null || echo '-') / $(git config --global user.email 2>/dev/null || echo '-') / $(git config --global init.defaultBranch 2>/dev/null || echo '-')"

# --- 3. gh auth -----------------------------------------------------------

exec 3>&1
GH_TOKEN=$(dialog --clear --title "GitHub Auth" \
  --insecure --passwordbox "\nPaste GitHub Personal Access Token (PAT):\n\nToken tidak akan ditampilkan.\nGunakan Ctrl+Shift+V untuk paste." \
  0 0 2>&1 1>&3)
exec 3>&-

if [ -n "$GH_TOKEN" ]; then
  echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null && grn "gh auth berhasil." || red "gh auth gagal — cek token kamu."
else
  say "gh auth dilewati (token kosong)."
fi

# --- done ----------------------------------------------------------------

grn "Setup selesai."