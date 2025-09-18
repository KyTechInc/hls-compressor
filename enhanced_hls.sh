#!/bin/bash

# Enhanced HLS Video Converter v2 - Quality Optimized
# Fine-tuned bitrates for better visual quality

set -e

# Optimized Configuration
DEFAULT_RESOLUTIONS="1440,1080,720"
SEGMENT_TIME=6
CRF_VALUE=23

# Check if an input filename is provided
if [ -z "$1" ]; then
    echo "Usage: $0 input_filename (without extension) [-t] [-hw] [-r resolutions] [-q quality]"
    echo "  -t: Add text overlay with resolution"
    echo "  -hw: Use hardware acceleration (VideoToolbox on macOS, NVENC on others)"
    echo "  -r: Comma-separated resolutions (default: $DEFAULT_RESOLUTIONS)"
    echo "  -q: Quality preset (fast|balanced|quality) - default: balanced"
    echo "Example: $0 video -hw -q quality"
    exit 1
fi

# Parse arguments
input_filename="$1"
input_file="$input_filename.mp4"

# Debug output
echo "Debug: Received filename: '$input_filename'"
echo "Debug: Looking for file: '$input_file'"
text_overlay=false
use_hardware=false
resolutions="$DEFAULT_RESOLUTIONS"
quality_preset="balanced"

shift
while [[ $# -gt 0 ]]; do
    case $1 in
        -t) text_overlay=true; shift ;;
        -hw) use_hardware=true; shift ;;
        -r) resolutions="$2"; shift 2 ;;
        -q) quality_preset="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate input file
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found"
    exit 1
fi

# Setup output directory
output_dir=$(dirname "$input_file")
output_subdir="$output_dir/$input_filename"
output_file="$output_subdir/playlist.m3u8"
mkdir -p "$output_subdir"

# Detect system and set hardware acceleration
detect_hardware() {
    if [ "$use_hardware" = true ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "videotoolbox"
        elif command -v nvidia-smi &> /dev/null; then
            echo "nvenc"
        else
            echo "software"
        fi
    else
        echo "software"
    fi
}

hw_type=$(detect_hardware)

# Get video information (fixed to handle decimals properly)
get_video_dimensions() {
    ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$input_file"
}

get_video_bitrate() {
    local bitrate=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$input_file" 2>/dev/null)
    if [ -z "$bitrate" ] || [ "$bitrate" = "N/A" ]; then
        # Fallback: estimate from file size and duration
        local file_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null || echo "0")
        local duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input_file" 2>/dev/null)
        if [ -n "$duration" ] && [ "$duration" != "N/A" ]; then
            duration_int=$(echo "$duration" | cut -d'.' -f1)
            if [ "$duration_int" -gt 0 ] && [ "$file_size" -gt 0 ]; then
                bitrate=$(( file_size * 8 / duration_int ))
            else
                bitrate=5000000  # 5Mbps default
            fi
        else
            bitrate=5000000  # 5Mbps default
        fi
    fi
    echo "$bitrate"
}

get_video_duration() {
    local duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input_file" 2>/dev/null)
    if [ -n "$duration" ] && [ "$duration" != "N/A" ]; then
        # Convert to integer seconds
        echo "$duration" | cut -d'.' -f1
    else
        echo "0"
    fi
}

video_dimensions=$(get_video_dimensions)
original_width=$(echo "$video_dimensions" | cut -d'x' -f1)
original_height=$(echo "$video_dimensions" | cut -d'x' -f2)
original_bitrate=$(get_video_bitrate)
duration=$(get_video_duration)

echo "Original resolution: ${original_width}x${original_height}"
echo "Original bitrate: $((original_bitrate / 1000))k"
echo "Duration: ${duration}s"
echo "Hardware acceleration: $hw_type"
echo "Quality preset: $quality_preset"

# Create master playlist header
cat > "$output_file" <<EOL
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS
EOL

