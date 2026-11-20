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
	# A hard pod kill (node crash, OOM, kubelet grace expiry) leaves a stale
	# postmaster.pid behind. PostgreSQL recovers from it, but the recorded PID
	# belongs to the previous container's PID namespace and may collide with a
	# live PID in this one, which can trick a freshly started postmaster into
	# shutting itself down. With the Recreate strategy and replicaCount=1 no
	# other pod can be using the data directory while this runs, so any
	# pidfile found here is stale by definition.
	find "$data_dir" -maxdepth 3 -name postmaster.pid -type f -print -delete 2>/dev/null

	echo "Permission before:"
	ls -ld "$data_dir/"

	echo ""
	echo "Setting the right owner..."

	# The image runs as uid 1000 (hindsight). Embedded Postgres refuses to start
	# when the data directory is owned by another user, so match that owner and
	# keep the data private to it.
	chown -R 1000:1000 "$release_dir/"
	chmod -R u+rwX,go-rwx "$release_dir/"

	echo ""
	echo "Permission after:"
	ls -ld "$data_dir/"
else
	echo "$data_dir doesn't exist and could not be created."
	exit 1
fi
