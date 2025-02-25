#!/bin/bash

# WARNING: This script will delete ALL Btrfs snapshots in the current directory.
# Use with caution, as this action is irreversible.

# Get the current directory
current_dir=$(pwd)

# Find all Btrfs snapshots in the current directory
# Adjust pattern as needed if snapshot naming convention differs
snapshots=$(find "$current_dir" -maxdepth 1 -type d -name '[0-9]*-????-??-??-??-??-??')

# Check if any snapshots are found
if [ -z "$snapshots" ]; then
    echo "No snapshots found in the current directory."
    exit 1
fi

# Loop through the snapshots and delete them
for snapshot in $snapshots; do
    echo "Deleting snapshot: $snapshot"
    sudo btrfs subvolume delete "$snapshot" || echo "Failed to delete $snapshot"
done

echo "All snapshots have been deleted."

