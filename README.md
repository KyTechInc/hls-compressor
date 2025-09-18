# hls-compressor

Simple, script-based HLS (HTTP Live Streaming) compression workflow for generating adaptive bitrate streams from MP4 files. Produces a master playlist plus multiple resolution-specific variant streams and a thumbnail.

Works on macOS, Linux, and Windows (via WSL or Git Bash). Requires ffmpeg and ffprobe.

### Demo
https://github.com/user-attachments/assets/784b12ad-edc3-4c9c-9751-6951dd155417


## Features
- Multi-resolution HLS output (e.g., 1440p/1080p/720p)
- Master playlist generation with variant streams
- Optional text overlay of resolution
- Hardware acceleration support in enhanced script (VideoToolbox on macOS, NVENC on NVIDIA)
- Automatic thumbnail generation

## Requirements
Install ffmpeg and ffprobe:
- macOS: `brew install ffmpeg`
- Linux (Debian/Ubuntu): `sudo apt update && sudo apt install -y ffmpeg`
- Windows:
  - Winget: `winget install --id Gyan.FFmpeg.Full` (or `winget install ffmpeg` if available)
  - Or use WSL and install via apt (see Linux instructions)

## Getting Started
1) Clone the repo
```
git clone https://github.com/<your-org-or-user>/hls-compressor.git
cd hls-compressor
```

2) Make scripts executable (macOS/Linux)
```
chmod +x hls_script.sh
chmod +x enhanced_hls.sh
```
On Windows (Git Bash), the above also works; on PowerShell/CMD, run via `bash ./enhanced_hls.sh`.

3) Run a conversion
- Basic script (fixed ladders):
```
./hls_script.sh myvideo
./hls_script.sh myvideo -t   # add resolution text overlay
```

- Enhanced script (configurable + hardware accel):
```
./enhanced_hls.sh myvideo                    # default resolutions: 1440,1080,720
./enhanced_hls.sh myvideo -hw                # enable hardware acceleration
./enhanced_hls.sh myvideo -q quality         # quality preset: fast|balanced|quality
./enhanced_hls.sh myvideo -r "1080,720,480"  # custom resolutions
./enhanced_hls.sh myvideo -t -hw -q quality  # combined options
```

Input `myvideo.mp4` will produce an output folder `myvideo/` containing:
```
myvideo/
├── playlist.m3u8
├── thumbnail.jpg
├── myvideo_720p.m3u8
├── myvideo_720p_0001.ts ...
└── ...
```

## TUI (Terminal UI)
A simple terminal UI is included to run the scripts with nicer progress output.

Quick init:
```
make init
# This will check/install ffmpeg (macOS/Linux), build the TUI, and create bin shims.

# Optionally install global commands (hls, hlsx) into /usr/local/bin
make install
```

No make? Use the setup script:
```
./scripts/setup.sh
# Does the same steps as 'make init' on macOS/Debian/Ubuntu.
# On Windows, follow the manual notes below.
```

Usage with simple commands:
```
# Enhanced (default)
./bin/hls myvideo -q quality -r "1080,720" -hw -t

# Basic script (pass -basic)
./bin/hls myvideo -basic -t

# Or use the alternate shim (same behavior as hls)
./bin/hlsx myvideo -q balanced
```

Notes:
- Global commands: after `make install`, you can run `hlsx myvideo -hw -q balanced` from anywhere.
- Uninstall global commands: `make uninstall`.
- On Windows, make may not be available by default. You can still build and run:
  - Install ffmpeg via winget: `winget install --id Gyan.FFmpeg.Full`
  - Build the TUI: `cd hls-tui && go build`
  - Run: `./hls-tui/hls-tui myvideo ...` (or create your own .bat shim in a folder on PATH)

The TUI simply wraps the existing scripts and shows progress; it doesn’t change their behavior.

## Notes
- drawtext overlay uses a system font via ffmpeg; if you see errors, install a TrueType font and ensure ffmpeg has fontconfig support. The basic script uses a hardcoded font path in the example.
- Hardware acceleration depends on your system capabilities. Fallback to software is automatic.

## Roadmap
- CLI wrapper (single command install and usage)
- Post-processing uploads (S3-compatible) via rsync/rclone workflows
- Docker image and a simple HTTP API for VPS hosting
- Optional H.265/HEVC output profiles
- Subtitle track passthrough and metadata handling

## Contributing
See CONTRIBUTING.md for guidelines. PRs to improve cross-platform behavior and add tests (e.g., shellcheck, sample media) are welcome.

## License
MIT — see LICENSE.
