#!/bin/sh
# Git sync saves on shutdown (covers power-button save+shutdown)
sysdir=/mnt/SDCARD/.tmp_update
$sysdir/script/git_sync_saves.sh "shutdown" 2>/dev/null
# Wait for push to complete (up to 10 seconds)
wait
