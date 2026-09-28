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
  red "Must be run inside Termux."
  exit 1
fi

ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ]; then
  red "Only aarch64 is supported, detected: $ARCH"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- 1. packages ----------------------------------------------------------

hdr "Packages"

pkg update -y -qq 2>&1 | grep -E '^[^*]' || true
pkg update -y -qq 2>&1 >/dev/null || true

curl -fsSL -o "$TMP_DIR/packages.txt" "$RAW_BASE/packages.txt"
pkg install -y -qq $(grep -vE '^\s*(#|$)' "$TMP_DIR/packages.txt") 2>&1 | grep -E '(newest|newly installed|NEW|upgraded)' || true
grn "  ✓ packages ready"

# --- 2. git config --------------------------------------------------------

hdr "Git Config"

GIT_USER=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
GIT_BRANCH=$(git config --global init.defaultBranch 2>/dev/null || true)

if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ] && [ -n "$GIT_BRANCH" ]; then
  grn "  $GIT_USER <$GIT_EMAIL>"
  grn "  Branch: $GIT_BRANCH"
else
  while true; do
    exec 3>&1
    GIT_VALS=$(dialog --clear --title "Git Config" \
      --form "Enter your Git identity:\n\nName, email, and branch are required." \
      0 0 0 \
      "Name"        1 1 "${GIT_USER:-}"  1 15 40 0 \
      "Email"       2 1 "${GIT_EMAIL:-}" 2 15 40 0 \
      "Branch"      3 1 "${GIT_BRANCH:-main}" 3 15 40 0 \
      2>&1 1>&3)
    exec 3>&-

    GIT_USER=$(echo "$GIT_VALS" | sed -n '1p' | xargs)
    GIT_EMAIL=$(echo "$GIT_VALS" | sed -n '2p' | xargs)
    GIT_BRANCH=$(echo "$GIT_VALS" | sed -n '3p' | xargs)

    if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ] && [ -n "$GIT_BRANCH" ]; then
      git config --global user.name "$GIT_USER"
      git config --global user.email "$GIT_EMAIL"
      git config --global init.defaultBranch "$GIT_BRANCH"
      break
    fi
  done
fi

# --- 3. gh auth -----------------------------------------------------------

hdr "GitHub Auth"

GH_AUTH_STATUS=$(gh auth status 2>&1 || true)

if echo "$GH_AUTH_STATUS" | grep -q "Logged in"; then
  GH_USER=$(echo "$GH_AUTH_STATUS" | grep -oE '[a-zA-Z0-9_-]+ \(' | tr -d ' (' || true)
  grn "  ${GH_USER:-?}"
else
  while true; do
    exec 3>&1
    GH_TOKEN=$(dialog --clear --title "GitHub Auth" \
      --insecure --passwordbox "\nPaste your GitHub Personal Access Token (PAT):\n\nToken will not be displayed.\nUse Ctrl+Shift+V to paste." \
      0 0 2>&1 1>&3)
    exec 3>&-

    if [ -z "$GH_TOKEN" ]; then
      red "Token is required."
      continue
    fi

    if echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null; then
      GH_USER=$(gh auth status 2>&1 | grep -oE '[a-zA-Z0-9_-]+ \(' | tr -d ' (' || true)
      grn "  ${GH_USER:-?}"
      break
    fi

    red "Invalid token, try again."
  done
fi

# --- done ----------------------------------------------------------------

hdr "Done"
grn "  All steps complete. Restart Termux or run exec bash to reload."