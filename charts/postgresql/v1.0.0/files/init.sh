#!/bin/sh

mkdir -p "/tmp_mount/$1/postgresql/data"
mkdir -p "/tmp_mount/$1/pgadmin"
chmod -R 777 "/tmp_mount/$1"
echo "TEST" >>"/tmp_mount/$1/tmp.txt"
