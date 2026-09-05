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
