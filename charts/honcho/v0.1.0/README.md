Honcho Helm Chart

Honcho is the identity layer for the agentic world: memory infrastructure for
stateful agents. The chart deploys the Honcho API, the background worker
(deriver) and, optionally, a PostgreSQL database with pgvector and a Redis
cache.

Upstream: <https://github.com/plastic-labs/honcho>

## Components

| Component  | Resource                | Port | Notes                                                              |
| ---------- | ----------------------- | ---- | ------------------------------------------------------------------ |
| API        | `Deployment` `honcho`   | 8000 | FastAPI server. `/health`, `/docs`, `/metrics`, API under `/v3`      |
| Deriver    | `Deployment` `honcho-deriver` | - | Background worker. `python -m src.deriver`                          |
| Postgres   | `Deployment` `honcho-db` | 5432 | Only with `database.type=internal`. `pgvector/pgvector:pg15`        |
| Redis      | `Deployment` `honcho-redis` | 6379 | Only with `redis.enabled=true` and `redis.type=internal`            |

## Requirements

- **An LLM provider is mandatory.** Honcho refuses to start without one. With
  the built-in defaults a single OpenAI key is enough: text generation uses
  `openai/gpt-5.4-mini`, embeddings use `openai/text-embedding-3-small`.
- **PostgreSQL with the `pgvector` extension.** The chart's internal database
  image provides it. An external database must have it too.
- The migrations create `vector`, `pg_trgm` and `btree_gin`. `pg_trgm` and
  `btree_gin` are optional (without them the message search indexes are
  skipped), but `vector` is not.

## Network isolation

The chart-managed Postgres and Redis are reachable **only by the Honcho pods of
the same release**. Each datastore gets a `NetworkPolicy` that allows
ingress on its port from pods labelled `app.kubernetes.io/instance=<release>`
(the API and the deriver) and from nobody else:

| Resource            | NetworkPolicy        | Allowed from                |
| ------------------- | -------------------- | --------------------------- |
| `honcho-db-cip`     | `honcho-db-np`       | API + deriver, TCP 5432     |
| `honcho-redis-cip`  | `honcho-redis-np`    | API + deriver, TCP 6379     |

Everything else - other releases of Honcho, other applications in the same
namespace, and pods in other namespaces - is rejected by the CNI. Both
datastores are `ClusterIP` services, so they are not reachable from outside
the cluster either.

The policy selects on `app.kubernetes.io/instance`, which Helm sets to the
release name. Two releases of Honcho in the same namespace therefore get
separate databases, each reachable only by its own pods.

This relies on the cluster CNI enforcing `NetworkPolicy`. The CNI in this
cluster (k3s) does enforce it.

When `database.type=external` or `redis.type=external`, the chart deploys no
datastore and creates no policy - securing that service is up to you.

## Secrets

Credentials come from a Secret in the install namespace. Either select one in
the Rancher form (**Existing Secret**), or leave it empty and fill in the
Security and Database fields so the chart creates the Secret
`<release>-honcho-config`).

| Key                    | Required            | Notes                                                                             |
| ---------------------- | ------------------- | --------------------------------------------------------------------------------- |
| `DB_CONNECTION_URI`    | yes                 | `postgresql+psycopg://user:pass@host:5432/dbname`. The `postgresql+psycopg` prefix is mandatory |
| `LLM_OPENAI_API_KEY`   | one provider key    | Also `LLM_ANTHROPIC_API_KEY` / `LLM_GEMINI_API_KEY` for the other transports      |
| `AUTH_JWT_SECRET`      | only with auth      | Hex string that signs the API keys. Changing it invalidates every issued key      |
| `POSTGRES_PASSWORD`    | internal DB only    | Password for the chart-managed Postgres                                           |
| `REDIS_PASSWORD`       | optional            | Password for the cache. Ignored when it is empty                                  |

```bash
kubectl -n <namespace> create secret generic honcho-secrets \
  --from-literal=DB_CONNECTION_URI='postgresql+psycopg://honcho:CHANGE_ME@db.example.com:5432/honcho' \
  --from-literal=LLM_OPENAI_API_KEY='sk-CHANGE_ME'
```

## Manual install

With an existing Postgres and an LLM key:

```bash
helm install honcho charts/honcho/v0.1.0 -n <namespace> \
--set envVars.honcho.openaiApiKey=sk-... \
--set envVars.honcho.dbConnectionUri='postgresql+psycopg://honcho:CHANGE_ME@db.example.com:5432/honcho' \
--set ingress.enabled=true \
--set ingress.tlsEnabled=true \
--set ingress.issuer=letsencrypt-cert-prod \
--set ingress.hostUrl=honcho.example.com
```

