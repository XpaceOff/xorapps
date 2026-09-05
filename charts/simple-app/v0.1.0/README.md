# simple-app Helm Chart

Generic single-container chart. Set the image, container port, optional NFS
storage, and ingress. Useful for quickly deploying an off-the-shelf image
without writing a bespoke chart.

## Manual install

```bash
helm install my-app charts/simple-app/v0.1.0 \
  --set image.repository=nginx \
  --set image.tag=1.27 \
  --set containerPort=80 \
  --set service.port=80 \
  --set ingress.enabled=true \
  --set ingress.hostUrl=app.example.com \
  --set ingress.tlsEnabled=true \
  --set ingress.issuer=letsencrypt-prod \
  --set ingress.forceHttps=true \
  --set storage.nfs.hostname=nfs.example.com \
  --set storage.nfs.path=/exports/apps \
  --set storage.mountPath=/usr/share/nginx/html \
  -n my-namespace
```

## Manual upgrade

```bash
helm upgrade my-app charts/simple-app/v0.1.0 -n my-namespace
```

## Manual uninstall

```bash
helm uninstall my-app -n my-namespace
```

## NFS storage notes

`storage.nfs.path` must be an **existing, exported** directory on the NFS
server. Do **not** append a release-specific subfolder to it - the chart
already isolates each release by mounting with `subPath: <release-fullname>`
underneath that path.

Example (correct):

```
storage.nfs.hostname = rmnas.opt2
storage.nfs.path     = /volume1/cluspi/tmp     # exists and is exported
```

The chart then mounts `/volume1/cluspi/tmp/<release-fullname>` into the
container at `storage.mountPath`.

If the mount fails with

```
mount.nfs: mounting <host>:<path> failed, reason given by server:
No such file or directory
```

it means one of:

1. The path doesn't exist on the NAS - create it, or point at an existing parent.
2. The path (or an ancestor) is not in the NFS server's export list.
3. The cluster node's IP is not allowed by the export's client rules.

Verify from any Linux host on the cluster network with:

```bash
showmount -e <nfs-hostname>
```

The value of `storage.nfs.path` must match (or be a subdirectory of) one of
the exports listed there. The busybox init container that fixes permissions
cannot help here - it only runs after the NFS mount succeeds.
