# Contributing to hls-compressor

Thanks for your interest in contributing!

## Getting started
- Install ffmpeg and ffprobe (see README)
- Make scripts executable: `chmod +x *.sh`
- Test locally with a small sample MP4: `./enhanced_hls.sh sample -q fast -r "720"`

## Opening issues
- Clearly describe the problem, environment (OS, ffmpeg version), and steps to reproduce.
- Include command output and any relevant ffprobe logs.

## Pull requests
- Keep changes focused and small when possible.
- Ensure scripts run on macOS, Linux, and Windows (via WSL/Git Bash). Avoid bashisms if possible or note the requirement for bash.
- Run shellcheck locally if available: `shellcheck *.sh`
- Update README/CLAUDE.md when flags, outputs, or defaults change.

## Commit messages
Use concise messages, e.g. `feat: add hevc preset`, `fix: handle missing bitrate`, `docs: clarify Windows install`.

## Code of Conduct
Be respectful and constructive.