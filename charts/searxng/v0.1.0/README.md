SearXNG Helm Chart

SearXNG is a privacy-respecting, hackable metasearch engine. The chart runs the
upstream image (`ghcr.io/searxng/searxng`) behind Traefik, on port 8080.

## Secrets

`SEARXNG_SECRET` signs sessions and protects against CSRF. It must stay the
same across restarts, otherwise users are logged out on every pod restart.
It comes from a Secret in the install namespace. Either select one in the
Rancher form (**Existing Secret**), or leave it empty and fill in the
**SearXNG Secret** field so the chart creates the Secret.

Keys read from the Secret:

| Key             | Required | Notes                                                        |
| --------------- | -------- | ------------------------------------------------------------ |
| `SEARXNG_SECRET` | yes     | Long random string, e.g. `openssl rand -hex 32`              |

Create the Secret before installing (replace the placeholder value):

```bash
kubectl -n <namespace> create secret generic searxng-secrets \
  --from-literal=SEARXNG_SECRET="$(openssl rand -hex 32)"
```

With `secretSource=create` the secret is rendered into the chart's Secret
`<release>-config` - it then sits in the Helm release history, so prefer
`secretSource=existing` for real deployments.

## Manual install

Using an existing Secret:

```bash
helm install searxng charts/searxng/v0.1.0 -n <namespace> \
  --set secretSource=existing \
  --set existingSecret=searxng-secrets \
  --set ingress.enabled=true \
  --set ingress.hostUrl=searxng.example.com
```

With the chart-managed Secret:

```bash
helm install searxng charts/searxng/v0.1.0 -n <namespace> \
  --set searxng.secret=CHANGE_ME \
  --set ingress.enabled=true \
  --set ingress.hostUrl=searxng.example.com
```

## Base URL

SearXNG advertises an absolute URL for itself (redirects, the opensearch
plugin): `SEARXNG_BASE_URL`. The chart derives it from the ingress hostname
(`https://searxng.example.com/` in the examples above) - or from the internal
hostname when only the internal one is published. Without an ingress the
variable is not set and SearXNG derives the URL from the request `Host`
header. Override it with `searxng.baseUrl` when the app is reached through
another address than the ingress.

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
  rejects every source outside `ingress.internalAllowedCidrs` with **403** -
  DNS alone is not access control, since anyone who knows the Traefik IP can
  send a request with the right `Host` header. The default allows every
  private range (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16`.
- `both`: both hostnames are published side by side. They are separate Traefik
  routers, so the public one keeps its certificate and HTTPS redirect while
  the internal one stays on HTTP and is restricted to the allowed networks.

```bash
helm install searxng charts/searxng/v0.1.0 -n <namespace> \
  --set secretSource=existing \
  --set existingSecret=searxng-secrets \
  --set ingress.enabled=true \
  --set ingress.exposure=both \
  --set ingress.hostUrl=searxng.example.com \
  --set ingress.internalHostUrl=searxng.internal
```

To allow only specific networks on the internal hostname:

```bash
helm upgrade searxng charts/searxng/v0.1.0 -n <namespace> --reuse-values \
  --set-json 'ingress.internalAllowedCidrs=["10.0.0.0/8","192.168.0.0/16"]'
```

Without an Ingress at all (`ingress.enabled=false`), the app is only reachable
in-cluster through the Service:
`http://<release>-searxng-cip.<namespace>.svc.cluster.local:8080`.

## Custom settings.yml

Optional: paste a full `settings.yml` into `searxng.settingsYml` (Rancher field
**Custom settings.yml**, only with Credentials Source **Enter value here**).
The chart writes it into its Secret and mounts it at
`/etc/searxng/settings.yml`. Start from the upstream template and extend it:

```yaml
use_default_settings: true

server:
  image_proxy: true

general:
  contact_url: "mailto:admin@example.com"
```

Environment variables (`SEARXNG_SECRET`, `SEARXNG_BASE_URL` and the entries in
`env`) always override matching values in this file. See
https://docs.searxng.org/admin/settings/settings.html for the reference.

## Storage

`storage.type`:

- `None` (default): SearXNG keeps only a disposable cache
  (`/var/cache/searxng`) in the pod's ephemeral storage.
- `NFS`: the cache directory lives on an NFS share, scoped per release via
  subPath (`<release>/cache`). The share path must already be exported.

```bash
helm upgrade searxng charts/searxng/v0.1.0 -n <namespace> --reuse-values \
  --set storage.type=NFS \
  --set storage.nfs.hostname=nfs.example.com \
  --set storage.nfs.path=/volume1/k8s
```

## Extra environment variables

SearXNG reads many settings from `SEARXNG_*` environment variables (they
override `settings.yml`). Pass them through `env` in `values.yaml`:

```yaml
env:
  - name: SEARXNG_LIMITER
    value: "true"
  - name: SEARXNG_VALKEY_URL
    value: valkey://valkey.example.com:6379/0
```

The bot-detection limiter (`SEARXNG_LIMITER=true`) requires a Valkey/Redis
server - point `SEARXNG_VALKEY_URL` (or `SEARXNG_REDIS_URL`) at one.

## Manual uninstall

```bash
helm uninstall searxng -n <namespace>
```

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade searxng charts/searxng/v0.1.0 -n <namespace> --reuse-values \
  --set image.tag=2026.11.20-1ebea4a07
```
