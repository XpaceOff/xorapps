OpenViking Helm Chart

OpenViking is a context database for AI agents. This chart runs the server (API on port 1933, Web Studio at `/studio`) with Vikingbot disabled, as a server-only deployment.

## Secrets

Credentials come from a Secret in the install namespace. Either select one in the Rancher form (**Existing Secret**), or leave it empty and fill in the Security fields so the chart creates the Secret.

Keys read from the Secret:

| Key                         | Required | Notes                                                                 |
| --------------------------- | -------- | --------------------------------------------------------------------- |
| `OPENVIKING_ROOT_API_KEY`   | yes      | Root key for the HTTP API (`auth_mode: api_key`)                      |
| `OPENAI_API_KEY`            | yes      | Used by the embedding model (`text-embedding-3-small`) and the VLM    |

The keys are never written into `ov.conf`: the ConfigMap holds `${OPENVIKING_ROOT_API_KEY}` and `${OPENAI_API_KEY}` placeholders, which the server resolves from its environment at startup.

Create the Secret before installing (replace the placeholder values):

```bash
kubectl -n <namespace> create secret generic openviking-secrets \
  --from-literal=OPENVIKING_ROOT_API_KEY="$(openssl rand -hex 32)" \
  --from-literal=OPENAI_API_KEY='CHANGE_ME'
```

## Manual install

Using an existing Secret:

```bash
helm install openviking charts/openviking/v0.1.0 -n <namespace> \
--set secretSource=existing \
--set existingSecret=openviking-secrets
```

Chart-managed Secret (values are written into the chart's Secret, so prefer `secretSource=existing`):

```bash
helm install openviking charts/openviking/v0.1.0 -n <namespace> \
--set envVars.openviking.rootApiKey=CHANGE_ME \
--set envVars.openviking.openaiApiKey=sk-...
```

## Storage

OpenViking keeps its workspace (`/app/.openviking/data`: the vector DB and file metadata) on an NFS share when `storage.type=NFS`. Each release gets its own subdirectory (`<release>-openviking/data`) on an existing export.

```bash
helm install openviking charts/openviking/v0.1.0 -n <namespace> \
--set secretSource=existing \
--set existingSecret=openviking-secrets \
--set storage.type=NFS \
--set storage.nfs.hostname=nfs.example.com \
--set storage.nfs.path=/volume1/k8s
```

With `storage.type=None` (the default) the workspace is an emptyDir, so all indexed data is lost when the pod is replaced.

The workspace has a single writer. Keep `replicaCount` at `1`; the Deployment uses the `Recreate` strategy so a rollout never runs two pods against the same data.

## Ingress exposure

`ingress.exposure` decides which hostnames are published:

- `external` (default): the **public** hostname (`ingress.hostUrl`), TLS from cert-manager, redirect to HTTPS. `ingress.issuer` must be a cert-manager `Issuer` **in the namespace where the app is installed**. Available in this cluster: `letsencrypt-cert-prod`, `letsencrypt-cert-staging`, `rancher`.
- `internal`: the **internal** hostname (`ingress.internalHostUrl`), resolved only by the internal DNS. It is served over plain HTTP and the Traefik `ipAllowList` middleware rejects every source outside `ingress.internalAllowedCidrs` with **403**. The default allows every private range (RFC 1918).
- `both`: both hostnames are published side by side, each with its own treatment.

```bash
helm upgrade openviking charts/openviking/v0.1.0 -n <namespace> --reuse-values \
--set ingress.enabled=true \
--set ingress.exposure=external \
--set ingress.hostUrl=openviking.example.com \
--set ingress.issuer=letsencrypt-cert-prod
```

To allow only specific networks on the internal hostname:

```bash
helm upgrade openviking charts/openviking/v0.1.0 -n <namespace> --reuse-values \
--set-json 'ingress.internalAllowedCidrs=["10.0.0.0/8","192.168.0.0/16"]'
```

Without an Ingress (`ingress.enabled=false`), the API is only reachable in-cluster through the Service: `http://<release>-openviking-cip.<namespace>.svc.cluster.local:1933`.

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade openviking charts/openviking/v0.1.0 -n <namespace> --reuse-values \
--set image.tag=v0.5.3
```

Changing `ovConf.*` or the Secret rolls the pod automatically through the config checksum annotations.

## Manual uninstall

```bash
helm uninstall openviking -n <namespace>
```
