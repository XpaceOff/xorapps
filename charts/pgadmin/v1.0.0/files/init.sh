#!/bin/sh

pgadmin_dir="/tmp_mount/$1/pgadmin"

if [ ! -d "$pgadmin_dir" ]; then
	chown -R pgadminr:root "$pgadmin_dir/*"
fi
