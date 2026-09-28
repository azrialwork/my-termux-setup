#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

red()  { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
grn()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
hdr()  { printf '\n\033[1;36m══ %s\033[0m\n' "$*"; }

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

hdr "Paket"

pkg update -y -qq 2>&1 | grep -E '^[^*]' || true
pkg update -y -qq 2>&1 >/dev/null || true

curl -fsSL -o "$TMP_DIR/packages.txt" "$RAW_BASE/packages.txt"
pkg install -y -qq $(grep -vE '^\s*(#|$)' "$TMP_DIR/packages.txt") 2>&1 | grep -E '(newest|newly installed|NEW|upgraded)' || true
grn "✓ paket siap"

# --- 2. git config --------------------------------------------------------

hdr "Git Config"

GIT_NAME=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
GIT_BRANCH=$(git config --global init.defaultBranch 2>/dev/null || true)

if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ] && [ -n "$GIT_BRANCH" ]; then
  grn "$GIT_NAME <$GIT_EMAIL>"
  say  "Branch: $GIT_BRANCH"
else
  exec 3>&1
  GIT_VALS=$(dialog --clear --title "Git Config" \
    --form "Isi identitas Git:\n\nGunakan panah ↑↓ untuk pindah field, Tab untuk next, Enter untuk OK." \
    0 0 0 \
    "Nama"        1 1 "${GIT_NAME:-}"  1 15 40 0 \
    "Email"       2 1 "${GIT_EMAIL:-}" 2 15 40 0 \
    "Branch"      3 1 "${GIT_BRANCH:-main}" 3 15 40 0 \
    2>&1 1>&3)
  exec 3>&-

  GIT_NAME=$(echo "$GIT_VALS" | sed -n '1p' | xargs)
  GIT_EMAIL=$(echo "$GIT_VALS" | sed -n '2p' | xargs)
  GIT_BRANCH=$(echo "$GIT_VALS" | sed -n '3p' | xargs)

  [ -n "$GIT_NAME" ]   && git config --global user.name "$GIT_NAME"
  [ -n "$GIT_EMAIL" ]  && git config --global user.email "$GIT_EMAIL"
  [ -n "$GIT_BRANCH" ] && git config --global init.defaultBranch "$GIT_BRANCH"

  grn "✓ tersimpan"
fi

# --- 3. gh auth -----------------------------------------------------------

hdr "GitHub Auth"

GH_AUTH_STATUS=$(gh auth status 2>&1 || true)

if echo "$GH_AUTH_STATUS" | grep -q "Logged in"; then
  grn "✓ sudah login"
else
  exec 3>&1
  GH_TOKEN=$(dialog --clear --title "GitHub Auth" \
    --insecure --passwordbox "\nPaste GitHub Personal Access Token (PAT):\n\nToken tidak akan ditampilkan.\nGunakan Ctrl+Shift+V untuk paste." \
    0 0 2>&1 1>&3)
  exec 3>&-

  if [ -n "$GH_TOKEN" ]; then
    echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null && grn "✓ login berhasil" || red "✗ login gagal — cek token kamu."
  else
    say "⊙ dilewati (token kosong)"
  fi
fi

# --- done ----------------------------------------------------------------

hdr "Selesai"
grn "Semua langkah siap. Jalankan exec bash untuk memuat ulang shell."