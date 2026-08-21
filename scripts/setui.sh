# === Bootstrap: package manager ===
# Homebrew is interactive (Enter + sudo prompt) but must run first —
# every brew install below depends on it.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# === Toolchain managers === (non-interactive, run early)
curl https://mise.run | sh
curl -LsSf https://astral.sh/uv/install.sh | sh

# === Core dev workflow ===
brew install docker docker-compose colima
colima start
brew install glab
brew install worktrunk
brew install tlrc
brew install httpie

# === Productivity tools ===
brew install zoxide
brew install fzf
brew install sazardev/shiki/shiki  # TUI note taking

# === AI agents ===
curl -fsSL https://claude.ai/install.sh | bash
brew install anomalyco/tap/opencode
brew install --cask codex
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk init --global

# === Cloud tooling (GCP) — non-interactive downloads ===
mkdir -p "$HOME/.local/bin"
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz
tar -xf google-cloud-cli-darwin-arm.tar.gz -C "$HOME/.local"
for bin in gcloud gsutil bq; do ln -sf "$HOME/.local/google-cloud-sdk/bin/$bin" "$HOME/.local/bin/$bin"; done
# see Releases for other versions
URL="https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.23.0"
# TODO(debt): linux.amd64 binary on darwin-arm machine — won't exec; needs darwin.arm64
curl "$URL/cloud-sql-proxy.linux.amd64" -o "$HOME/.local/bin/cloud-sql-proxy"
chmod +x "$HOME/.local/bin/cloud-sql-proxy"

# === Interactive steps — run last so unattended portion completes first ===
"$HOME/.local/google-cloud-sdk/install.sh"   # prompts for PATH/completion setup
wt config shell install         # modifies shell rc