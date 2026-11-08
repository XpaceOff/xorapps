#!/bin/sh
echo "Running init.sh..."
app_dir="/tmp_mount/$1"
data_dir="$app_dir/$2"

echo "Creating $data_dir if it does not exist..."
mkdir -p "$data_dir"

echo "Permission before:"
ls -ld "$data_dir"

echo ""
echo "Setting the right owner..."
chown -R root:root "$data_dir"
chmod 777 "$data_dir"

echo ""
echo "Permission after:"
ls -ld "$data_dir"
