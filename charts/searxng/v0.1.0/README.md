SearXNG Helm Chart

SearXNG is a privacy-respecting, hackable metasearch engine.

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

Environment variables (`SEARXNG_SECRET`, `SEARXNG_BASE_URL`, `SEARXNG_CONTACT_URL` and the entries in
`env`) always override matching values in this file. See
https://docs.searxng.org/admin/settings/settings.html for the reference.

## Contact URL

The wikipedia, wikidata and openstreetmap engines must identify the client
to their APIs, so they refuse to load without a contact URL. Turn on **Set a
contact URL** in the Rancher form (**SearXNG Settings** group) and enter an
address you actually read; the chart passes it as
`SEARXNG_CONTACT_URL=mailto:<email>`. With it off, those three engines are
skipped - everything else works.

## Search output formats

SearXNG can return results as `html` (the web UI - always on), `json`,
`csv` and `rss`. For resource reasons only `html` is enabled by default.
The **SearXNG Settings** group has a checkbox per extra format; `json`
enables the JSON search API, e.g. `GET /search?q=searxng&format=json`.

There is no environment variable for this setting, so enabling any of the
checkboxes makes the chart render its own `settings.yml` into the Secret it
manages, containing:

```yaml
use_default_settings: true

server:
  image_proxy: true

search:
  formats:
    - html
    - json
```

Notes:

- Requires Credentials Source **Enter value here** (the chart must render
  the file), and cannot be combined with `searxng.settingsYml` - set
  `search.formats` inside your own file instead.
- The rendered file is mounted over `/etc/searxng/settings.yml`, so with
  `storage.type=NFS` it overlays the copy on the share and the entrypoint
  never writes its own while any format is enabled.

```bash
helm upgrade searxng charts/searxng/v0.1.0 -n <namespace> --reuse-values \
  --set searxng.searchFormats.json=true
```

## Storage (config on NFS)

`storage.type`:

- `None` (default): `/etc/searxng` stays in the pod's ephemeral storage. The
  entrypoint regenerates `settings.yml` on every pod start - which is safe,
  because the random `server.secret_key` it writes is overridden by the
  `SEARXNG_SECRET` env var either way.
- `NFS`: the chart mounts an NFS share at `/etc/searxng`, scoped per release
  via subPath (`<release>/config`). On first start the entrypoint creates
  `settings.yml` **on the share** and it survives pod restarts. You can edit
  the file directly on the share (restart the pod to apply changes) and drop
  extra config files such as `limiter.toml` next to it.

```bash
helm upgrade searxng charts/searxng/v0.1.0 -n <namespace> --reuse-values \
  --set storage.type=NFS \
  --set storage.nfs.hostname=nfs.example.com \
  --set storage.nfs.path=/volume1/k8s
```

Two notes:

- The docker-compose style `./data` mount (`/var/cache/searxng`) has no
  equivalent in this chart: no application code writes there in this release.
- When `searxng.settingsYml` is set, or any extra search output format is
  enabled, the chart-rendered file overlays
  `<share>/<release>/config/settings.yml`, so the entrypoint never writes
  its own copy to the share.

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
server - point `SEARXNG_VALKEY_URL` (or `SEARXNG_REDIS_URL`) at one. When you
enable it, also list your reverse proxies in your `settings.yml` so the
limiter sees the real client addresses:

```yaml
botdetection:
  trusted_proxies:
    - 10.0.0.0/8
```

## Expected log lines

A default install logs a few lines that look alarming but are fine:

- `ahmia: can't register engine` / `torch: can't register engine` - onion
  engines are skipped when no Tor proxy is configured
  (`outgoing.using_tor_proxy`). Every install without Tor shows this.
- `wikipedia/wikidata/openstreetmap engine requires general.contact_url` -
  fixed by turning on **Set a contact URL** and entering an email
  (`SEARXNG_CONTACT_URL`). Those three engines are skipped while it is off.
- `missing config file: /etc/searxng/limiter.toml` - the optional limiter
  config file; only relevant when the limiter is enabled.
- `X-Forwarded-For nor X-Real-IP header is set!` - a request reached the pod
  directly (e.g. `kubectl port-forward`) instead of through the Traefik
  ingress. Through the ingress these headers are always set. Harmless while
  the limiter is off.
- `"/etc/searxng/settings.yml" does not exist, creating from template...` -
  the entrypoint generating its default settings file. Without NFS this
  appears on every pod start; with `storage.type=NFS` it appears once and
  the file then lives on the share.

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
