#!/bin/bash
# The Moonruster tree Rusticc builds, for working on it: Moonruster at
# moonruster_git.bb's SRCREV with Rusticc's patches
# (meta-rusticc/recipes-apps/moonruster/files/moonruster) as commits, branch
# rusticc-work, in work/moonruster (or DEST). Edit and commit there, then
# tools/moonruster-export.sh writes the patches back.
#   tools/moonruster-tree.sh [DEST]
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
R=$HERE/meta-rusticc/recipes-apps/moonruster
DEST=${1:-$HERE/work/moonruster}
rev=$(sed -n 's/^SRCREV = "\(.*\)"/\1/p' "$R/moonruster_git.bb")
url=$(sed -n 's#^SRC_URI = "git://\([^;]*\);.*#https://\1#p' "$R/moonruster_git.bb")
if [ ! -d "$DEST/.git" ]; then
    git clone -q -c core.autocrlf=false "$url" "$DEST"
fi
cd "$DEST"
git fetch -q origin
git checkout -q -B rusticc-work "$rev"
git am -q "$R"/files/moonruster/*.patch
echo "$DEST: $(git log --oneline "$rev"..HEAD | wc -l) Rusticc patches on $(git log -1 --format=%h "$rev")"
