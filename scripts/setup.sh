#!/usr/bin/env bash
set -euo pipefail

# scripts/setup.sh - fallback to Makefile 'init' for systems without make
# - Checks/installs ffmpeg & ffprobe (macOS: brew, Debian/Ubuntu: apt)
# - Builds the TUI
# - Creates bin/ shims (hls, hlsx)

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
OS="$(uname -s)"

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

install_ffmpeg() {
  if has_cmd ffmpeg && has_cmd ffprobe; then
    info "ffmpeg/ffprobe already installed"
    return 0
  fi

  case "$OS" in
    Darwin)
      if ! has_cmd brew; then
        error "Homebrew not found. Please install from https://brew.sh and re-run this script."
        exit 1
      fi
      info "Installing ffmpeg via Homebrew..."
      brew install ffmpeg || { error "Homebrew install failed"; exit 1; }
      ;;
    Linux)
      if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        info "Installing ffmpeg via apt..."
        sudo apt update && sudo apt install -y ffmpeg || { error "apt install failed"; exit 1; }
      else
        warn "Automatic install unsupported on this Linux distribution."
        warn "Install ffmpeg manually: https://ffmpeg.org/download.html"
        exit 1
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      warn "Windows detected. Please install ffmpeg via winget:"
      warn "  winget install --id Gyan.FFmpeg.Full"
      exit 1
      ;;
    *)
      warn "Unsupported OS for automatic ffmpeg install."
      warn "Install ffmpeg manually: https://ffmpeg.org/download.html"
      exit 1
      ;;
  esac
}

build_tui() {
  info "Building TUI..."
  (cd "$ROOT_DIR/hls-tui" && go build)
  info "Built: $ROOT_DIR/hls-tui/hls-tui"
}

create_shims() {
  info "Creating bin/ shims..."
  mkdir -p "$ROOT_DIR/bin"
  cat > "$ROOT_DIR/bin/hls" <<'EOF'
#!/usr/bin/env bash
exec "$PWD/hls-tui/hls-tui" "$@"
EOF
  cat > "$ROOT_DIR/bin/hlsx" <<'EOF'
#!/usr/bin/env bash
exec "$PWD/hls-tui/hls-tui" "$@"
EOF
  chmod +x "$ROOT_DIR/bin/hls" "$ROOT_DIR/bin/hlsx"
  info "Created shims: bin/hls, bin/hlsx"
}

main() {
  install_ffmpeg
  build_tui
  create_shims
  echo
  info "Setup complete. Try: ./bin/hls myvideo -q quality -r '1080,720' -hw"
}

main "$@"
