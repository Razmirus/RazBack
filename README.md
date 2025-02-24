# RazBack

## Summary
RazBack is a simple Btrfs-based backup system using snapshots. A Btrfs subvolume is shared over the network via Samba, and a script periodically creates new snapshots while keeping a structured retention schedule. Older snapshots are removed at increasing intervals to balance storage efficiency and recovery options.

The Samba share utilizes the `vfs_shadow_copy2` module, allowing Windows clients to access previous versions of files directly from the file or folder properties.

## Details
The Samba share (e.g., `NameOfTheShare`) is located on a Btrfs-formatted volume mounted at `/path`. Snapshots are stored in a dedicated subdirectory: `/path/.snapshots`. The primary script, `makesnap.sh`, periodically creates snapshots, while `deletesnaps.sh` (optional) can be used to manually remove all snapshots if needed.

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

### Snapshot Creation (makesnap.sh)
The `makesnap.sh` script is executed periodically via `cron`. For example, to create a snapshot every hour:

```sh
sudo crontab -e
0   *   *   *   *   /path/.snapshots/makesnap.sh
```

Snapshots follow the naming pattern: `XXXXXX-YYYY-MM-DD-HH-MM-SS`, where `XXXXXX` is a sequential counter, and the rest is a timestamp.

The script implements a retention policy that maintains:
- The last **three** hourly snapshots
- The last **three** 2-hourly snapshots
- The last **three** 4-hourly snapshots
- ... Up to three snapshots spaced every **512 hours (~21 days)**

All other snapshots outside this pattern are removed automatically.

### Snapshot Deletion (deletesnaps.sh)
The `deletesnaps.sh` script removes **all** snapshots. It is only meant for emergency cleanups when disk space is critically low and is **not recommended** for regular use.

---

This system provides a simple and efficient way to manage backups using Btrfs snapshots while making them accessible to Windows clients through Samba’s Previous Versions feature.

