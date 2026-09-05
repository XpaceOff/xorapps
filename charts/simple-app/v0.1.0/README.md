# simple-app Helm Chart

Generic single-container chart. Set the image, container port, optional NFS
storage, and ingress. Useful for quickly deploying an off-the-shelf image
without writing a bespoke chart.

## Manual install

```bash
helm install my-app charts/simple-app/v0.1.0 \
  --set image.repository=nginx \
  --set image.tag=1.27 \
  --set containerPort=80 \
  --set service.port=80 \
  --set ingress.enabled=true \
  --set ingress.hostUrl=app.example.com \
  --set ingress.tlsEnabled=true \
  --set ingress.issuer=letsencrypt-prod \
  --set ingress.forceHttps=true \
  --set storage.nfs.hostname=nfs.example.com \
  --set storage.nfs.path=/exports/apps \
  --set storage.mountPath=/usr/share/nginx/html \
  -n my-namespace
```

## Manual upgrade

```bash
helm upgrade my-app charts/simple-app/v0.1.0 -n my-namespace
```

## Manual uninstall

```bash
helm uninstall my-app -n my-namespace
```

## Secrets

Turn on with `secrets.enabled=true`. Three input paths, and they compose.
All of them end up as environment variables on the container via `envFrom`.

### 1. YAML map (`secrets.env`)

```yaml
secrets:
  enabled: true
  env:
    DB_PASSWORD: "hunter2"
    API_KEY: "abc123"
```

### 2. Pasted `.env`-style block (`secrets.envFile`)

Convenient when you already have a `.env` file. In the Rancher UI this is
the **"Paste .env-style secrets"** textarea in the Security group.

```yaml
secrets:
  enabled: true
  envFile: |
    DB_PASSWORD=hunter2
    # comments and blank lines are ignored
    API_KEY=abc123
```

Parsing rules: split on the first `=`; blank lines and lines starting with
`#` are skipped; the key is trimmed, the value is taken verbatim (no quote
stripping). Keys from `secrets.env` override keys from `secrets.envFile`
if both define the same name.

Both `env` and `envFile` render a single chart-managed Secret named
`<release-fullname>-env`, mounted with `envFrom.secretRef`.

### 3. Reference existing Secrets (out-of-band)

Create the Secret yourself, then point the chart at it. Nothing sensitive
passes through Helm.

```bash
kubectl create secret generic my-db-creds \
  --from-literal=DB_PASSWORD=hunter2 \
  -n my-namespace

# or from a file:
kubectl create secret generic my-app-env \
  --from-env-file=./prod.env \
  -n my-namespace
```

In the Rancher UI: pick it from the **"Or pick an existing Secret"**
dropdown. In YAML:

```yaml
secrets:
  enabled: true
  existingSecret: my-db-creds       # single, UI-friendly
  envFromExisting:                  # additional, YAML-only
    - my-app-env
    - shared-team-secrets
```

Each entry is added as its own `envFrom.secretRef`. All keys from all
referenced Secrets become environment variables.

### Note on file upload

The Rancher UI has no file-upload field. To load a file's contents:
paste it into `secrets.envFile`, or run
`kubectl create secret generic <name> --from-env-file=<path>` and select
that Secret with `secrets.existingSecret`.

### Precedence

Within the container spec, `envFrom` is rendered before `env`, so any
entry in the plain (non-secret) `env:` list overrides a same-named key
coming from a Secret.

### Opting out

`secrets.enabled: false` (the default) renders no Secret and no `envFrom`
block. The output is byte-identical to a chart install without any
`secrets:` config.

## NFS storage notes

`storage.nfs.path` must be an **existing, exported** directory on the NFS
server. Do **not** append a release-specific subfolder to it - the chart
already isolates each release by mounting with `subPath: <release-fullname>`
underneath that path.

Example (correct):

```
storage.nfs.hostname = rmnas.opt2
storage.nfs.path     = /volume1/cluspi/tmp     # exists and is exported
```

The chart then mounts `/volume1/cluspi/tmp/<release-fullname>` into the
container at `storage.mountPath`.

If the mount fails with

```
mount.nfs: mounting <host>:<path> failed, reason given by server:
No such file or directory
```

it means one of:

1. The path doesn't exist on the NAS - create it, or point at an existing parent.
2. The path (or an ancestor) is not in the NFS server's export list.
3. The cluster node's IP is not allowed by the export's client rules.

Verify from any Linux host on the cluster network with:

```bash
showmount -e <nfs-hostname>
```

The value of `storage.nfs.path` must match (or be a subdirectory of) one of
the exports listed there. The busybox init container that fixes permissions
cannot help here - it only runs after the NFS mount succeeds.
