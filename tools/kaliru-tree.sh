#!/bin/bash
# The kaliru tree Rusticc builds, for working on it: kaliru at
# rusticc_git.bb's SRCREV with Rusticc's patches
# (meta-rusticc/recipes-apps/rusticc/files/kaliru) as commits, branch
# rusticc-work, in work/kaliru (or DEST). Edit and commit there, then
# tools/kaliru-export.sh writes the patches back.
#   tools/kaliru-tree.sh [DEST]
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
R=$HERE/meta-rusticc/recipes-apps/rusticc
DEST=${1:-$HERE/work/kaliru}
rev=$(sed -n 's/^SRCREV = "\(.*\)"/\1/p' "$R/rusticc_git.bb")
url=$(sed -n 's#^SRC_URI = "git://\([^;]*\);.*#https://\1#p' "$R/rusticc_git.bb")
if [ ! -d "$DEST/.git" ]; then
    git clone -q -c core.autocrlf=false "$url" "$DEST"
fi
cd "$DEST"
git fetch -q origin
git checkout -q -B rusticc-work "$rev"
git am -q "$R"/files/kaliru/*.patch
echo "$DEST: $(git log --oneline "$rev"..HEAD | wc -l) Rusticc patches on $(git log -1 --format=%h "$rev")"
