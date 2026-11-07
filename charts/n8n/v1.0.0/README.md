# n8n Helm Chart

Deploys [n8n](https://n8n.io) with an optional NFS-backed data directory, task
runners and an optional Traefik ingress.

## Task runners

n8n 2.x runs the Code node in a separate process (the *task runner*). The chart
deploys it as its own workload:

| Component | Image | Purpose |
|---|---|---|
| n8n | `n8nio/n8n:2.47.2` | editor, API and the task **broker** (port 5679) |
| runners | `n8nio/runners:2.47.2` | executes the JavaScript/Python code |

The runner image version **must match the n8n version exactly**. Leave
`runners.image.tag` empty to always use the n8n image tag.

Both share the secret `N8N_RUNNERS_AUTH_TOKEN`:

- `secretSource=create`: put the token in `runners.authToken` (the form field
  *Runners Auth Token*). It is rendered into the release Secret
  `<release>-config`.
- `secretSource=existing`: the chart uses the Secret named in
  `existingSecret`, which must contain the key `N8N_RUNNERS_AUTH_TOKEN`.

```bash
kubectl -n <namespace> create secret generic n8n-secrets \
  --from-literal=N8N_RUNNERS_AUTH_TOKEN="$(openssl rand -hex 32)"
```

The broker listens on `0.0.0.0:5679` inside the n8n pod and is published on
the ClusterIP Service only — the ingress never routes it.

Optional runner settings:

| Value | Description |
|---|---|
| `runners.replicaCount` | Number of runner pods |
| `runners.nativePythonRunner` | Run Python code inside the n8n process |
| `runners.autoShutdownTimeout` | Seconds of inactivity before the runner exits (0 = never) |
| `runners.maxConcurrency` | Runner instances kept ready (0 = the image default) |
| `runners.launcherConfig` | Custom launcher config, mounted at `/etc/n8n-task-runners.json` |

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
exported** directory (e.g. `/volume1/k8s`). The chart mounts four subpaths of
it: `<release>/n8n_data` (the n8n database and config), `<release>/files`
(uploads), `<release>/backups` and `<release>/secrets`. An init container
creates them on the share before the main container starts, so a fresh install
works.

Leave the NFS fields empty to run without persistent storage — the database
is then lost when the pod is replaced.

## Environment variables

Besides the database and SMTP settings, the chart sets:

| Variable | Value |
|---|---|
| `N8N_EDITOR_BASE_URL` | `<scheme>://<hostname><hostPath>` — what the browser calls back |
| `WEBHOOK_URL` | `<scheme>://<hostname>/` — production webhook URLs |
| `N8N_HOST` | `<hostname>` (no protocol) |
| `TZ` | `envVars.n8n.timezone` |
| `NODE_FUNCTION_ALLOW_BUILTIN` | `envVars.n8n.nodeFunctionAllowBuiltin` |
| `NODES_EXCLUDE` | `envVars.n8n.nodesExclude` |
| `DB_SQLITE_POOL_SIZE` | `envVars.n8n.sqlitePoolSize` |
| `N8N_RESTRICT_FILE_ACCESS_TO` | `envVars.n8n.restrictFileAccessTo` |
| `N8N_SKIP_AUTH_ON_OAUTH_CALLBACK` | `envVars.n8n.skipAuthOnOauthCallback` |
| `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS` | `envVars.n8n.enforceSettingsFilePermissions` |

## Manual install

```bash
helm install n8n charts/n8n/v1.0.0 -n <namespace> \
--set envVars.n8n.dbType=postgresdb \
--set envVars.n8n.dbHost=postgres.example.com \
--set envVars.n8n.dbPort=5432 \
--set envVars.n8n.dbName=n8n \
--set envVars.n8n.dbUser=n8n-user \
--set envVars.n8n.dbPass=CHANGE_ME \
--set runners.authToken="$(openssl rand -hex 32)" \
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
