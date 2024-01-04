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
        # Extract metadata from the first file without modifying the values
        ffmpeg -i "$FIRST_FILE" 2>&1 | grep -E 'title|artist|album_artist|album|date|track|genre|publisher|encoded_by|composer|performer|disc' | while IFS=':' read -r key value; do
            # Trim leading and trailing spaces from key and value
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            # Write the key-value pair to the file
            echo "$key=$value"
        done > "$METADATA_TEMP_FILE"

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
ARTIST=$(grep -m 1 '^artist=' "$METADATA_TEMP_FILE" | sed 's/^artist=//')
ALBUM=$(grep -m 1 '^album=' "$METADATA_TEMP_FILE" | sed 's/^album=//')
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


METADATA_ARGS=""

ALBUM_TITLE=""  # Variable to store the album title

while IFS='=' read -r key value; do
    # Trim leading and trailing spaces from key and value
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    if [ "$key" == "album" ]; then
        ALBUM_TITLE="$value"
        # Set the title metadata to the album name
        METADATA_ARGS+="-metadata title=\"$ALBUM_TITLE\" "
        METADATA_ARGS+="-metadata album=\"$ALBUM_TITLE\" "
    elif [ "$key" != "title" ]; then
        # Add all metadata except for title
        METADATA_ARGS+="-metadata $key=\"$value\" "
    fi
    # Log the key and value
    echo "Setting metadata: $key = $value"
done < "$METADATA_TEMP_FILE"

# Apply all the metadata in one ffmpeg command
FFMPEG_CMD="ffmpeg -i \"$MERGED_MP3\" $METADATA_ARGS -codec copy \"temp_$MERGED_MP3\" && mv \"temp_$MERGED_MP3\" \"$MERGED_MP3\""
echo "$FFMPEG_CMD"  # Echo the command for debugging
eval "$FFMPEG_CMD"  # Use eval to correctly interpret and execute the command

ffmpeg -i "$MERGED_MP3" -i "$ALBUM_ART" -map 0 -map 1 -codec copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" "temp_$MERGED_MP3" && mv "temp_$MERGED_MP3" "$MERGED_MP3"

# Clean up temporary files
rm merge_list.txt "$METADATA_TEMP_FILE" "$ALBUM_ART"

echo "Merged MP3 file created: $MERGED_MP3"
