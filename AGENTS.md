# AGENTS.md — xorapps

Guide for AI agents (and humans) creating new Helm charts in this repo.

This repository is a **collection of Helm 3 charts** deployed to a Kubernetes cluster via **Rancher Apps & Marketplace**. There is no CI, no Fleet, no ArgoCD, no Kustomize, no chart dependencies. Sharing between charts is done by **copy-paste** of a well-established set of conventions.

When creating a new app, do **not** invent a new layout. Copy an existing reference chart and adapt it.

---

## 1. Repository layout

```
charts/
  <app-name>/
    v<X.Y.Z>/                 # Directory name — a folder convention only
      Chart.yaml
      values.yaml
      questions.yaml          # Rancher UI form
      README.md               # Minimal helm install/upgrade/uninstall examples
      .helmignore
      files/                  # (optional) assets loaded via .Files.Get
        init.sh
      templates/
        _helpers.tpl
        deployment.yaml
        service.yaml
        ingress.yaml
        configmap.yaml
        traefik-middleware-tohttps.yaml
```

- App names are lowercase-hyphenated.
- The version directory (`v1.0.0`) is a folder convention. The authoritative version is `Chart.yaml:version` and may differ from the folder name (e.g. `charts/directus/v1.0.0/` contains `Chart.yaml` with `version: 1.1.0`).
- `Chart.yaml` uses `apiVersion: v2`, `type: application`.

## 2. Reference charts (copy from these)

| Use case | Copy from |
|---|---|
| Standard single-service web app with ingress + NFS storage | `charts/directus/v1.0.0/` |
| Multi-component app (multiple deployments/services, secret-mounted config) | `charts/pangolin/0.4.0/` |
| Ingress + Service pointing at an external IP (bare `Endpoints`) | `charts/external-app-lb/v1.0.1/` |
| Web app with a database (internal Postgres or external URL) and optional Redis | `charts/litellm/v0.1.0/` |
| CRD-only chart (no workloads) | `charts/xo-cluster-cert/v1.0.0/` |
| Backend that speaks HTTPS with self-signed cert (Traefik `ServersTransport`) | `charts/teleport/v1.0.0/` |

**Default recipe: copy `charts/directus/v1.0.0/` and adapt.** It has the most complete single-service pattern.

## 3. Naming conventions

All resource names are prefixed by `{{ $fullName := include "<chart>.fullname" . }}` computed at the top of every template. Use these exact suffixes:

| Suffix | Kind | Purpose |
|---|---|---|
| *(none)* | Deployment | Main workload |
| `-cip` | Service | ClusterIP |
| `-lb` | Service | LoadBalancer |
| `-in` | Ingress | Ingress |
| `-tm-tohttps` | `traefik.io/v1alpha1` Middleware | HTTP→HTTPS redirect |
| `-tst` / `-tst-skipsslverify` | `traefik.io/v1alpha1` ServersTransport | Skip TLS verify to backend |
| `-configs` | ConfigMap | Holds `init.sh` and similar |
| `-config` | Secret | Rendered config files (pangolin pattern) |
| `-tls` | Secret | TLS cert created by cert-manager |

**Volume names:**
- Primary NFS mount: `vol-{{ $fullName }}-nfs`
- Secondary NFS mount: `vol-{{ $fullName }}-<label>nfs` (e.g. `-medianfs`)
- ConfigMap-backed: `vol-configs`
- Scratch: `vol-empty-tmp`

**Template file names:** plain `deployment.yaml`, `service.yaml`, `ingress.yaml` for single-service charts. For multi-component charts, prefix per component: `pangolin-deployment.yaml`, `gerbil-service-cip.yaml`, etc. Be consistent **within** a chart.

## 4. Assumed cluster technologies

Charts must assume — and only support — these:

- **Traefik** as the ingress controller (v3 CRDs `traefik.io/v1alpha1`).
- **cert-manager** for TLS via `cert-manager.io/issuer` annotation.
- **NFS** as the only storage backend, direct-mounted via `spec.volumes[].nfs` (no PV/PVC, no StorageClass, no Longhorn).
- **Rancher UI** as the primary install surface (via `questions.yaml`).
- Kubernetes 1.19+ (older API fallbacks exist in the ingress template — keep them).