# Quality presets with improved settings
get_quality_settings() {
    case $quality_preset in
        "fast")
            echo "45 4"  # q:v 45, segment_time 4 (lower quality, faster)
            ;;
        "balanced")
            echo "60 6"  # q:v 60, segment_time 6 (improved from 65)
            ;;
        "quality")
            echo "75 8"  # q:v 75, segment_time 8 (best quality)
            ;;
        *)
            echo "60 6"  # default
            ;;
    esac
}

quality_settings=$(get_quality_settings)
vt_quality=$(echo "$quality_settings" | cut -d' ' -f1)
segment_duration=$(echo "$quality_settings" | cut -d' ' -f2)

# Enhanced conversion function
convert_video() {
    local target_height=$1
    local bitrate=$2
    local font_size=$3
    local output_resolution_file="${output_subdir}/${input_filename}_${target_height}p.m3u8"

    # Skip if target resolution is higher than source
    if [ "$target_height" -gt "$original_height" ]; then
        echo "Skipping ${target_height}p (higher than source resolution)"
        return
    fi

    # Calculate width maintaining aspect ratio
    local target_width=$((target_height * original_width / original_height))
    target_width=$((target_width - target_width % 2))

    echo "Converting to ${target_height}p (${target_width}x${target_height}) at ${bitrate}k bitrate..."

    # Build video filters
    local video_filters="scale=${target_width}:${target_height}"

    if [ "$text_overlay" = true ]; then
        video_filters="${video_filters},drawtext=fontsize=${font_size}:fontcolor=white:borderw=2:bordercolor=black:x=(w-tw)/2:y=(h-th)/2:text='${target_height}p'"
    fi

    # Common settings
    local common_audio="-c:a aac -b:a 128k -ac 2"
    local common_video="-pix_fmt yuv420p -g 48 -keyint_min 48"
    local hls_settings="-f hls -hls_time $segment_duration -hls_playlist_type vod -hls_segment_type mpegts"
    local hls_files="-hls_segment_filename \"${output_subdir}/${input_filename}_${target_height}p_%04d.ts\""

    # Set codec based on hardware acceleration
    case $hw_type in
        "videotoolbox")
            # Optimized VideoToolbox settings with improved quality
            eval ffmpeg -i \"$input_file\" -vf \"$video_filters\" \
                -c:v h264_videotoolbox -b:v \"${bitrate}k\" -q:v $vt_quality \
                -allow_sw 1 -realtime 0 \
                $common_audio $common_video \
                $hls_settings $hls_files \
                \"$output_resolution_file\" -y
            ;;
        "nvenc")
            eval ffmpeg -i \"$input_file\" -vf \"$video_filters\" \
                -c:v h264_nvenc -b:v \"${bitrate}k\" -cq 20 -preset p4 -tune hq -rc vbr \
                $common_audio $common_video \
                $hls_settings $hls_files \
                \"$output_resolution_file\" -y
            ;;
        *)
            eval ffmpeg -i \"$input_file\" -vf \"$video_filters\" \
                -c:v libx264 -crf $((CRF_VALUE - 2)) -preset medium -b:v \"${bitrate}k\" \
                -maxrate \"$((bitrate * 12 / 10))k\" -bufsize \"$((bitrate * 2))k\" \
                $common_audio $common_video \
                $hls_settings $hls_files \
                \"$output_resolution_file\" -y
            ;;
    esac

    # Add to master playlist
    echo "#EXT-X-STREAM-INF:BANDWIDTH=$((bitrate * 1280)),RESOLUTION=${target_width}x${target_height},CODECS=\"avc1.640028,mp4a.40.2\"" >> "$output_file"
    echo "${input_filename}_${target_height}p.m3u8" >> "$output_file"
}

