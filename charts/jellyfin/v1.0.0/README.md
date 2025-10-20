## Manual install

```bash
# Example overwriting values
helm install jellyfin jellyfin/v1.0.0 \
--set ingress.hostUrl="jelly.lan" \
--set storage.type="NFS" \
--set storage.nfs.hostname="local-nas.lan" \
--set storage.nfs.path="/volume/cluspi/production/" \
--set storage.medianfs.hostname="local-nas.lan" \
--set storage.medianfs.path="/volume/media/" \
--namespace production
```

## Manual upgrade

```bash
# prod
helm upgrade jellyfin charts/jellyfin/v1.0.0 --namespace production

# dev
helm upgrade jellyfin-dev charts/jellyfin/v1.0.0 --namespace dev
```

## Manual uninstall

```bash
# prod
helm uninstall jellyfin

# dev
helm uninstall jellyfin-dev
```
