#!/bin/bash

# This script takes a video file as input and converts it into an HLS (HTTP Live Streaming) playlist with multiple resolutions and bitrates. It also generates a thumbnail image from the video.

# Check if an input filename is provided
if [ -z "$1" ]; then
    echo "Usage: $0 input_filename (without extension) [-t]"
    exit 1
fi

# Remove the file extension if provided
input_filename="${1%.*}"
input_file="$input_filename.mp4"
output_dir=$(dirname "$input_file")
output_subdir="$output_dir/$input_filename"
output_file="$output_subdir/playlist.m3u8"

# Check if the text overlay flag is provided
text_overlay=false
if [ "$2" == "-t" ]; then
    text_overlay=true
fi

# Create the output subdirectory
mkdir -p "$output_subdir"

# Create the HLS playlist file
cat > "$output_file" <<EOL
#EXTM3U
#EXT-X-VERSION:3
EOL

# Function to convert video to a specific resolution and bitrate
convert_video() {
    resolution=$1
    bitrate=$2
    font_size=$3
    output_resolution_file="${output_subdir}/${input_filename}_${resolution}.m3u8"

    if [ "$text_overlay" = true ]; then
        ffmpeg -i "$input_file" -vf "scale=-2:$resolution,drawtext=fontfile=/path/to/font.ttf:text='${resolution}p':x=(w-tw)/2:y=(h-th)/2:fontsize=${font_size}:fontcolor=white:borderw=2:bordercolor=black" -c:v libx264 -b:v "${bitrate}k" -c:a aac -b:a 128k -preset veryfast -crf 20 -g 48 -keyint_min 48 -sc_threshold 0 -hls_time 4 -hls_playlist_type vod -hls_segment_filename "${output_subdir}/${input_filename}_${resolution}_%03d.ts" "$output_resolution_file"
    else
        ffmpeg -i "$input_file" -vf "scale=-2:$resolution" -c:v libx264 -pix_fmt yuv420p -b:v "${bitrate}k" -c:a aac -b:a 128k -preset veryfast -crf 20 -g 48 -keyint_min 48 -sc_threshold 0 -hls_time 4 -hls_playlist_type vod -hls_segment_filename "${output_subdir}/${input_filename}_${resolution}_%03d.ts" "$output_resolution_file"
    fi

    echo "#EXT-X-STREAM-INF:BANDWIDTH=$(($bitrate * 1000)),RESOLUTION=${resolution}p" >> "$output_file"
    echo "${input_filename}_${resolution}.m3u8" >> "$output_file"
}

# Generate a thumbnail 5 seconds into the video
ffmpeg -i "$input_file" -ss 00:00:05 -vframes 1 -s 1920x1080 -q:v 2 "$output_subdir/thumbnail.jpg"

# Convert the video to different resolutions and bitrates with adjusted font sizes
convert_video 2160 15000 240   # 4K with font size 240
convert_video 1440 10000 180   # 1440p with font size 180
convert_video 1080 8000 120    # 1080p with font size 120
convert_video 720 5000 90      # 720p with font size 90
convert_video 480 2500 70      # 480p with font size 70
convert_video 360 1000 60      # 360p with font size 60

echo "HLS playlist and video files created successfully, and thumbnail generated."
