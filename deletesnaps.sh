#!/bin/bash

# Get the current directory
current_dir=$(pwd)

# Find all Btrfs snapshots in the current directory
# Assuming snapshot directories start with "@GMT" (change pattern as needed)
snapshots=$(find "$current_dir" -maxdepth 1 -type d -name '0000*')

# Check if any snapshots are found
if [ -z "$snapshots" ]; then
    echo "No snapshots found in the current directory."
    exit 1
fi

# Loop through the snapshots and delete them
for snapshot in $snapshots; do
    echo "Deleting snapshot: $snapshot"
    sudo btrfs subvolume delete "$snapshot"
done

echo "All snapshots have been deleted."
