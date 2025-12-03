# rclone-sync

Provides proper continuous syncing capabilities using rclone bisync.

## Features

- Bidirectional sync between remote and local directories
- Real-time local change detection via inotifywait
- Periodic remote polling (every 20s)
- Automatic conflict resolution (newer file wins, loser preserved)
- Graceful fallback for servers without checksum/modtime support
- Systemd integration for running as a user service

## Requirements

- rclone (configured with your remote)
- inotify-tools (`sudo apt install inotify-tools`)

### Optional

- systemd (for service management)

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Yiannis128/rclone-sync/refs/heads/master/install.sh | bash
```

Make sure `~/.local/bin` is in your PATH:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

### Add a sync

```sh
rclone-sync-add <name> <remote:path> <local-path>
```

Example:

```sh
rclone-sync-add documents gdrive:Documents ~/Documents
```

### Start the sync

```sh
systemctl --user enable --now rclone-sync@documents
```

### Check status

```sh
systemctl --user status rclone-sync@documents
```

### View logs

```sh
journalctl --user -u rclone-sync@documents -f
```

### Remove a sync

```sh
rclone-sync-delete documents
```

### Remove all syncs

```sh
rclone-sync-prune
```

### Update scripts

```sh
rclone-sync-update
```

## How It Works

1. On first run, performs a resync preferring the remote
2. Watches local directory for changes using inotifywait
3. Polls remote every 20 seconds for changes
4. Uses flock to prevent concurrent sync operations
5. On conflict, newer file wins; loser is renamed with `.path1` or `.path2` suffix

## Configuration

Configs are stored in `~/.config/rclone-sync/<name>.conf`:

```sh
REMOTE_PATH="gdrive:Documents"
LOCAL_DIR="/home/user/Documents"
```

Cache files are stored in `~/.cache/rclone/bisync/`.

## rclone Flags Used

| Flag | Purpose |
|------|---------|
| `--compare size,modtime,checksum` | Graceful fallback for different server capabilities |
| `--resilient` | Retry after minor errors |
| `--recover` | Auto-recover from interruptions |
| `--conflict-resolve newer` | Newer file wins on conflict |
| `--conflict-loser pathname` | Loser renamed with path suffix |
| `--check-first` | Validate before transferring |
| `--modify-window 1s` | Handle cross-platform time precision |

## License

See LICENSE file.