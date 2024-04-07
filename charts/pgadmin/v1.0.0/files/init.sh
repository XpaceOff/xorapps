#!/bin/sh
echo "Running init.sh..."
pgadmin_dir="/tmp_mount/$1/pgadmin"

if [ -d "$pgadmin_dir" ]; then
	echo "Permission before:"
	ls -l "$pgadmin_dir/"

	echo ""
	echo "Setting the right owner..."
	chown -R 5050:root "$pgadmin_dir/"
	chmod 777 "$pgadmin_dir"

	echo ""
	echo "Permission after:"
	ls -l "$pgadmin_dir/"
fi
