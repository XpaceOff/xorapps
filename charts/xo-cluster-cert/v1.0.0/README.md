## Options

- `certmanager.issuerKind`: `ClusterIssuer` or `Issuer`
- `certmanager.issuerType`: `letsencrypt` or `selfisgned`

## Manual install

```bash
# Example overwriting values
helm install test charts/xo-cluster-cert/v1.0.0 \
--set certmanager.issuerKind=ClusterIssuer \
--set certmanager.issuerType=letsencrypt \
--set certmanager.acme.email="test@example.com" \
--namespace dev

# prod
helm install xo-cluster-cert charts/xo-cluster-cert/v1.0.0 --namespace prod

# dev
helm install dev charts/xo-cluster-cert/v1.0.0 --namespace dev
```

## Manual upgrade

```bash
# prod
helm upgrade xo-cluster-cert charts/xo-cluster-cert/v1.0.0 --namespace prod

# dev
helm upgrade dev charts/xo-cluster-cert/v1.0.0 --namespace dev
```

## Manual uninstall

```bash
# prod
helm uninstall xo-cluster-cert

# dev
helm uninstall dev
```
