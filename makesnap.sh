#!/bin/bash
btrfs subvolume snapshot -r /mountpoint/ /mountpoint/.snapshots/@GMT_`date +%Y.%m.%d-%H.%M.%S`
