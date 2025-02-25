#!/bin/bash

# Script to create and manage Btrfs snapshots with automated retention

# add this script to crontab using:
# sudo crontab -e
# for example this will run the script every hour:
# 0   *   *   *   *   /path/.snapshots/razback-snap.sh

# Initialize DEBUG variable; set to 1 to enable debug messages, 0 to disable
DEBUG=0

# Define paths for mountpoint and snapshot directories
MOUNTPOINT="/path"
SNAPSHOT_DIR="$MOUNTPOINT/.snapshots"

# Debugging function to stdout
debug_echo() {
    [ "$DEBUG" -eq 1 ] && echo "$1"
}

# Debugging function to stderr
debug_echo_err() {
    [ "$DEBUG" -eq 1 ] && echo "$1" >&2
}

# Show usage information
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Creates a read-only Btrfs snapshot at the specified mountpoint."
    echo "Paths is defined as variable inside of the script."
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Ensure snapshot directory exists
mkdir -p "$SNAPSHOT_DIR" || { debug_echo_err "Error: Cannot create snapshot directory."; exit 1; }

# Generate snapshot name
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

# Find the largest NEXT_COUNTER value in the snapshot directory
NEXT_COUNTER=$(ls -d "$SNAPSHOT_DIR"/[0-9]* 2>/dev/null | awk -F/ '{print $NF}' | sed -E 's/^([0-9]{6}).*/\1/' | sort -n | tail -n 1 | sed 's/^0*//')

# If no snapshot exists, set the NEXT_COUNTER to 1 (or any other starting value)
if [ -z "$NEXT_COUNTER" ]; then
    NEXT_COUNTER=1
else
    NEXT_COUNTER=$((NEXT_COUNTER + 1))  # Increment the counter for the next snapshot
fi

# Determine which snapshots to retain
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

# Get the list of sequence numbers to keep from the backupnums function, needs to run before reformating $NEXT_COUNTER
SEQUENCE_TO_KEEP=$(backupnums "$NEXT_COUNTER")
debug_echo "Snapshots to keep: ${SEQUENCE_TO_KEEP}"

# Format the next counter as a six-digit number
NEXT_COUNTER=$(printf "%06d" "$NEXT_COUNTER")

# Construct the snapshot name
SNAPSHOT_NAME="${NEXT_COUNTER}-${TIMESTAMP}"

# Create snapshot
if ! btrfs subvolume snapshot -r "$MOUNTPOINT" "${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"; then
    debug_echo_err "Error: Failed to create snapshot $SNAPSHOT_NAME."
    exit 1
fi

debug_echo "Snapshot created: ${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"

# Delete outdated snapshots
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
