n8n Helm Chart

Deploys [n8n](https://n8n.io) with an optional NFS-backed data directory and an
optional Traefik ingress.

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
helm install n8n charts/n8n/v1.0.0 -n <namespace> \
--set ingress.enabled=true \
--set ingress.exposure=both \
--set ingress.hostUrl=n8n.example.com \
--set ingress.internalHostUrl=n8n.internal
```

## Public URL (chat trigger and webhooks)

n8n builds the URLs it hands back to the browser from `N8N_EDITOR_BASE_URL`
and `WEBHOOK_URL`. When they are not set, n8n falls back to `localhost` and
the chat widget fails with **"Failed to receive response"** (the browser
refuses to fetch `http://localhost:5678/...`).

The chart derives them from the ingress hostname:

| Variable | Derived from |
|---|---|
| `N8N_EDITOR_BASE_URL` | `<scheme>://<hostname><hostPath>` |
| `WEBHOOK_URL` | `<scheme>://<hostname>/` |
| `N8N_HOST` | `<hostname>` (no protocol) |

The scheme is `https` when the public hostname has a certificate, otherwise
`http`. Override them when n8n is reached through another address than the
ingress (or when there is no ingress at all):

```bash
helm install n8n charts/n8n/v1.0.0 -n <namespace> \
--set envVars.n8n.editorBaseUrl=https://n8n.example.com/ \
--set envVars.n8n.webhookUrl=https://n8n.example.com/
```

## Storage

`storage.nfs.hostname` and `storage.nfs.path` point at an **existing,
exported** directory (e.g. `/volume1/k8s`). The chart mounts two subpaths of
it, `<release>/n8n_data` (the n8n database and config) and `<release>/files`
(uploads). An init container creates both directories on the share before the
main container starts, so a fresh install works.

Leave the NFS fields empty to run without persistent storage — the database
is then lost when the pod is replaced.

## Manual install

```bash
helm install n8n charts/n8n/v1.0.0 -n <namespace> \
--set envVars.n8n.dbType=postgresdb \
--set envVars.n8n.dbHost=postgres.example.com \
--set envVars.n8n.dbPort=5432 \
--set envVars.n8n.dbName=n8n \
--set envVars.n8n.dbUser=n8n-user \
--set envVars.n8n.dbPass=CHANGE_ME \
--set storage.nfs.hostname=nfs.example.com \
--set storage.nfs.path=/volume1/k8s \
--set ingress.enabled=true \
--set ingress.hostUrl=n8n.example.com \
--set ingress.issuer=letsencrypt-cert-prod
```

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade n8n charts/n8n/v1.0.0 -n <namespace> --reuse-values \
--set ingress.exposure=both \
--set ingress.internalHostUrl=n8n.internal
```

## Manual uninstall

```bash
helm uninstall n8n -n <namespace>
```
