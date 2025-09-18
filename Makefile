SHELL := /bin/bash

OS := $(shell uname -s)
HAS_FFMPEG := $(shell command -v ffmpeg >/dev/null 2>&1 && echo 1 || echo 0)
HAS_FFPROBE := $(shell command -v ffprobe >/dev/null 2>&1 && echo 1 || echo 0)

.PHONY: help init deps tui run clean

help:
	@echo "Targets:"
	@echo "  make init   - Install ffmpeg if missing (macOS/Linux), build TUI, create bin shims"
	@echo "  make deps   - Install ffmpeg/ffprobe if missing"
	@echo "  make tui    - Build the TUI (hls-tui/hls-tui)"
	@echo "  make run    - Run the TUI: make run FILE=myvideo [ARGS='-q quality -hw']"
	@echo "  make clean  - Remove build outputs"

init: deps tui bin
	@echo "\nDone. Try: ./bin/hls myvideo -q quality -r '1080,720' -hw"

# Attempt to install ffmpeg cross-platform where feasible
# - macOS: Homebrew
# - Linux (Debian/Ubuntu): apt
# - Windows: print winget instructions
# If ffmpeg is present, this target is a no-op.
deps:
ifneq ($(HAS_FFMPEG)$(HAS_FFPROBE),11)
	@echo "ffmpeg and/or ffprobe not found; attempting to install..."
	@if [ "$(OS)" = "Darwin" ]; then \
		if ! command -v brew >/dev/null 2>&1; then \
			echo "Homebrew not found. Please install Homebrew from https://brew.sh and rerun 'make deps'"; exit 1; \
		fi; \
		echo "Installing ffmpeg via Homebrew..."; \
		brew install ffmpeg || { echo "Homebrew install failed"; exit 1; }; \
	elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then \
		echo "Installing ffmpeg via apt..."; \
		sudo apt update && sudo apt install -y ffmpeg || { echo "apt install failed"; exit 1; }; \
	else \
		echo "Unsupported automatic install on this platform."; \
		echo "Install ffmpeg manually and rerun: https://ffmpeg.org/download.html"; \
		echo "Windows (winget): winget install --id Gyan.FFmpeg.Full"; \
		exit 1; \
	fi
else
	@echo "ffmpeg/ffprobe already installed."
endif

# Build the TUI
# Keeps the module inside hls-tui directory
tui:
	@echo "Building TUI..."
	@cd hls-tui && go build
	@echo "Built hls-tui/hls-tui"

# Convenience run target
run: tui
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make run FILE=myvideo [ARGS='-q quality -r 1080,720 -hw']"; exit 1; \
	fi
	@./hls-tui/hls-tui $(FILE) $(ARGS)

# Create bin/ shims for simpler commands
.PHONY: bin
bin:
	@mkdir -p bin
	@printf '%s\n' '#!/usr/bin/env bash' 'exec "$$PWD/hls-tui/hls-tui" "$$@"' > bin/hls
	@printf '%s\n' '#!/usr/bin/env bash' 'exec "$$PWD/hls-tui/hls-tui" "$$@"' > bin/hlsx
	@chmod +x bin/hls bin/hlsx
	@echo "Shims created: bin/hls, bin/hlsx (both run enhanced by default; pass -basic to use basic script)"

clean:
	@rm -f hls-tui/hls-tui
	@echo "Cleaned build artifacts"