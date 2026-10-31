#!/bin/sh
echo "Running init.sh..."
# $1 = release name (isolates each release on the NFS share)
# $2 = data subdirectory inside the release directory
release_dir="/tmp_mount/$1"
data_subdir="${2:-pg0}"
data_dir="$release_dir/$data_subdir"

# The subPath of a NFS mount must exist on the export before the main
# container starts, so create the release/data directories on first install.
mkdir -p "$data_dir"

if [ -d "$data_dir" ]; then
	echo "Permission before:"
	ls -ld "$data_dir/"

	echo ""
	echo "Setting the right owner..."

	# The app writes to this directory as its own (unknown) user, so make it
	# accessible to any user of the pod.
	chown -R root:root "$release_dir/"
	chmod -R 777 "$release_dir"

	echo ""
	echo "Permission after:"
	ls -ld "$data_dir/"
else
	echo "$data_dir doesn't exist and could not be created."
	exit 1
fi
