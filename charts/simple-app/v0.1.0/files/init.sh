#!/bin/sh
echo "Running init.sh..."
target_dir="/tmp_mount/$1"

if [ -d "$target_dir" ]; then
	echo "Permission before:"
	ls -l "$target_dir/"

	echo ""
	echo "Setting the right owner..."

	chown -R root:root "$target_dir/"
	chmod 777 "$target_dir"

	echo ""
	echo "Permission after:"
	ls -l "$target_dir/"
else
	echo "$target_dir doesn't exist."
	echo "This is probably because this is a new deployment."
fi
