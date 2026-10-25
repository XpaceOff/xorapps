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

Do **not** introduce Longhorn, HPA templates, NetworkPolicies, PDBs, ServiceAccount resources, ExternalSecrets, SealedSecrets, or chart dependencies unless the user explicitly asks.

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
5. `storage.nfs:` — `hostname`, `path`.
6. Standard tail (kept from `helm create`): `imagePullSecrets`, `nameOverride`, `fullnameOverride`, `podAnnotations`, `podLabels`, `podSecurityContext`, `securityContext`, `resources`, `autoscaling`, `nodeSelector`, `tolerations`, `affinity`.

Ingress hosts are a **single** `hostUrl` string, not a list. (Only `rancher-demo` uses `ingress.hosts[]` — do not follow that older pattern.)

## 6. Ingress + TLS + force-HTTPS pattern

- `templates/ingress.yaml` — copy verbatim from directus; it uses `semverCompare` to switch between `networking.k8s.io/v1`, `v1beta1`, and `extensions/v1beta1`. Keep the full switch.
- TLS: annotation `cert-manager.io/issuer: {{ .Values.ingress.issuer }}`; TLS secret name `{{ $fullName }}-tls`.
- Force-HTTPS: render `traefik-middleware-tohttps.yaml` when `.Values.ingress.forceHttps`, then reference it on the Ingress with:
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

Two supported idioms:

1. **Env-var passthrough (default).** Sensitive values live in `values.yaml` and are injected as `env: [{name, value}]` on the container. No `Secret` resource is created. This is the pattern used by directus, vaultwarden, n8n, etc. Known limitation: passwords appear in the Deployment spec.
2. **Rendered file secret (pangolin pattern).** Create `templates/secret-<purpose>.yaml` with `stringData:` populated via `tpl (.Files.Get "files/<name>.yml") .`, mount as a file. Use this when the app expects a config file rather than env vars.

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
- `type`: `string` | `password` | `enum` | `hostname` | `int` | `boolean`.
- Conditional display: `show_if: "ingress.enabled=true"`, `show_subquestion_if: "true"`, nested `subquestions:`.

Group names used consistently across charts: **User**, **Security**, **Database**, **Email**, **Gateway/Ingress**, **Storage**, **Container Images**. Follow directus's grouping order.

## 12. README.md

Minimal — just install/upgrade/uninstall examples using `helm` with all relevant `--set` flags. See `charts/directus/v1.0.0/README.md`. No project marketing.

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

**Don't**
- Don't add PVCs, StorageClasses, or Longhorn resources.
- Don't add HPA, PDB, NetworkPolicy, or ServiceAccount templates unsolicited.
- Don't introduce chart dependencies (`Chart.yaml:dependencies`).
- Don't hardcode namespaces.
- Don't use the `ingress.hosts[]` list style; use single `hostUrl`.
- Don't invent new resource-name suffixes.
- Don't rename the `vol-{{ $fullName }}-nfs` / `vol-configs` / `vol-empty-tmp` volumes.
