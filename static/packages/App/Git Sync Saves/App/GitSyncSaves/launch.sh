#!/bin/sh
# Git Sync Saves — Setup & Configuration
# Initializes a git repo in the saves directory and configures the remote.

sysdir=/mnt/SDCARD/.tmp_update
savesdir=/mnt/SDCARD/Saves/CurrentProfile
config_dir=$sysdir/config
git_bin=$sysdir/bin/git
sync_config="$config_dir/.gitsync"
enable_flag="$config_dir/.gitSyncEnabled"
ssh_key="$config_dir/.gitsync_ssh_key"
log_file=/tmp/git_sync.log

export HOME=/mnt/SDCARD
export GIT_SSH_COMMAND="ssh -i $ssh_key -o StrictHostKeyChecking=no"

# Check git binary exists
if [ ! -x "$git_bin" ]; then
    infoPanel --title "Git Sync Saves" \
        --message "Git binary not found.\nPlace a static ARM git binary at:\n$git_bin" --auto
    exit 1
fi

# Load existing config or set defaults
remote_url=""
branch="main"
if [ -f "$sync_config" ]; then
    . "$sync_config"
fi

init_repo() {
    # Initialize git repo covering saves and states
    cd "$savesdir" || return 1

    if [ ! -d ".git" ]; then
        "$git_bin" init >> "$log_file" 2>&1
        # Create .gitignore to only track saves and states
        cat > .gitignore << 'EOF'
# Track only save files and save states
*
!.gitignore
!saves/
!saves/**
!states/
!states/**

# Within those dirs, only track actual save files
saves/**
!saves/**/*.srm
states/**
!states/**/*.state
!states/**/*.state.*
EOF
        "$git_bin" add .gitignore >> "$log_file" 2>&1
        "$git_bin" commit -m "init: git sync saves" >> "$log_file" 2>&1
    fi

    if [ -n "$remote_url" ]; then
        "$git_bin" remote remove origin >> "$log_file" 2>&1
        "$git_bin" remote add origin "$remote_url" >> "$log_file" 2>&1
    fi

    if [ -n "$branch" ]; then
        "$git_bin" branch -M "$branch" >> "$log_file" 2>&1
    fi
}

save_config() {
    cat > "$sync_config" << EOF
remote_url="$remote_url"
branch="$branch"
EOF
}

toggle_sync() {
    if [ -f "$enable_flag" ]; then
        rm "$enable_flag"
        infoPanel --title "Git Sync Saves" \
            --message "Git sync DISABLED.\nSaves will no longer auto-push." --auto
    else
        if [ -z "$remote_url" ]; then
            infoPanel --title "Git Sync Saves" \
                --message "No remote configured.\nEdit:\n$sync_config\nThen re-run this app." --auto
            return 1
        fi
        touch "$enable_flag"
        infoPanel --title "Git Sync Saves" \
            --message "Git sync ENABLED.\nSaves will push after every game exit." --auto
    fi
}

test_connection() {
    infoPanel --title "Git Sync Saves" --message "Testing connection..." --persistent &
    info_pid=$!

    cd "$savesdir" || return 1

    if [ ! -f "$ssh_key" ]; then
        kill $info_pid 2>/dev/null
        infoPanel --title "Git Sync Saves" \
            --message "SSH key not found at:\n$ssh_key\nPlace your private key there." --auto
        return 1
    fi

    result=$("$git_bin" ls-remote origin 2>&1)
    exit_code=$?
    kill $info_pid 2>/dev/null

    if [ $exit_code -eq 0 ]; then
        infoPanel --title "Git Sync Saves" \
            --message "Connection OK!\nRemote: $remote_url" --auto
    else
        infoPanel --title "Git Sync Saves" \
            --message "Connection FAILED.\n$result" --auto
    fi
}

force_sync() {
    infoPanel --title "Git Sync Saves" --message "Running sync..." --persistent &
    info_pid=$!

    $sysdir/script/git_sync_saves.sh "manual" >> "$log_file" 2>&1
    exit_code=$?
    kill $info_pid 2>/dev/null

    if [ $exit_code -eq 0 ]; then
        infoPanel --title "Git Sync Saves" \
            --message "Sync complete!" --auto
    else
        infoPanel --title "Git Sync Saves" \
            --message "Sync failed. Check:\n$log_file" --auto
    fi
}

# --- Main menu ---
init_repo

status="DISABLED"
[ -f "$enable_flag" ] && status="ENABLED"

choice=$(echo -e "Toggle sync ($status)\nTest connection\nForce sync now\nView config" | \
    $sysdir/bin/batocera-menu --title "Git Sync Saves" 2>/dev/null)

# Fallback if batocera-menu not available: use simpler approach
if [ $? -ne 0 ] || [ -z "$choice" ]; then
    # Simple toggle-only mode
    toggle_sync
    exit 0
fi

case "$choice" in
    Toggle*) toggle_sync ;;
    Test*) test_connection ;;
    Force*) force_sync ;;
    View*)
        msg="Remote: ${remote_url:-<not set>}\nBranch: ${branch:-main}\nStatus: $status\nSSH key: $([ -f "$ssh_key" ] && echo 'found' || echo 'MISSING')"
        infoPanel --title "Git Sync Config" --message "$msg" --auto
        ;;
esac