With the chart-managed Postgres (the password is written into the chart's
Secret, so prefer `secretSource=existing`):

```bash
helm install honcho charts/honcho/v0.1.0 -n <namespace> \
--set database.type=internal \
--set database.internal.password=CHANGE_ME \
--set storage.type=NFS \
--set storage.nfs.hostname=nfs.example.com \
--set storage.nfs.path=/volume1/k8s \
--set envVars.honcho.openaiApiKey=sk-...
```

With the chart-managed Redis as well:

```bash
helm install honcho charts/honcho/v0.1.0 -n <namespace> \
--set redis.enabled=true \
--set redis.type=internal \
--set envVars.honcho.openaiApiKey=sk-...
```

## Database migrations

The published image does **not** run the migrations on startup - its command is
`fastapi run --host 0.0.0.0 src/main.py`. The chart therefore runs
`python scripts/provision_db.py` in an init container on both the API and the
deriver pod before either of them starts.

That script goes through `src.migrate`, which takes a **Postgres advisory
lock**, so the two pods starting at the same time do not race: one applies the
migrations, the others wait for the lock and then do nothing. Set
`migrations.enabled=false` if you run the migrations yourself.

```bash
kubectl -n <namespace> exec deploy/<release>-honcho -- \
  /app/.venv/bin/python scripts/provision_db.py
```

`helm rollback` does not undo schema changes. Back up the database before
upgrading.

## Deriver

The deriver is the background worker: it extracts observations from messages,
builds peer representations, generates session summaries and runs dream
consolidation. **Without it, messages are stored but no memory is produced.**

It is enabled by default with one replica. Scale it with `deriver.replicas` -
the replicas coordinate through the database queue.

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
  private range (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12` and
  `192.168.0.0/16`. Public sources are always rejected.
- `both`: both hostnames are published side by side. They are separate
  Traefik routers, so the public one keeps its certificate and HTTPS redirect
  while the internal one stays on HTTP and is restricted to the allowed
  networks.

```bash
helm install honcho charts/honcho/v0.1.0 -n <namespace> \
--set ingress.enabled=true \
--set ingress.exposure=both \
--set ingress.hostUrl=honcho.example.com \
--set ingress.internalHostUrl=honcho.internal
```

To allow only specific networks on the internal hostname:

```bash
helm upgrade honcho charts/honcho/v0.1.0 -n <namespace> --reuse-values \
--set-json 'ingress.internalAllowedCidrs=["10.0.0.0/8","192.168.0.0/16"]'
```

Without an Ingress at all (`ingress.enabled=false`), the API is only reachable
in-cluster through the Service:
`http://<release>-honcho-cip.<namespace>.svc.cluster.local:8000`.

## Authentication

With `auth.enabled=true` the API requires a JWT bearer token and the server
refuses to start without `AUTH_JWT_SECRET`. Mint an API key with:

```bash
kubectl -n <namespace> port-forward svc/<release>-honcho-cip 8000:8000 &
curl -s -X POST 'http://127.0.0.1:8000/v3/keys?workspace_id=my-workspace' \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

The key is scoped to the workspace (and optionally to a peer, session or
scope) and is used as the API key by the SDKs.

Leave the authentication off for an instance that is only reachable from the
internal network.

## Verifying the install

```bash
# The API is up
kubectl -n <namespace> port-forward svc/<release>-honcho-cip 8000:8000 &
curl -s http://127.0.0.1:8000/health
# {"status":"ok"}

# The database is connected and the migrations ran
curl -s -X POST http://127.0.0.1:8000/v3/workspaces \
  -H 'Content-Type: application/json' -d '{"name":"test"}'

# The deriver is processing
kubectl -n <namespace> logs deploy/<release>-honcho-deriver --tail 20
```

`/health` only confirms the process is running. It does not check the database
or the LLM provider.

## Manual uninstall

```bash
helm uninstall honcho -n <namespace>
```

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade honcho charts/honcho/v0.1.0 -n <namespace> --reuse-values \
--set image.tag=v3.6.1
```

## Notes

- The image tag carries a `v` prefix (`v3.6.1`). There is no `3.6.1` tag in
  the registry.
- The MCP server is **not** part of this chart. Upstream ships it as a separate
  Bun application that is not published as an image.
- `VECTOR_STORE_TYPE` other than `pgvector` (turbopuffer, lancedb, qdrant,
  chromadb) needs an additional external service and its own settings.
