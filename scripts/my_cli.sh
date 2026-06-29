#!/usr/bin/env bash
# Bootstrap CLI tools on a new Mac
# Usage: bash my_cli.sh
# Requires: Homebrew already installed (https://brew.sh)
set -euo pipefail

log() { echo "[install] $*"; }

if ! command -v brew &>/dev/null; then
  echo "ERROR: Homebrew not found. Install it first: https://brew.sh" >&2
  exit 1
fi

log "Updating Homebrew..."
brew update --quiet

# ---- Shell Tools ----
log "Shell tools..."
brew install --quiet \
  zoxide \
  eza \
  fzf \
  fd \
  ripgrep \
  dust \
  btop \
  yazi \
  television \
  navi \
  starship \
  zellij \
  tmux

# ---- Editors ----
log "Editors..."
brew install --quiet \
  neovim \
  source-highlight

# ---- Git ----
log "Git tools..."
brew install --quiet \
  git \
  git-delta \
  lazygit \
  gh \
  glab

# ---- Containers ----
log "Container tools..."
brew install --quiet \
  colima \
  docker \
  docker-compose \
  docker-credential-helper \
  podman \
  podman-compose

# ---- Databases ----
log "Databases..."
brew install --quiet \
  postgresql@14 \
  mysql \
  libpq \
  libmemcached \
  pgcli \
  lazysql

# ---- Languages / Runtimes ----
log "Languages and runtimes..."
brew install --quiet \
  node \
  python@3.10 \
  openjdk@11 \
  gcc \
  pipx \
  scala

# openjdk@11 is keg-only; link it for system java
if ! java -version 2>&1 | grep -q "11\."; then
  sudo ln -sfn "$(brew --prefix openjdk@11)/libexec/openjdk.jdk" \
    /Library/Java/JavaVirtualMachines/openjdk-11.jdk 2>/dev/null || true
fi

# ---- Utilities ----
log "Utilities..."
brew install --quiet \
  curl \
  wget \
  coreutils \
  make \
  unzip \
  socat \
  xclip \
  pass \
  watchman \
  terminal-notifier

# ---- Media / Docs ----
log "Media and docs..."
brew install --quiet \
  ffmpeg \
  graphviz \
  plantuml

# ---- CLI Helpers ----
log "CLI helpers..."
brew install --quiet \
  tlrc

# ---- Custom / Workspace ----
log "Custom tools..."
brew install --quiet rtk 2>/dev/null || log "rtk not in public tap — install manually"
brew install --quiet worktrunk 2>/dev/null || log "worktrunk not in public tap — install manually"

log "Done. Run 'brew list --installed-on-request' to verify."
