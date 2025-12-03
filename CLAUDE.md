# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

rclone-sync is a continuous bidirectional sync tool built on top of `rclone bisync`. It provides real-time local file monitoring (via inotifywait) combined with periodic remote polling to maintain sync between remote and local directories. The project is designed to run as systemd user services for multiple sync instances.

## Architecture

### Core Scripts

- **rclone-sync**: Main sync daemon that runs as a systemd service
  - Performs initial resync preferring remote if no cache exists
  - Runs two concurrent loops:
    1. `inotifywait` loop for local changes (line 98-107)
    2. Periodic remote polling loop (every 20s) (line 83-90)
  - Uses `/tmp/rclone_bisync_lockfile` with flock to prevent concurrent bisync operations
  - Local changes are batched with 5s delay before syncing

- **rclone-sync-add**: Creates new sync instance configurations
  - Stores config in `~/.config/rclone-sync/<name>.conf`
  - Config format: `REMOTE_PATH` and `LOCAL_DIR` environment variables

- **rclone-sync-delete**: Removes single sync instance
  - Stops systemd service, deletes config, cleans cache files matching the pattern

- **rclone-sync-prune**: Removes all sync instances (interactive confirmation required)

- **rclone-sync-update**: Updates all scripts from GitHub master branch

- **install.sh**: Initial installer (downloads and runs rclone-sync-update)

### Data Storage

- **Configs**: `~/.config/rclone-sync/<instance-name>.conf`
- **Cache**: `~/.cache/rclone/bisync/` (rclone's bisync cache files)
  - Files follow naming pattern: `<SAFE_REMOTE>..<SAFE_LOCAL>.path*.lst`
  - `SAFE_REMOTE` and `SAFE_LOCAL` have `/` and `:` characters replaced with `_`

### Systemd Integration

- Template service: `rclone-sync@.service`
- Instance name becomes `%i` in systemd (loaded from `%i.conf`)
- Installed in `~/.config/systemd/user/`
- Service reads environment from config file and passes to rclone-sync script

## rclone bisync Configuration

The sync uses carefully tuned rclone flags (rclone-sync:31-42):

- `--compare size,modtime,checksum`: Graceful fallback for servers without full support
- `--resilient`, `--recover`: Automatic error recovery
- `--conflict-resolve newer --conflict-loser pathname`: Newer file wins, loser renamed with `.path1`/`.path2` suffix
- `--check-first`: Validation before transfer
- `--modify-window 1s`: Cross-platform time precision handling

## Development Commands

### Testing changes locally (without systemd)

```bash
# Direct execution
./rclone-sync remote:path ~/local/path
```

### Testing with systemd

```bash
# Add a test instance
./rclone-sync-add test-instance remote:TestPath ~/test-sync

# Start the service
systemctl --user start rclone-sync@test-instance

# Watch logs
journalctl --user -u rclone-sync@test-instance -f

# Stop and remove
systemctl --user stop rclone-sync@test-instance
./rclone-sync-delete test-instance
```

### Installation testing

```bash
# Install from local directory (modify install.sh to use local paths)
bash install.sh

# Or test the update script directly
bash rclone-sync-update
```

## Key Implementation Details

### First-run Detection

Initial sync (resync) is triggered when (rclone-sync:76):
- Either `.path1.lst` or `.path2.lst` cache files don't exist, OR
- Local directory didn't exist before script started

The resync uses `--resync-mode path1` to prefer remote files.

### Concurrency Control

Both the local (inotifywait) and remote (polling) loops use the same flock mechanism:
```bash
(
    flock -n 99 || exit 1
    run_bisync $RCLONE_FLAGS
) 99>/tmp/rclone_bisync_lockfile
```
This prevents overlapping bisync operations which could corrupt the cache.

### Process Management

The remote polling loop runs in background (`&`) and its PID is captured. A trap ensures it's killed on SIGINT/SIGTERM.

### Safe Path Transformation

Remote and local paths are transformed for cache file naming (rclone-sync:45-46):
- Replace `/` with `_`
- Replace `:` with `_`
- Strip leading `/` from local paths

This matches rclone's internal cache naming scheme.
