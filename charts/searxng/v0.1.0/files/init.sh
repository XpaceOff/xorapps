#!/bin/sh
echo "Running init.sh..."
# $1 = release name (isolates each release on the NFS share)
# $2 = chart-managed settings mode:
#        render - copy the settings.yml mounted at $3 onto the share
#        clean  - remove a settings.yml the chart rendered previously, so
#                 the container entrypoint regenerates its own
# $3 = path of the chart-rendered settings.yml (render mode)
release_dir="/tmp_mount/$1"
mode="${2:-}"
src="${3:-}"
target="$release_dir/config/settings.yml"
marker="# managed-by: xorapps-searxng-chart - the Rancher form owns this file while a settings source is enabled"

# The subPath of a NFS mount must exist on the export before the main
# container starts, so create the release directory on first install.
mkdir -p "$release_dir/config"

if [ -d "$release_dir/config" ]; then
	echo "Permission before:"
	ls -ld "$release_dir/"

	echo ""
	echo "Setting the right owner..."

	# The SearXNG entrypoint (and the chart, in render mode) writes into this
	# directory, so make it accessible to any user of the pod (NFS root_squash
	# safe).
	chown -R root:root "$release_dir/"
	chmod -R 777 "$release_dir"

	echo ""
	echo "Permission after:"
	ls -ld "$release_dir/"
else
	echo "$release_dir/config doesn't exist and could not be created."
	exit 1
fi

case "$mode" in
render)
	echo "Writing chart-managed $target ..."
	echo "$marker" > "$target.new"
	cat "$src" >> "$target.new"
	mv "$target.new" "$target"
	;;
clean)
	if [ -f "$target" ] && [ "$(head -n 1 "$target")" = "$marker" ]; then
		rm -f "$target"
		echo "Removed chart-managed $target (no settings source enabled anymore)"
	fi
	;;
esac
