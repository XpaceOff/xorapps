#!/bin/sh
echo "Running init.sh..."
# $1 = release name (isolates each release on the NFS share)
release_dir="/tmp_mount/$1"

# The subPath of a NFS mount must exist on the export before the main
# container starts, so create the release directories on first install.
mkdir -p "$release_dir/n8n_data"
mkdir -p "$release_dir/files"

if [ -d "$release_dir" ]; then
	echo "Permission before:"
	ls -ld "$release_dir/"

	echo ""
	echo "Setting the right owner..."

	# The app writes to these directories as its own user, so make them
	# accessible to any user of the pod.
	chown -R root:root "$release_dir/"
	chmod -R 777 "$release_dir"

	echo ""
	echo "Permission after:"
	ls -ld "$release_dir/"
else
	echo "$release_dir doesn't exist and could not be created."
	exit 1
fi
