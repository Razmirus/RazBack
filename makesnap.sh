#!/bin/bash

# add this script to crontab using:
# sudo crontab -e
# for example this will run the script at 12:43 every day:
# 43  12 *   *   *     /path_to_script/makesnap.sh

btrfs subvolume snapshot -r /mountpoint/ /mountpoint/.snapshots/@GMT_`date +%Y.%m.%d-%H.%M.%S`
