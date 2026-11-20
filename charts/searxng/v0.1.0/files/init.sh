#!/bin/sh
set -eu
: "${1:?release name required}"

release_dir="/tmp_mount/$1"
mkdir -p "$release_dir/cache"

# Only works if the init container runs as the app's UID/GID
# or the export is configured to allow it.
chmod 770 "$release_dir" "$release_dir/cache"
ls -ld "$release_dir" "$release_dir/cache"
