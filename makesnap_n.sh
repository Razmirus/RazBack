#!/bin/bash

# Script to create and manage Btrfs snapshots with automated retention

DEBUG=0  # Set to 1 to enable debug messages

MOUNTPOINT="/path"
SNAPSHOT_DIR="$MOUNTPOINT/.snapshots"

# Debugging function
debug_echo() {
    [ "$DEBUG" -eq 1 ] && echo "$1"
}

debug_echo_err() {
    [ "$DEBUG" -eq 1 ] && echo "$1" >&2
}

# Show usage information
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Creates a read-only Btrfs snapshot at the specified mountpoint."
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
NEXT_COUNTER=$(ls -d "$SNAPSHOT_DIR"/[0-9]* 2>/dev/null | awk -F/ '{print $NF}' | sed -E 's/^([0-9]{6}).*/\1/' | sort -n | tail -n 1 | sed 's/^0*//')
NEXT_COUNTER=$((NEXT_COUNTER + 1))
NEXT_COUNTER=$(printf "%06d" "$NEXT_COUNTER")
SNAPSHOT_NAME="${NEXT_COUNTER}-${TIMESTAMP}"

# Create snapshot
if ! btrfs subvolume snapshot -r "$MOUNTPOINT" "$SNAPSHOT_DIR/$SNAPSHOT_NAME"; then
    debug_echo_err "Error: Failed to create snapshot $SNAPSHOT_NAME."
    exit 1
fi

debug_echo "Snapshot created: $SNAPSHOT_DIR/$SNAPSHOT_NAME"

# Determine which snapshots to retain
backupnums() {
    local currnum=$1
    local returnval=()
    for (( i=0; i<10; i++ )); do
        while (( currnum % (2 ** i) != 0 )); do ((currnum--)); done
        for (( j=0; j<3; j++ )); do
            returnval+=("$(printf "%06d" $currnum)")
            ((currnum -= (2 ** i)))
            (( currnum < (2 ** i) )) && break
        done
        (( currnum < (2 ** i) + 1 )) && break
    done
    echo "${returnval[@]}"
}

SEQUENCE_TO_KEEP=$(backupnums "$NEXT_COUNTER")
debug_echo "Snapshots to keep: ${SEQUENCE_TO_KEEP}"

# Delete outdated snapshots
find "$SNAPSHOT_DIR" -maxdepth 1 -type d -name "??????-????-??-??-??-??-??" | while read -r old_snapshot; do
    SNAPSHOT_NUMBER=$(basename "$old_snapshot" | sed -E 's/^([0-9]{6}).*/\1/')
    if [[ ! " ${SEQUENCE_TO_KEEP[@]} " =~ " ${SNAPSHOT_NUMBER} " ]]; then
        debug_echo "Deleting old snapshot: $old_snapshot"
        sudo btrfs subvolume delete "$old_snapshot" || debug_echo_err "Failed to delete $old_snapshot"
    fi
done

exit 0

