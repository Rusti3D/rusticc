#!/bin/bash
# Read-only copy of the CC1's current config and plugins into work/cc1_live
# (tools/cc1_cmp.sh uses it when present). Changes nothing on the printer.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
dest=$HERE/work/cc1_live
rm -rf "$dest" && mkdir -p "$dest"
ssh root@${CC1:-192.168.1.148} 'cd /etc/klipper && tar cf - --exclude=config/config-backups \
    --exclude=config/config_backups --exclude="*/__pycache__" config plugins' | tar xf - -C "$dest"
echo "$dest"
