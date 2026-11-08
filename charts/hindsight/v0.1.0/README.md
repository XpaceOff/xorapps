Hindsight Helm Chart

Hindsight is an agent memory service (Vectorize). The chart deploys the
`ghcr.io/vectorize-io/hindsight` image with an embedded Postgres database
(`.pg0`), an optional NFS-backed data directory and an optional Traefik ingress.

## Ports

| Port | Purpose |
|---|---|
| 8888 | Hindsight API |
| 9999 | Control Plane (web UI) |

Both ports are exposed by the `ClusterIP` Service. The main ingress hostname
routes to the Control Plane (`ingress.port`, default `9999`); enable
`ingress.api.enabled` to expose the API on a second hostname.

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

The optional API hostname follows the same rule: `ingress.api.hostUrl` is the
public one and `ingress.api.internalHostUrl` the internal one.

```bash
helm install hindsight charts/hindsight/v0.1.0 -n <namespace> \
--set ingress.enabled=true \
--set ingress.exposure=both \
--set ingress.hostUrl=hindsight.example.com \
--set ingress.internalHostUrl=hindsight.internal
```

To allow only specific networks on the internal hostname:

```bash
helm upgrade hindsight charts/hindsight/v0.1.0 -n <namespace> --reuse-values \
--set-json 'ingress.internalAllowedCidrs=["10.0.0.0/8","192.168.0.0/16"]'
```

Without an Ingress at all (`ingress.enabled=false`), the app is only reachable
in-cluster through the Service:

- API: `http://<release>-hindsight-cip.<namespace>.svc.cluster.local:8888`
- Control Plane: `http://<release>-hindsight-cip.<namespace>.svc.cluster.local:9999`

## Credentials

Credentials come from a Secret in the install namespace. Either create it from the form (**Credentials Source: Enter values here**) or select an existing one (**Use an existing Secret**).

| Key | Required | Notes |
|---|---|---|
| `HINDSIGHT_API_LLM_API_KEY` | for `openai` provider | API key for the LLM endpoint |

Create the Secret before installing when using an existing one (it must live in
the same namespace as the release):

```bash
kubectl -n <namespace> create secret generic hindsight-secrets \
  --from-literal=HINDSIGHT_API_LLM_API_KEY="CHANGE_ME"
```

With `secretSource=create` the key is rendered into the release Secret
`<release>-config` and therefore ends up in the Helm release history.

The `ollama` provider needs no key, so no Secret is required for it.

## LLM provider

- **openai**: any OpenAI-compatible endpoint, e.g. LiteLLM (`http://litellm.example.com:4000/v1`). Requires the API key.
- **ollama**: a local Ollama server (`http://ollama.example.com:11434/v1`). No key needed.

Environment variables passed to the container:

| Variable | Value |
|---|---|
| `HINDSIGHT_API_LLM_PROVIDER` | `llm.provider` |
| `HINDSIGHT_API_LLM_BASE_URL` | `llm.baseUrl` |
| `HINDSIGHT_API_LLM_API_KEY` | from the Secret |
| `HINDSIGHT_API_LLM_MODEL` | `llm.model` |
| `HINDSIGHT_API_LLM_MAX_CONCURRENT` | `llm.maxConcurrent` |
| `HINDSIGHT_API_LLM_TIMEOUT` | `llm.timeout` (seconds) |

## Storage

`storage.type=None` (default) keeps the embedded database in an `emptyDir`: the
data is lost when the pod is replaced.

`storage.type=NFS` mounts the export at `storage.mountPath`
(`/home/hindsight/.pg0`) using `subPath: <release>/pg0`, so several releases can
share one export. An init container creates the release directory on the share
and fixes its permissions before the main container starts. The NFS path must be
an **existing, exported** directory (e.g. `/volume1/k8s`).

Because the embedded Postgres data directory is a single-writer store, keep
`replicaCount: 1` when using NFS.

## Memory

The container needs shared memory; the chart mounts an `emptyDir` with
`medium: Memory` and a `1Gi` limit at `/dev/shm` (equivalent to the compose
file's `shm_size: 1g`). Set `resources.limits.memory` above 1Gi, otherwise the
pod is killed for exceeding its memory limit.

## Manual install

Same configuration as the docker-compose setup (LiteLLM as the LLM endpoint):

```bash
helm install hindsight charts/hindsight/v0.1.0 -n <namespace> \
--set llm.provider=openai \
--set llm.baseUrl=http://litellm.example.com:4000/v1 \
--set llm.model=gpt-oss-20b \
--set llm.maxConcurrent=4 \
--set llm.timeout=300 \
--set llm.apiKey=<LITELLM_API_KEY>
```

With an existing Secret, an ingress and NFS storage:

```bash
kubectl -n <namespace> create secret generic hindsight-secrets \
  --from-literal=HINDSIGHT_API_LLM_API_KEY="CHANGE_ME"

helm install hindsight charts/hindsight/v0.1.0 -n <namespace> \
--set secretSource=existing \
--set existingSecret=hindsight-secrets \
--set llm.provider=openai \
--set llm.baseUrl=http://litellm.example.com:4000/v1 \
--set llm.model=gpt-oss-20b \
--set storage.type=NFS \
--set storage.nfs.hostname=nfs.example.com \
--set storage.nfs.path=/volume1/k8s \
--set ingress.enabled=true \
--set ingress.tlsEnabled=true \
--set ingress.issuer=letsencrypt-prod \
--set ingress.hostUrl=hindsight.example.com \
--set ingress.api.enabled=true \
--set ingress.api.hostUrl=api.hindsight.example.com
```

Ollama instead of LiteLLM:

```bash
helm install hindsight charts/hindsight/v0.1.0 -n <namespace> \
--set llm.provider=ollama \
--set llm.baseUrl=http://ollama.example.com:11434/v1 \
--set llm.model=qwen3:14b
```

## Manual uninstall

```bash
helm uninstall hindsight -n <namespace>
```

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade hindsight charts/hindsight/v0.1.0 -n <namespace> --reuse-values \
--set llm.model=gpt-oss-20b
```

## Image tag

The chart is pinned to `image.tag: "1.1.0"` with `image.pullPolicy: IfNotPresent`
(the all-in-one image: API + Control Plane + embedded Postgres). Upstream
releases: <https://github.com/vectorize-io/hindsight/releases>.

To track the newest release instead:

```bash
helm upgrade hindsight charts/hindsight/v0.1.0 -n <namespace> --reuse-values \
--set image.tag=latest \
--set image.pullPolicy=Always
```

## Health checks

| Probe | Endpoint | Behaviour |
|---|---|---|
| liveness | `GET /health/live` | In-process only, never touches the database |
| readiness | `GET /health` | Verifies the database is reachable; a pod that fails it is removed from the Service |

## Worker identity

`HINDSIGHT_API_WORKER_ID` is set to the release name, which stays the same
across pod restarts. Hindsight warns when the worker id changes: tasks left in
`processing` under the old id are never recovered. Keep `replicaCount: 1` with
the embedded database; if you scale out, set `workerId` to something unique
per pod.
