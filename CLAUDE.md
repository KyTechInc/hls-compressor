# CLAUDE.md

This file provides guidance when working with code in this repository.

## Project Overview

This is an HLS (HTTP Live Streaming) video conversion toolkit that transforms MP4 videos into adaptive bitrate streaming formats. The project contains two bash scripts that generate HLS playlists and video segments at multiple resolutions and bitrates.

## Core Components

### Scripts
- `hls_script.sh` - Basic HLS converter with fixed resolutions (360p-4K)
- `enhanced_hls.sh` - Advanced converter with configurable resolutions, optional hardware acceleration, and quality presets

### Architecture
Both scripts follow the same pattern:
1. Create output directory structure: `{filename}/{filename}_resolution.m3u8` and `.ts` segments
2. Generate master playlist (`playlist.m3u8`) with multiple bitrate streams
3. Create thumbnail from video at 5-second mark
4. Use FFmpeg for video processing with optimized encoding settings

## Common Development Commands

### Running the Basic Converter
```bash
./hls_script.sh filename
./hls_script.sh filename -t  # With text overlay showing resolution
```

### Running the Enhanced Converter
```bash
./enhanced_hls.sh filename                    # Default: 1440p,1080p,720p
./enhanced_hls.sh filename -hw                # Hardware acceleration
./enhanced_hls.sh filename -q quality         # Quality preset (fast|balanced|quality)
./enhanced_hls.sh filename -r "1080,720,480"  # Custom resolutions
./enhanced_hls.sh filename -t -hw -q quality  # All options combined
```

## Key Technical Details

### Video Processing Pipeline
- Uses FFmpeg with H.264/AAC encoding
- Supports hardware acceleration (VideoToolbox on macOS, NVENC on others)
- Segment duration: 4-8 seconds depending on quality preset
- Maintains aspect ratio with automatic width calculation

### Bitrate Strategy
Quality-optimized bitrates vary by preset:
- **Fast**: Lower bitrates for quick processing
- **Balanced**: Optimized balance of quality/size (1080p: 4200k, 720p: 2750k)
- **Quality**: Maximum quality settings (1080p: 5500k, 720p: 3500k)

### Output Structure
```
{filename}/
├── playlist.m3u8              # Master playlist
├── thumbnail.jpg              # Video thumbnail
├── {filename}_{resolution}p.m3u8  # Resolution-specific playlist
└── {filename}_{resolution}p_*.ts  # Video segments
```

## Hardware Acceleration Support
- **macOS**: VideoToolbox (`h264_videotoolbox`)
- **NVIDIA GPUs**: NVENC (`h264_nvenc`)
- **Fallback**: Software encoding (`libx264`)

Auto-detection based on system and available hardware.
## Tauri GUI Application

The project now includes a modern desktop GUI built with Tauri + React + Vite.

### Development Commands
```bash
cd hls-converter
bun install                    # Install dependencies
bun run tauri dev             # Start development server
bun run tauri build           # Build for production
```

### GUI Features
- **Drag & Drop Interface**: Drop video files directly into the app
- **Real-time Progress**: Visual feedback during conversion
- **Configurable Settings**: Quality presets, resolutions, hardware acceleration
- **Output Management**: Direct access to converted files and folders

### Architecture
- **Frontend**: React + TypeScript + Tailwind CSS + Vite
- **Backend**: Rust (Tauri) with async command handlers
- **File Operations**: Uses Tauri plugins for fs, shell, and dialog operations
- **Script Integration**: Executes `enhanced_hls.sh` via Rust backend

The GUI app provides the same functionality as the command-line scripts but with an intuitive visual interface.