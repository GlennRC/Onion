#!/bin/sh
# git_sync_saves.sh — Post-game hook: commit and push save files via git
# Called from launch_game_postprocess() in runtime.sh
# Usage: git_sync_saves.sh [rom_name]

sysdir=/mnt/SDCARD/.tmp_update
savesdir=/mnt/SDCARD/Saves/CurrentProfile
config_dir=$sysdir/config
git_bin=$sysdir/bin/git
enable_flag="$config_dir/.gitSyncEnabled"
sync_config="$config_dir/.gitsync"
ssh_key="$config_dir/.gitsync_ssh_key"
log_file=/mnt/SDCARD/Saves/git_sync.log

# Exit early if sync not enabled
[ -f "$enable_flag" ] || exit 0

# Exit early if git binary missing
[ -x "$git_bin" ] || exit 0

# Exit early if no .git repo initialized
[ -d "$savesdir/.git" ] || exit 0

export HOME=/mnt/SDCARD
export GIT_SSH_COMMAND="$sysdir/bin/ssh -i $ssh_key"

rom_name="${1:-unknown}"
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$log_file"
}

log "=== git sync start: $rom_name ==="

# Sync clock via NTP if WiFi is up (device resets to 1970 on boot)
if ifconfig wlan0 2>/dev/null | grep -q "inet addr"; then
    $sysdir/bin/ntpdate -s pool.ntp.org 2>/dev/null
fi

cd "$savesdir" || { log "ERROR: cd to $savesdir failed"; exit 1; }

# Stage save files (.srm) and save states (.state*)
# Use find because /bin/sh does not support ** globs
save_count=$(find saves -name '*.srm' 2>/dev/null | wc -l)
state_count=$(find states \( -name '*.state' -o -name '*.state.*' \) 2>/dev/null | wc -l)
log "Found $save_count srm files, $state_count state files"

find saves -name '*.srm' -exec "$git_bin" add -f {} + 2>> "$log_file"
find states \( -name '*.state' -o -name '*.state.*' \) -exec "$git_bin" add -f {} + 2>> "$log_file"

# Check if there are changes to commit
if "$git_bin" diff --cached --quiet 2>> "$log_file"; then
    log "No save changes to commit"
    exit 0
fi

# Commit with game name and timestamp
"$git_bin" commit -m "auto: $rom_name — $timestamp" >> "$log_file" 2>&1

if [ $? -ne 0 ]; then
    log "ERROR: commit failed"
    exit 1
fi

log "Committed save changes"

# Push in background (don't block return to menu)
# Only push if WiFi is up and remote is configured
if [ -f "$sync_config" ]; then
    . "$sync_config"
fi

if [ -z "$remote_url" ]; then
    log "No remote configured, skipping push"
    exit 0
fi

wifi_up() {
    ifconfig wlan0 2>/dev/null | grep -q "inet addr"
}

if wifi_up; then
    "$git_bin" push -u origin "${branch:-main}" >> "$log_file" 2>&1
    if [ $? -eq 0 ]; then
        log "Push OK"
    else
        log "Push FAILED"
    fi
else
    log "WiFi down, skipping push (will push next time)"
fi

exit 0
