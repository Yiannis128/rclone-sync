#!/bin/bash
# Common functions and variables for rclone-sync scripts

# Common directory paths
CONFIG_DIR="$HOME/.config/rclone-sync"
CACHE_DIR="$HOME/.cache/rclone/bisync"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"

# Function to encode paths to match rclone's bisync cache naming scheme
# Sets global variables: SAFE_REMOTE, SAFE_LOCAL, PATTERN
encode_paths() {
    local remote_path="$1"
    local local_dir="$2"

    # Match rclone's cache naming: replace /, :, and spaces with _
    SAFE_REMOTE=$(echo -n "$remote_path" | tr '/: ' '___')
    # Strip leading / from local path, then replace /, :, and spaces with _
    SAFE_LOCAL=$(echo -n "$local_dir" | sed 's|^/||' | tr '/: ' '___')
    PATTERN="$SAFE_REMOTE..$SAFE_LOCAL"
}

# Function to load instance configuration
# Sets global variables: REMOTE_PATH, LOCAL_DIR, MAX_DELETE
# Returns: 0 on success, 1 if config not found
load_instance_config() {
    local instance="$1"
    local config_file="$CONFIG_DIR/$instance.conf"

    if [ ! -f "$config_file" ]; then
        echo "Error: Instance '$instance' not found."
        return 1
    fi

    source "$config_file"
    return 0
}

# Function to clean up cache files for a given instance
# Arguments: remote_path, local_dir
cleanup_cache_files() {
    local remote_path="$1"
    local local_dir="$2"

    if [ -n "$remote_path" ] && [ -n "$local_dir" ]; then
        encode_paths "$remote_path" "$local_dir"
        echo "Cleaning cache files matching: $PATTERN"
        find "$CACHE_DIR" -name "${PATTERN}*" -delete 2>/dev/null || true
    fi
}

# Function to stop and disable a service instance
# Arguments: instance name
stop_service() {
    local instance="$1"

    systemctl --user stop "rclone-sync@$instance" 2>/dev/null || true
    systemctl --user disable "rclone-sync@$instance" 2>/dev/null || true
}

# Function to iterate over all instances and execute a callback
# Arguments: callback_function
# The callback receives: instance_name, config_file_path
iterate_instances() {
    local callback="$1"

    if [ ! -d "$CONFIG_DIR" ] || [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
        echo "No rclone-sync instances found."
        return 1
    fi

    for conf in "$CONFIG_DIR"/*.conf; do
        [ -f "$conf" ] || continue

        local instance=$(basename "$conf" .conf)
        "$callback" "$instance" "$conf"
    done

    return 0
}

# Function to expand tilde in paths
# Arguments: path
# Output: expanded path
expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}
