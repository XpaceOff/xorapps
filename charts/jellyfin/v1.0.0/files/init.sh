#!/bin/sh
echo "Running init.sh..."
jellyfin_dir="/tmp_mount/$1"

if [ -d "$jellyfin_dir" ]; then
	echo "Permission before:"
	ls -l "$jellyfin_dir/"

	echo ""
	echo "Setting the right owner..."

	# NOTE: I don't know if using root:root is safe, but it makes the app work
	# when data is already written. I would have to check if there is a NFS
	# setting for me to avoid this.
	# TODO: Check if this is safe and make changes if necessary.
	chown -R root:root "$jellyfin_dir/"
	chmod 777 "$jellyfin_dir"

	echo ""
	echo "Permission after:"
	ls -l "$jellyfin_dir/"
else
	echo "$jellyfin_dir doesn't exist."
	echo "This is probably because this is a new deployment."
fi
