Vaultwarden Helm Chart

Deploys [Vaultwarden](https://github.com/dani-garcia/vaultwarden) with its data
on an NFS volume and an optional Traefik ingress.

## Ingress exposure

`ingress.exposure` decides which hostnames are published:

- `external` (default): the **public** hostname (`ingress.hostUrl`), TLS from
  cert-manager, redirect to HTTPS. `ingress.issuer` must be a cert-manager
  `Issuer` **in the namespace where the app is installed**
  (`cert-manager.io/issuer` is resolved in the same namespace). Available in
  this cluster: `letsencrypt-cert-prod`, `letsencrypt-cert-staging`, `rancher`.
- `internal`: the **internal** hostname (`ingress.internalHostUrl`), resolved
  only by the internal DNS. A public CA cannot issue a certificate for such a
  name, so it is served over plain HTTP. The Traefik `ipAllowList` middleware
  rejects every source outside `ingress.internalAllowedCidrs` with **403** —
  DNS alone is not access control, since anyone who knows the Traefik IP can
  send a request with the right `Host` header. The default allows every
  private range (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12` and
  `192.168.0.0/16`. Public sources are always rejected.
- `both`: both hostnames are published side by side. They are separate
  Traefik routers, so the public one keeps its certificate and HTTPS redirect
  while the internal one stays on HTTP and is restricted to the allowed
  networks.

```bash
helm install vaultwarden charts/vaultwarden/v1.0.0 -n <namespace> \
--set ingress.enabled=true \
--set ingress.exposure=internal \
--set ingress.internalHostUrl=vaultwarden.cluster \
--set env.DOMAIN="https://vaultwarden.example.com" \
--set volumes[0].name=vol-vw \
--set volumes[0].nfs.server=nfs.example.com \
--set volumes[0].nfs.path=/volume1/k8s/vaultwarden
```

To allow only specific networks on the internal hostname:

```bash
helm upgrade vaultwarden charts/vaultwarden/v1.0.0 -n <namespace> --reuse-values \
--set-json 'ingress.internalAllowedCidrs=["10.0.0.0/8","192.168.0.0/16"]'
```

## Domain

`env.DOMAIN` is the public URL of the instance — it is what the clients use to
reach it and what Vaultwarden puts in its emails. It does not have to match
the ingress hostname (a proxy in front of the cluster is fine).

## Storage

`volumes[0]` is mounted at `/data` (subPath `vw-data`) and holds the database
and the attachments. The NFS path must be an existing, exported directory.

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade vaultwarden charts/vaultwarden/v1.0.0 -n <namespace> --reuse-values \
--set image.tag=1.37.5
```

## Manual uninstall

```bash
helm uninstall vaultwarden -n <namespace>
```