Do **not** introduce Longhorn, HPA templates, PDBs, ServiceAccount resources, ExternalSecrets, SealedSecrets, or chart dependencies unless the user explicitly asks. NetworkPolicies are allowed when they are the mechanism that secures a chart-managed datastore (e.g. the internal Redis in litellm); in that case the datastore's password may be optional and the policy is what restricts access. Add a README note that the cluster's CNI must enforce NetworkPolicy.

`automountServiceAccountToken: false` on pod specs is fine — it needs no extra resource.

## 5. Values conventions

Structure `values.yaml` in this order:

1. `image:` (or `image.<component>:` for multi-component) with `repository`, `tag`, `pullPolicy: IfNotPresent`.
2. `envVars:` (or `envVars.<component>:`) — arbitrary app config.
3. `service:` — `type: ClusterIP`, `port: <n>`.
4. `ingress:`
   ```yaml
   ingress:
     enabled: true
     className: ""
     tlsEnabled: true
     forceHttps: true
     issuer: letsencrypt-prod
     annotations: {}
     hostUrl: app.example.com
     hostPath: /
     hostPathType: Prefix
   ```
5. `storage:` — a `type: None|NFS` selector plus `nfs.hostname`, `nfs.path`, and `mountPath` (see `simple-app`). Older charts use bare `storage.nfs`; prefer the selector in new charts.
6. Standard tail (kept from `helm create`): `imagePullSecrets`, `nameOverride`, `fullnameOverride`, `podAnnotations`, `podLabels`, `podSecurityContext`, `securityContext`, `resources`, `autoscaling`, `nodeSelector`, `tolerations`, `affinity`.

Ingress hosts are a **single** `hostUrl` string, not a list. (Only `rancher-demo` uses `ingress.hosts[]` — do not follow that older pattern.)

## 6. Ingress + TLS + force-HTTPS pattern

- `templates/ingress.yaml` — copy verbatim from directus; it uses `semverCompare` to switch between `networking.k8s.io/v1`, `v1beta1`, and `extensions/v1beta1`. Keep the full switch.
- TLS: annotation `cert-manager.io/issuer: {{ .Values.ingress.issuer }}`; TLS secret name `{{ $fullName }}-tls`.
- Force-HTTPS: render `traefik-middleware-tohttps.yaml` only when `and .Values.ingress.enabled .Values.ingress.forceHttps`, so no orphan Middleware exists when ingress is off, then reference it on the Ingress with:
  ```yaml
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: {{ .Release.Namespace }}-{{ $fullName }}-tm-tohttps@kubernetescrd
  ```
  Note the `<namespace>-<name>@kubernetescrd` provider suffix — required by Traefik.

## 7. NFS storage pattern

Storage is a raw NFS mount, isolated per release by using `$fullName` as a subpath on the share.

Every chart with persistence needs three things:

**a. `files/init.sh`** — copied verbatim from directus. Chowns and chmods `/tmp_mount/$1` (where `$1 == $fullName`).

**b. `templates/configmap.yaml`** — `{{ $fullName }}-configs`, containing `init.sh` via `.Files.Get "files/init.sh"`.

**c. In `deployment.yaml`, an init container:**

```yaml
initContainers:
  - name: prepare-nfs-dirs
    image: busybox:1.35.0
    imagePullPolicy: IfNotPresent
    command:
      - /bin/sh
      - -c
      - cp /scripts/init.sh /scripts-w/init.sh && chmod +x /scripts-w/init.sh && /bin/sh /scripts-w/init.sh '{{ $fullName }}'
    {{- if and .Values.storage.nfs.hostname .Values.storage.nfs.path }}
    volumeMounts:
      - name: vol-{{ $fullName }}-nfs
        mountPath: /tmp_mount
      - name: vol-configs
        mountPath: /scripts/init.sh
        subPath: init.sh
        readOnly: false
      - name: vol-empty-tmp
        mountPath: /scripts-w
    {{- end }}
```

