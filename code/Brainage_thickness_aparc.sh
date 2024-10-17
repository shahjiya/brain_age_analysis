#!/bin/bash

# Set the directory containing all subject folders
SUBJECTS_DIR="/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/output"

# Define the output CSV file
OUTPUT_FILE="thickness_data.csv"

# Define the path to the lh.aparc.stats and rh.aparc.stats files in the specified first subject directory
FIRST_SUBJECT="/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/output/sub-CMH00000001/"
FIRST_LH_FILE="$FIRST_SUBJECT/stats/lh.aparc.stats"
FIRST_RH_FILE="$FIRST_SUBJECT/stats/rh.aparc.stats"

# Check if the lh.aparc.stats and rh.aparc.stats files exist
if [ ! -f "$FIRST_LH_FILE" ] || [ ! -f "$FIRST_RH_FILE" ]; then
  echo "One or both files do not exist."
  exit 1
fi

# Extract and modify header from lh.aparc.stats
LEFT_HEADER=$(awk '$1 != "#" {printf "left_%s,", $1}' "$FIRST_LH_FILE")

# Extract and modify header from rh.aparc.stats
RIGHT_HEADER=$(awk '$1 != "#" {printf "right_%s,", $1}' "$FIRST_RH_FILE")

# Combine headers and prepend 'Subject,' to it
HEADER="Subject,$LEFT_HEADER$RIGHT_HEADER"
HEADER="${HEADER%,}"  # Remove trailing comma

# Print the header to the CSV file
echo "$HEADER" > "$OUTPUT_FILE"

# Loop through each subject in the directory
for subject in "$SUBJECTS_DIR"/*; do
  if [ -d "$subject" ]; then
    SUBJECT_NAME=$(basename "$subject")

    # Paths to the left and right hemisphere stats files
    LH_FILE="$subject/stats/lh.aparc.stats"
    RH_FILE="$subject/stats/rh.aparc.stats"

    # Check if both files exist before proceeding
    if [[ -f "$LH_FILE" && -f "$RH_FILE" ]]; then

      # Extract left hemisphere thickness data
      LH_THICKNESS=$(awk '$1 != "#" && NF > 1 {print $3}' "$LH_FILE" | tr '\n' ',' | sed 's/,$//')
      
      # Extract right hemisphere thickness data
      RH_THICKNESS=$(awk '$1 != "#" && NF > 1 {print $3}' "$RH_FILE" | tr '\n' ',' | sed 's/,$//')

      # Combine subject name, thickness data, and hemisphere data
      echo "$SUBJECT_NAME,$LH_THICKNESS,$RH_THICKNESS" >> "$OUTPUT_FILE"

    else
      echo  " Missing lh.aparc.stats or rh.aparc.stats for subject: $SUBJECT_NAME"
    fi
  fi
done

