Directus Helm Chart

## Manual install

```bash
# Example overwriting values
 helm install directus charts/directus/v1.0.0 \
 --set replicaCount=2 \
 --set ingress.enabled=true \
 --set ingress.tlsEnabled=true \
 --set ingress.issuer=letsencrypt-staging \
 --set ingress.hosts[0].host=test.xpaceoff.com,\
ingress.hosts[0].paths[0].path=/,\
ingress.hosts[0].paths[0].pathType=Prefix

# prod
helm install directus charts/directus/v1.0.0
```

## Manual uninstall

```bash
helm uninstall directus
```

## Manual upgrade

```bash
helm upgrade directus charts/directus/v1.0.0
```

