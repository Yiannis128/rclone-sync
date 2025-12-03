#!/bin/bash
set -e

BASE_URL="https://raw.githubusercontent.com/Yiannis128/rclone-sync/refs/heads/master"

echo "Installing rclone-sync..."

# Download and run update script
curl -fsSL "$BASE_URL/rclone-sync-update" | bash
