#!/bin/bash

# add this script to crontab using:
# sudo crontab -e
# for example this will run the script at 12:43 every day:
# 43    12  *   *   *   /path/.snapshots/makesnap.sh
# or every hour:
# 0     *   *   *   *   /path/.snapshots/makesnap.sh

# Initialize DEBUG variable; set to 1 to enable debug messages, 0 to disable
DEBUG=0

# Define paths for mountpoint, snapshots directory
MOUNTPOINT="/path"
SNAPSHOT_DIR="$MOUNTPOINT/.snapshots"

# Function for debug messages to stdout
debug_echo() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "$1"
    fi
}

# Function for debug messages to stderr
debug_echo_err() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "$1" >&2
    fi
}

# Function to display usage information
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "This script creates a read-only snapshot of a Btrfs subvolume at the specified mountpoint."
    echo
    echo "Options:"
    echo "  -h, --help, /?        Display this help message and exit"
}

# Function to determine which snapshots to keep (backupnums)
backupnums() {
    local currnum=$1
    local returnval=()

    for (( i=0; i<10; i++ )); do
        # Ensure currnum is divisible by 2^i
        while (( currnum % (2 ** i) != 0 )); do
            ((currnum--))
        done

        # Add currnum three times to returnval, then decrement currnum
        for (( j=0; j<3; j++ )); do
            returnval+=("$(printf "%06d" $currnum)")
            ((currnum -= (2 ** i)))
            if (( currnum < (2 ** i) )); then
                break
            fi
        done

        # Exit if currnum drops below 2^i + 1
        if (( currnum < (2 ** i) + 1 )); then
            break
        fi
    done

    # Output tuple as result
    echo "${returnval[@]}"
}

# Check for help options
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "/?" ]]; then
    show_help
    exit 0
fi

# Create snapshot directory if it doesn't exist
mkdir -p "$SNAPSHOT_DIR" || { debug_echo_err "Error: Unable to create snapshot directory."; exit 1; }

# Generate the timestamp for the snapshot name
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

# Find the largest NEXT_COUNTER value in the snapshot directory
NEXT_COUNTER=$(ls -d "$SNAPSHOT_DIR"/[0-9]* 2>/dev/null | awk -F/ '{print $NF}' | sed -E 's/^([0-9]{6}).*/\1/' | sort -n | tail -n 1 | sed 's/^0*//')

# If no snapshot exists, set the NEXT_COUNTER to 1 (or any other starting value)
if [ -z "$NEXT_COUNTER" ]; then
    NEXT_COUNTER=1
else
    NEXT_COUNTER=$((NEXT_COUNTER + 1))  # Increment the counter for the next snapshot
fi

# Get the list of sequence numbers to keep from the backupnums function
SEQUENCE_TO_KEEP=$(backupnums "$NEXT_COUNTER")
debug_echo "Backups to keep - backupnums "$NEXT_COUNTER": ${SEQUENCE_TO_KEEP}"

# Format the next counter as a six-digit number
NEXT_COUNTER=$(printf "%06d" "$NEXT_COUNTER")

# Construct the snapshot name
SNAPSHOT_NAME="${NEXT_COUNTER}-${TIMESTAMP}"

# Create a snapshot with a name containing the date and time and the counter
if ! btrfs subvolume snapshot -r "$MOUNTPOINT" "${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"; then
    debug_echo_err "Error: Unable to create snapshot $SNAPSHOT_NAME."
    exit 1
fi

# Output result message if DEBUG=1
debug_echo "Snapshot created: ${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"

# Delete snapshots that don't match the sequence numbers from backupnums
find "$SNAPSHOT_DIR" -maxdepth 1 -type d -name "??????-????-??-??-??-??-??" | while read -r old_snapshot; do
    # Extract the snapshot number from the name
    SNAPSHOT_NUMBER=$(basename "$old_snapshot" | sed -E 's/^([0-9]{6}).*/\1/')

    # Check if the snapshot number is in the list of sequence numbers to keep
    if [[ ! " ${SEQUENCE_TO_KEEP[@]} " =~ " ${SNAPSHOT_NUMBER} " ]]; then
        debug_echo "Deleting old snapshot: $old_snapshot"
        sudo btrfs subvolume delete "$old_snapshot" || debug_echo_err "Failed to delete $old_snapshot"
    fi
done

exit 0
