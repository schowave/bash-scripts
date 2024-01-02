#!/bin/bash

# Check if at least one argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <folder_path>"
    exit 1
fi

FOLDER_PATH=$1

# Check if the folder exists
if [ ! -d "$FOLDER_PATH" ]; then
    echo "Folder not found: $FOLDER_PATH"
    exit 1
fi

FIRST_FILE=""
METADATA_TEMP_FILE="metadata_temp.txt"
ALBUM_ART="album_art.jpg"

# Find the first MP3 file in the folder and extract metadata and album art
for file in "$FOLDER_PATH"/*.mp3; do
    if [ -z "$FIRST_FILE" ] && [ -f "$file" ]; then
        FIRST_FILE="$file"
        # Extract metadata from the first file
        ffmpeg -i "$FIRST_FILE" 2>&1 | grep -E 'title|artist|album|date|genre|track' > "$METADATA_TEMP_FILE"
        # Extract album art
        ffmpeg -i "$FIRST_FILE" -an -vcodec copy "$ALBUM_ART"
        break
    fi
done

if [ -z "$FIRST_FILE" ]; then
    echo "No MP3 files found in the folder"
    exit 1
fi

# Extract artist and album for filename
ARTIST=$(grep -m 1 'artist' "$METADATA_TEMP_FILE" | sed 's/^.*: //')
ALBUM=$(grep -m 1 'album' "$METADATA_TEMP_FILE" | sed 's/^[^:]*: *//; s/ *$//')
MERGED_MP3="${ARTIST}-${ALBUM}.mp3"
MERGED_MP3=${MERGED_MP3//\//_} # Replace any forward slashes to prevent directory issues
MERGED_MP3=${MERGED_MP3//:/-}  # Replace colons with hyphens

# Merge all MP3 files in the folder
echo "Merging files into $MERGED_MP3"
> merge_list.txt
for file in "$FOLDER_PATH"/*.mp3; do
    if [ -f "$file" ]; then
        echo "file '$file'" >> merge_list.txt
    fi
done

ffmpeg -f concat -safe 0 -i merge_list.txt -c copy "$MERGED_MP3"

# Add metadata and album art to merged file
while IFS=': ' read -r key value; do
    ffmpeg -i "$MERGED_MP3" -metadata "$key=$value" -codec copy "temp_$MERGED_MP3" && mv "temp_$MERGED_MP3" "$MERGED_MP3"
done < "$METADATA_TEMP_FILE"

ffmpeg -i "$MERGED_MP3" -i "$ALBUM_ART" -map 0 -map 1 -codec copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" "temp_$MERGED_MP3" && mv "temp_$MERGED_MP3" "$MERGED_MP3"

# Clean up temporary files
rm merge_list.txt "$METADATA_TEMP_FILE" "$ALBUM_ART"

echo "Merged MP3 file created: $MERGED_MP3"