With volumes:

```yaml
volumes:
  - name: vol-{{ $fullName }}-nfs
    nfs:
      server: {{ .Values.storage.nfs.hostname }}
      path: {{ .Values.storage.nfs.path }}
  - name: vol-configs
    configMap:
      name: {{ $fullName }}-configs
  - name: vol-empty-tmp
    emptyDir: {}
```

The main container then mounts `vol-{{ $fullName }}-nfs` with `subPath: {{ $fullName }}/<data-dir>` so multiple releases can share one NFS export safely.

## 8. Secrets

Three supported idioms, in order of preference:

1. **Credential Secret with existing-secret option (preferred for charts with passwords/keys).** Render `templates/secret-<name>.yaml` into `{{ $fullName }}-config` (one Secret per release) and reference it from containers with `env: valueFrom: secretKeyRef` (use `optional: true` for keys that may be absent). Offer `secretSource: create|existing` and `existingSecret` (questions `type: secret`): with `existing`, skip rendering the Secret and reference the user's Secret by name. With `create`, values are rendered into the Secret but still sit in Helm release history — document that. `fail` at render time when a required credential is empty. URL-encode connection strings built from user/password (`urlquery`).
2. **Env-var passthrough (legacy).** Sensitive values live in `values.yaml` and are injected as `env: [{name, value}]` on the container. Used by directus, vaultwarden, n8n. Known limitation: passwords appear in the Deployment spec. Prefer idiom 1 for new charts with secrets.
3. **Rendered file secret (pangolin pattern).** Create `templates/secret-<purpose>.yaml` with `stringData:` populated via `tpl (.Files.Get "files/<name>.yml") .`, mount as a file. Use this when the app expects a config file rather than env vars.

`{{ $fullName }}-config` is the credentials Secret; `{{ $fullName }}-configs` is the ConfigMap for non-secret files. Keep them separate — an existing Secret must not be expected to contain config files.

Do not add ExternalSecrets or SealedSecrets without explicit request.

## 9. Namespaces

- Never hardcode a namespace. The user chooses one at install time (`-n <ns>`).
- Cross-namespace refs (rare) use fully-qualified DNS: `<svc>.{{ .Release.Namespace }}.svc.{{ .Values.clusterDomain | default "cluster.local" }}`.
- The only exception is cert-manager `Issuer` (namespaced) using `{{ .Release.Namespace }}` — see `xo-cluster-cert`.

## 10. `_helpers.tpl`

Copy verbatim from any existing chart and do a global find/replace of the old chart name → new chart name. It defines `<chart>.name`, `<chart>.fullname`, `<chart>.chart`, `<chart>.labels`, `<chart>.selectorLabels`, `<chart>.serviceAccountName`. Keep all of them even if unused.

## 11. `questions.yaml` (Rancher UI)

Required for anything installed through the Rancher UI. Schema uses:
- `variable` (dot-path into values), `label`, `description`, `group`, `required`, `default`.
- `type`: `string` | `password` | `enum` | `hostname` | `int` | `boolean` | `secret` | `multiline`.
- Nested questions: the key is **`subquestions:`** (plural). The singular `subquestion:` is silently ignored — the parent shows nothing. Gate them with `show_subquestion_if: true` on the parent.
- Conditional display: `show_if: "var=value"`. Chains with `&&` (e.g. `"database.type=internal&&secretSource=create"`) are used in litellm but are not documented by Rancher — verify in the UI when you use them.
- `enum` options accept plain strings (`- None`) or `{value, label}` maps.
- `type: secret` renders a dropdown of Secrets in the install namespace.

Group names used consistently across charts: **User**, **Security**, **Database**, **Email**, **Gateway/Ingress**, **Container Images** (see `simple-app` and `litellm`). Don't use a **Storage** group when storage serves only one component — put the storage questions in that component's group and gate them with `show_if` (litellm puts its DB storage under **Database**).

Mark credential fields `required: false` in the form when they can come from an existing Secret; enforce them with `fail` in the templates instead, so Rancher doesn't block the existing-Secret path.