# Quality-optimized bitrate calculation
get_optimal_bitrate() {
    local height=$1
    case $quality_preset in
        "fast")
            case $height in
                2160) echo 10000 ;;  # 4K
                1440) echo 5500 ;;   # 2.5K
                1080) echo 3500 ;;   # 1080p
                720)  echo 2200 ;;   # 720p
                480)  echo 1000 ;;   # 480p
                360)  echo 500 ;;    # 360p
                *) echo 2500 ;;      # Default
            esac
            ;;
        "balanced")
            case $height in
                2160) echo 12000 ;;  # 4K
                1440) echo 6000 ;;   # 2.5K (unchanged - was good)
                1080) echo 4200 ;;   # 1080p (+5% from 4000)
                720)  echo 2750 ;;   # 720p (+10% from 2500)
                480)  echo 1200 ;;   # 480p
                360)  echo 600 ;;    # 360p
                *) echo 3000 ;;      # Default
            esac
            ;;
        "quality")
            case $height in
                2160) echo 15000 ;;  # 4K
                1440) echo 8000 ;;   # 2.5K
                1080) echo 5500 ;;   # 1080p
                720)  echo 3500 ;;   # 720p
                480)  echo 1800 ;;   # 480p
                360)  echo 900 ;;    # 360p
                *) echo 4000 ;;      # Default
            esac
            ;;
        *)
            # Default balanced
            case $height in
                2160) echo 12000 ;;
                1440) echo 6000 ;;
                1080) echo 4200 ;;
                720)  echo 2750 ;;
                480)  echo 1200 ;;
                360)  echo 600 ;;
                *) echo 3000 ;;
            esac
            ;;
    esac
}

get_font_size() {
    local height=$1
    echo $((height / 8))
}

# Generate optimized thumbnail with better quality
echo "Generating thumbnail..."
ffmpeg -i "$input_file" -ss 00:00:05 -vframes 1 \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black" \
    -q:v 1 -update 1 "$output_subdir/thumbnail.jpg" -y 2>/dev/null

# Start conversion timer
start_time=$(date +%s)

# Convert videos for specified resolutions
IFS=',' read -ra RESOLUTION_ARRAY <<< "$resolutions"
for resolution in "${RESOLUTION_ARRAY[@]}"; do
    resolution=$(echo "$resolution" | tr -d ' ')
    bitrate=$(get_optimal_bitrate "$resolution")
    font_size=$(get_font_size "$resolution")
    convert_video "$resolution" "$bitrate" "$font_size"
done

# Calculate total processing time
end_time=$(date +%s)
total_time=$((end_time - start_time))

# Enhanced file size report
echo ""
echo "=== Conversion Complete ==="
echo "Processing time: ${total_time}s"
echo "Original file: $(du -h "$input_file" | cut -f1)"
echo "Output folder: $(du -sh "$output_subdir" | cut -f1)"

# Calculate compression ratio (fixed integer arithmetic)
original_size_kb=$(du -k "$input_file" | cut -f1)
output_size_kb=$(du -sk "$output_subdir" | cut -f1)
if [ "$original_size_kb" -gt 0 ]; then
    compression_ratio=$((100 - (output_size_kb * 100 / original_size_kb)))
    space_saved_mb=$(((original_size_kb - output_size_kb) / 1024))
    echo "Compression: ${compression_ratio}% smaller"
    echo "Space saved: ${space_saved_mb}MB"
fi

echo ""
echo "Stream breakdown:"
for res in "${RESOLUTION_ARRAY[@]}"; do
    res=$(echo "$res" | tr -d ' ')
    if [ -f "${output_subdir}/${input_filename}_${res}p.m3u8" ]; then
        # Calculate size of all segments for this resolution
        segment_size=$(find "${output_subdir}" -name "${input_filename}_${res}p_*.ts" -exec du -ck {} + 2>/dev/null | tail -1 | cut -f1 || echo "0")
        segment_size=${segment_size:-0}  # Ensure it's not empty
        if [ "$segment_size" -gt 0 ] 2>/dev/null; then
            segment_size_mb=$((segment_size / 1024))
            echo "  ${res}p: ${segment_size_mb}MB"
        fi
    fi
done

echo ""
echo "Quality preset used: $quality_preset"
echo "HLS playlist: $output_file"
