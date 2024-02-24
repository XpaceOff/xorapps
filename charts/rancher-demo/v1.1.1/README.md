

## Manual install

```bash
# Example overwriting values
 helm install rancher-demo charts/rancher-demo/v1.0.0 \
 --set replicaCount=2 \
 --set ingress.enabled=true \
 --set ingress.tlsEnabled=true \
 --set ingress.issuer=letsencrypt-staging \
 --set ingress.hosts[0].host=test.xpaceoff.com,\
ingress.hosts[0].paths[0].path=/,\
ingress.hosts[0].paths[0].pathType=Prefix

# prod
helm install rancher-demo charts/rancher-demo/v1.0.0

# dev
helm install dev charts/rancher-demo/v1.0.0
```

## Manual uninstall

```bash
# prod
helm uninstall rancher-demo

# dev
helm uninstall dev
```

## Manual upgrade

```bash
# prod
helm upgrade rancher-demo charts/rancher-demo/v1.0.0

# dev
helm upgrade dev charts/rancher-demo/v1.0.0
```
