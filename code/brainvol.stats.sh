#!/bin/bash

# Set the directory containing all subject folders
SUBJECTS_DIR="/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/output"

# Define the output CSV file
OUTPUT_FILE="brainvol_data.csv"

# Define the path to a sample brain volume file
SAMPLE_FILE="/KIMEL/tigrlab/scratch/jshah/TAY/freesurfer/output/sub-CMH00000001/stats/brainvol.stats"

# Check if the sample file exists
if [ ! -f "$SAMPLE_FILE" ]; then
  echo "Sample file does not exist: $SAMPLE_FILE"
  exit 1
fi

# Extract the header from the sample file
HEADER=$(awk -F, '/^# Measure/ {printf "%s,", $2}' "$SAMPLE_FILE" | sed 's/,$//')
echo "Generated header: $HEADER"

# Write the header to the output CSV file
echo "SubjectID,$HEADER" > "$OUTPUT_FILE"

# Loop through each subject in the directory
for subject in "$SUBJECTS_DIR"/*; do
  if [ -d "$subject" ]; then
    SUBJECT_NAME=$(basename "$subject")

    # Path to the stats file for the current subject
    FILE="$subject/stats/brainvol.stats"

    # Check if the stats file exists
    if [ -f "$FILE" ]; then
      # Extract volume data (column 4)
      DATA=$(awk -F, '/^# Measure/ {printf "%s,", $4}' "$FILE" | sed 's/,$//')

      # Write subject name and data to the output file
      echo "$SUBJECT_NAME,$DATA" >> "$OUTPUT_FILE"
    else
      echo "Missing stats file for subject: $SUBJECT_NAME"
    fi
  fi
done

