#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

red() { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
say() { printf '  %s\n' "$*"; }
ask() { printf '  \033[0;36m%s\033[0m ' "$*"; }
hdr() { printf '\n\033[1;36m══ %s\033[0m\n' "$*"; }

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

spinner() {
  local pid=$1 msg=$2 delay=0.1 chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  while kill -0 "$pid" 2>/dev/null; do
    for ((i=0;i<${#chars};i++)); do
      printf '\r  %s %s' "${chars:$i:1}" "$msg"
      sleep "$delay"
    done
  done
  printf '\r\033[2K'
}

pkg update -y -qq >/dev/null 2>&1 &
spinner $! "updating repos..."

curl -fsSL -o "$TMP_DIR/packages.txt" "$RAW_BASE/packages.txt"
pkg install -y -qq $(grep -vE '^\s*(#|$)' "$TMP_DIR/packages.txt") >/dev/null 2>&1 &
spinner $! "installing packages..."

say "  ✓ packages ready"

# --- 2. git config --------------------------------------------------------

hdr "Git Config"

GIT_USER=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
GIT_BRANCH=$(git config --global init.defaultBranch 2>/dev/null || true)

if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ] && [ -n "$GIT_BRANCH" ]; then
  say "  $GIT_USER <$GIT_EMAIL>"
  say "  Branch: $GIT_BRANCH"
else
  while true; do
    ask "Name   [$GIT_USER]:" && read -r input && GIT_USER="${input:-$GIT_USER}"
    ask "Email  [$GIT_EMAIL]:" && read -r input && GIT_EMAIL="${input:-$GIT_EMAIL}"
    ask "Branch [$GIT_BRANCH]:" && read -r input && GIT_BRANCH="${input:-${GIT_BRANCH:-main}}"
    echo

    if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ] && [ -n "$GIT_BRANCH" ]; then
      git config --global user.name "$GIT_USER"
      git config --global user.email "$GIT_EMAIL"
      git config --global init.defaultBranch "$GIT_BRANCH"
      say "  ✓ config saved"
      break
    fi
    red "  All fields are required."
  done
fi

# --- 3. gh auth -----------------------------------------------------------

hdr "GitHub Auth"

GH_AUTH_STATUS=$(gh auth status 2>&1 || true)

if echo "$GH_AUTH_STATUS" | grep -q "Logged in"; then
  GH_USER=$(echo "$GH_AUTH_STATUS" | grep -oE '[a-zA-Z0-9_-]+ \(' | tr -d ' (' || true)
  say "  ${GH_USER:-?}"
else
  while true; do
    ask "GitHub PAT:" && read -rs GH_TOKEN && printf ' %.0s*' $(seq 1 ${#GH_TOKEN}) && echo
    if [ -z "$GH_TOKEN" ]; then
      red "  Token is required."
      continue
    fi
    if echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null; then
      GH_USER=$(gh auth status 2>&1 | grep -oE '[a-zA-Z0-9_-]+ \(' | tr -d ' (' || true)
      say "  ${GH_USER:-?}"
      break
    fi
    red "  Invalid token, try again."
  done
fi

# --- done ----------------------------------------------------------------

hdr "Done"
say "  All steps complete. Restart Termux or run exec bash to reload."