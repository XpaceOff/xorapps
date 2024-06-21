#!/bin/sh
echo "Running init.sh..."
teleport_dir="/tmp_mount/$1"

if [ -d "$teleport_dir" ]; then
	echo "Permission before:"
	ls -l "$teleport_dir/"

	echo ""
	echo "Setting the right owner..."

	# NOTE: I don't know if using root:root is safe, but it makes the app work
	# when data is already written. I would have to check if there is a NFS
	# setting for me to avoid this.
	# TODO: Check if this is safe and make changes if necessary.
	chown -R root:root "$teleport_dir/"
	chmod 777 "$teleport_dir"

	echo ""
	echo "Permission after:"
	ls -l "$teleport_dir/"
else
	echo "$teleport_dir doesn't exist."
	echo "This is probably because this is a new deployment."
fi

sleep 5s
