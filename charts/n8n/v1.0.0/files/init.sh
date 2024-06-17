#!/bin/sh
echo "Running init.sh..."
n8n_dir="/tmp_mount/$1/n8n"

if [ -d "$n8n_dir" ]; then
	echo "Permission before:"
	ls -l "$n8n_dir/"

	echo ""
	echo "Setting the right owner..."
	chown -R node:node "$n8n_dir/"
	chmod 777 "$n8n_dir"

	echo ""
	echo "Permission after:"
	ls -l "$n8n_dir/"
	sleep 5s
fi
