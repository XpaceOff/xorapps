#!/bin/sh
echo "Running init.sh..."
# $1 = release name (isolates each release on the NFS share)
release_dir="/tmp_mount/$1"

# The subPath of a NFS mount must exist on the export before the main
# container starts, so create the release directory on first install.
mkdir -p "$release_dir/config"

if [ -d "$release_dir/config" ]; then
	echo "Permission before:"
	ls -ld "$release_dir/"

	echo ""
	echo "Setting the right owner..."

	# The SearXNG entrypoint writes settings.yml here on first start, so
	# make the directory accessible to any user of the pod (NFS root_squash
	# safe).
	chown -R root:root "$release_dir/"
	chmod -R 777 "$release_dir"

	echo ""
	echo "Permission after:"
	ls -ld "$release_dir/"
else
	echo "$release_dir/config doesn't exist and could not be created."
	exit 1
fi
