# RazBack

## Summary
RazBack is a simple Btrfs-based backup system using snapshots. A Btrfs subvolume is shared over the network via Samba, and a script periodically creates new snapshots while keeping a structured retention schedule. Older snapshots are removed at increasing intervals to balance storage efficiency and recovery options.

The Samba share utilizes the `vfs_shadow_copy2` module, allowing Windows clients to access previous versions of files directly from the file or folder properties.

## Details
The Samba share (e.g., `NameOfTheShare`) is located on a Btrfs-formatted volume mounted at `/path`. Snapshots are stored in a dedicated subdirectory: `/path/.snapshots`. The primary script, `razback-snap.sh`, periodically creates snapshots, while `razback-remove-all.sh` (optional) can be used to manually remove all snapshots if needed.

### Samba Configuration
To enable previous versions in Windows, configure the share as follows in `/etc/samba/smb.conf`:

```ini
[NameOfTheShare]
    comment = This contains stuff...
    path = /path
    vfs objects = shadow_copy2
    shadow:snapprefix = .*
    shadow:delimiter = -20
    shadow:format = -%Y-%m-%d-%H-%M-%S
    shadow:sort = desc
    shadow:snapdir = .snapshots
    read only = no
    browsable = yes
```

### Snapshot Creation (razback-snap.sh)
The `razback-snap.sh` script is executed periodically via `cron`. For example, to create a snapshot every hour:

```sh
sudo crontab -e
0   *   *   *   *   /path/.snapshots/razback-snap.sh
```

Snapshots follow the naming pattern: `XXXXXX-YYYY-MM-DD-HH-MM-SS`, where `XXXXXX` is a sequential counter, and the rest is a timestamp.

The script implements a retention policy that maintains:
- last three hourly snapshots (all intervals depend on interval the script is being executed via cron)
- next three 2-hourly snapshots
- next three 4-hourly snapshots
- ... up to three snapshots spaced every 512 hours (~21 days)

Total number od snapshots is 30, with increassing time intervals. When using suggested 1-hour interval, maximum age of the last snapshot is around four months.  

All other snapshots outside this pattern are removed automatically.

### Snapshot Deletion (razback-remove-all.sh)
The `razback-remove-all.sh` script removes **all** snapshots. It is only meant for emergency cleanups when disk space is critically low and is **not meant** for regular use.
Individual snapshots can be removed by executing:
sudo btrfs subvolume delete "/path/.snapshots/XXXXXX-YYYY-MM-DD-HH-MM-SS"

---

This system provides a simple and efficient way to manage backups using Btrfs snapshots while making them accessible to Windows clients through Samba’s Previous Versions feature.