## 12. README.md

Minimal — install/upgrade/uninstall examples using `helm` with all relevant `--set` flags. See `charts/directus/v0.1.0/README.md` or `charts/litellm/v0.1.0/README.md`. No project marketing.

- Always show `helm upgrade` with `--reuse-values`; without it unspecified settings reset to chart defaults.
- When a chart supports an existing Secret (section 8), document the required and optional keys and give a `kubectl create secret generic ...` command.
- When the app needs a database user, include the short SQL to create it.

## 12a. Common porting pitfalls

Things that went wrong when porting docker-compose apps — check for them:

- Compose `command:` maps to Kubernetes `args:`, not `command:` (the latter replaces the image entrypoint).
- App-specific health endpoints may require auth. E.g. LiteLLM `/health` needs the master key; use the unauthenticated `/health/liveliness` and `/health/readiness` for probes. Check the app's probe contract before copying a `/health` probe.
- Quote every env `value:` (`| quote`), especially connection strings with `@`/`:`.
- Quote every annotation value in ingress annotations loops.
- Pin a real image tag in `values.yaml`/`Chart.yaml` (`appVersion`), not a floating `latest`-style tag; users change it in Rancher via `image.tag`.
- Apps sending email links usually need an explicit public base URL (LiteLLM: `PROXY_BASE_URL`); derive it from `ingress.hostUrl` and allow an override value.
- Multi-process apps (uvicorn workers etc.) need a worker-count value, and shared state (Redis) when workers or replicas exceed 1.

## 13. Step-by-step: adding a new app

1. `mkdir -p charts/<newapp>/v0.1.0/{templates,files}`.
2. Copy every file from `charts/directus/v1.0.0/` into it.
3. In `_helpers.tpl` and every template, global find/replace `directus` → `<newapp>`.
4. Update `Chart.yaml`: `name`, `description`, `appVersion` (upstream app version), `version` (chart semver, start at `0.1.0`).
5. Rewrite `values.yaml`:
   - Set `image.repository` / `image.tag`.
   - Replace `envVars.*` with the new app's config.
   - Set container port and adjust `service.port`.
   - Fix `storage.nfs` subpaths in mounts.
6. Edit `deployment.yaml`:
   - Update `containerPort` / `livenessProbe` / `readinessProbe`.
   - Update `env:` list.
   - Update `volumeMounts` `subPath`s under `vol-{{ $fullName }}-nfs`.
7. Update `questions.yaml` for the new variables. Keep the group ordering.
8. Update `README.md` with new `helm install` example.
9. Optional add-ons:
   - `templates/traefik-servertransport-skipsslverify.yaml` — backend is HTTPS with self-signed cert.
   - `templates/secret-<name>.yaml` — app needs a config file rather than env vars.
   - Additional deployments/services — prefix template files per-component.
10. Validate locally: `helm lint charts/<newapp>/v0.1.0` and `helm template charts/<newapp>/v0.1.0`.

## 14. Do / Don't

**Do**
- Copy an existing reference chart and adapt.
- Keep the `-cip`, `-in`, `-tm-tohttps`, `-configs`, `-tls` suffixes.
- Preserve the multi-API-version block in `ingress.yaml`.
- Keep the busybox NFS init container when using NFS.
- Update `questions.yaml` for every user-facing value.
- Verify the image registry/tag with the user before changing it — don't guess at "official" registries.
- Validate with `helm lint` and render both sides of every `enabled`/`type` toggle with `helm template`.

**Don't**
- Don't add PVCs, StorageClasses, or Longhorn resources.
- Don't add HPA, PDB, or ServiceAccount templates unsolicited. NetworkPolicy is the exception described in section 4.
- Don't introduce chart dependencies (`Chart.yaml:dependencies`).
- Don't hardcode namespaces.
- Don't use the `ingress.hosts[]` list style; use single `hostUrl`.
- Don't invent new resource-name suffixes.
- Don't rename the `vol-{{ $fullName }}-nfs` / `vol-configs` / `vol-empty-tmp` volumes.
