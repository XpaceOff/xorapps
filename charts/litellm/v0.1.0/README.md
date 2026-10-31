LiteLLM Helm Chart

## Secrets

Credentials come from a Secret in the install namespace. Either select one in the Rancher form (**Existing Secret**), or leave it empty and fill in the Security and Database fields so the chart creates the Secret.

Keys read from the Secret:

| Key                     | Required         | Notes                                                                                                                                 |
| ----------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `LITELLM_MASTER_KEY`    | yes              | Admin key for the proxy                                                                                                               |
| `LITELLM_SALT_KEY`      | yes              | Encrypts stored credentials. Do not change after first use                                                                            |
| `DATABASE_URL`          | yes              | `postgresql://user:pass@host:5432/db`. For internal Postgres, `postgresql://litellm:<password>@<release>-litellm-db-cip:5432/litellm` |
| `POSTGRES_PASSWORD`     | internal DB only | Password for the chart-managed Postgres                                                                                               |

Create the Secret before installing (replace the placeholder values, and add the Postgres key if you use the chart-managed database):

```bash
kubectl -n <namespace> create secret generic litellm-secrets \
  --from-literal=LITELLM_MASTER_KEY="sk-$(openssl rand -hex 24)" \
  --from-literal=LITELLM_SALT_KEY="$(openssl rand -hex 32)" \
  --from-literal=DATABASE_URL='postgresql://litellm:CHANGE_ME@db.example.com:5432/litellm'
```

For the chart-managed Postgres, also add `--from-literal=POSTGRES_PASSWORD=CHANGE_ME` and set `DATABASE_URL` to the internal service URL (the release name must match the install command).

Keep the master and salt keys: losing the salt key makes stored model credentials unreadable.

## Creating the database user manually

For an existing Postgres server, create a dedicated user and database (run as a superuser, e.g. `postgres`):

```bash
psql -h db.example.com -p 5432 -U postgres
```

```sql
CREATE USER litellm WITH PASSWORD 'CHANGE_ME';
CREATE DATABASE litellm OWNER litellm;
REVOKE ALL ON DATABASE litellm FROM PUBLIC;
GRANT ALL PRIVILEGES ON DATABASE litellm TO litellm;
```

Then use this URL for `DATABASE_URL` (or the Database URL field):

```
postgresql://litellm:CHANGE_ME@db.example.com:5432/litellm
```

If the password contains `@`, `:`, `/`, or `%`, URL-encode it in the URL.

## Manual install

Using an existing Secret:

```bash
helm install litellm charts/litellm/v0.1.0 -n <namespace> \
--set secretSource=existing \
--set existingSecret=litellm-secrets \
--set ingress.enabled=true \
--set ingress.tlsEnabled=true \
--set ingress.issuer=letsencrypt-cert-prod \
--set ingress.hostUrl=litellm.example.com
```

Chart-managed Postgres (values are written into the chart's Secret, so prefer `secretSource=existing`):

```bash
helm install litellm charts/litellm/v0.1.0 -n <namespace> \
--set database.type=internal \
--set database.internal.password=CHANGE_ME \
--set storage.type=NFS \
--set storage.nfs.hostname=nfs.example.com \
--set storage.nfs.path=/volume1/k8s \
--set envVars.litellm.masterKey=sk-... \
--set envVars.litellm.saltKey=...
```

## Ingress exposure

`ingress.exposure` decides how the app is published:

- `external` (default): public hostname, TLS from cert-manager, redirect to HTTPS.
  `ingress.issuer` must be a cert-manager `Issuer` **in the namespace where the
  app is installed** (`cert-manager.io/issuer` is resolved in the same
  namespace). Available in this cluster: `letsencrypt-cert-prod`,
  `letsencrypt-cert-staging`, `rancher`.
- `internal`: the hostname is only resolved by the internal DNS (e.g.
  `litellm.cluster`). A public CA cannot issue a certificate for such a name,
  so the chart renders plain HTTP: no TLS block, no `cert-manager.io/issuer`
  annotation and no HTTPS redirect middleware. In addition, the Traefik
  `ipAllowList` middleware rejects every source outside
  `ingress.internalAllowedCidrs` with **403** — DNS alone is not access
  control, since anyone who knows the Traefik IP can send a request with the
  right `Host` header. The default allows every private range (RFC 1918):
  `10.0.0.0/8` (includes the pods of this cluster), `172.16.0.0/12` and
  `192.168.0.0/16` (includes this LAN). Public sources are always rejected.

```bash
helm install litellm charts/litellm/v0.1.0 -n <namespace> \
--set ingress.enabled=true \
--set ingress.exposure=internal \
--set ingress.hostUrl=litellm.cluster
```

To allow only specific networks:

```bash
helm upgrade litellm charts/litellm/v0.1.0 -n <namespace> --reuse-values \
--set ingress.internalAllowedCidrs="192.168.8.0/24,10.42.0.0/16"
```

Without an Ingress at all (`ingress.enabled=false`), the app is only reachable
in-cluster through the Service:
`http://<release>-litellm-cip.<namespace>.svc.cluster.local:4000`.

## Workers and Redis

By default the chart runs one worker process (`numWorkers: 1`). With one worker and one replica, Redis is not needed.

If you run more than one worker (`numWorkers`) or replica (`replicaCount`), enable Redis so rate limits, budgets, and router state are shared. Without it LiteLLM shows a warning and enforces limits per worker.

Use an existing Redis server:

```bash
helm upgrade litellm charts/litellm/v0.1.0 -n <namespace> --reuse-values \
--set numWorkers=4 \
--set redis.enabled=true \
--set redis.host=redis.<namespace>.svc.cluster.local \
--set redis.port=6379 \
--set redis.password=CHANGE_ME
```

If you use an existing Secret, add `REDIS_PASSWORD` to it instead of setting `redis.password`. The Secret can be created with:

```bash
kubectl -n <namespace> create secret generic litellm-secrets \
  --from-literal=REDIS_PASSWORD='CHANGE_ME' \
  ...
```

Redis options:

- **Existing Redis** (`redis.type=external`): set `redis.host` and `redis.port`.
- **Chart-managed Redis** (`redis.type=internal`): the chart deploys Redis with no persistence. A NetworkPolicy allows connections only from LiteLLM pods in this release.

```bash
helm upgrade litellm charts/litellm/v0.1.0 -n <namespace> --reuse-values \
--set redis.enabled=true \
--set redis.type=internal
```

The Redis password is optional. Leave `redis.password` empty for no password. The NetworkPolicy is what restricts access in that case, so keep it in place and make sure your cluster's CNI enforces NetworkPolicy.

## Manual uninstall

```bash
helm uninstall litellm -n <namespace>
```

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade litellm charts/litellm/v0.1.0 -n <namespace> --reuse-values \
--set image.tag=v1.106.4
```
