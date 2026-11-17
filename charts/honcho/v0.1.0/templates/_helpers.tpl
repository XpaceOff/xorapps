{{/* Expand the name of the chart. */}}
{{- define "honcho.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a default fully qualified app name. */}}
{{- define "honcho.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "honcho.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "honcho.labels" -}}
helm.sh/chart: {{ include "honcho.chart" . }}
{{ include "honcho.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "honcho.selectorLabels" -}}
app.kubernetes.io/name: {{ include "honcho.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Create the name of the service account to use */}}
{{- define "honcho.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "honcho.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Name of the Secret holding the credentials. */}}
{{- define "honcho.secretName" -}}
{{- if eq .Values.secretSource "existing" }}
{{- .Values.existingSecret }}
{{- else }}
{{- printf "%s-config" (include "honcho.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Connection URI of an external Postgres. envVars.honcho.dbConnectionUri wins when
set; otherwise the URI is built from the database.external fields.
*/}}
{{- define "honcho.externalDbUri" -}}
{{- if .Values.envVars.honcho.dbConnectionUri -}}
{{- .Values.envVars.honcho.dbConnectionUri -}}
{{- else -}}
{{- $ext := .Values.database.external -}}
{{- if not $ext.host -}}
{{- fail "Database Host is required when Database is 'Use an existing Postgres'" -}}
{{- end -}}
{{- if not $ext.password -}}
{{- fail "Database Password is required when Database is 'Use an existing Postgres'" -}}
{{- end -}}
{{- printf "postgresql+psycopg://%s:%s@%s:%v/%s" ($ext.user | urlquery) ($ext.password | urlquery) $ext.host $ext.port ($ext.dbName | urlquery) -}}
{{- end -}}
{{- end }}

{{/* Redis URL for the cache. Empty when Redis is disabled. */}}
{{- define "honcho.cacheUrl" -}}
{{- $fullName := include "honcho.fullname" . -}}
{{- $internal := eq .Values.redis.type "internal" -}}
{{- $host := .Values.redis.host -}}
{{- $port := .Values.redis.port -}}
{{- if $internal -}}
{{- $host = printf "%s-redis-cip" $fullName -}}
{{- $port = 6379 -}}
{{- end -}}
{{- $url := printf "redis://%s:%v/0?suppress=true" $host $port -}}
{{- if and .Values.redis.password $internal -}}
{{- $url = printf "redis://:%s@%s:%v/0?suppress=true" (.Values.redis.password | urlquery) $host $port -}}
{{- end -}}
{{- $url -}}
{{- end }}

{{/*
Common environment for the API and the deriver. Both talk to the same
database and the same cache, so they get the same settings.
*/}}
{{- define "honcho.env" -}}
{{- $secretName := include "honcho.secretName" . -}}
{{- if eq .Values.database.type "internal" }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: POSTGRES_PASSWORD
- name: DB_CONNECTION_URI
  value: {{ printf "postgresql+psycopg://%s:$(DB_PASSWORD)@%s-db-cip:%v/%s" (.Values.database.internal.user | urlquery) (include "honcho.fullname" .) .Values.database.internal.service.port (.Values.database.internal.dbName | urlquery) | quote }}
{{- else }}
- name: DB_CONNECTION_URI
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: DB_CONNECTION_URI
{{- end }}
- name: LLM_OPENAI_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: LLM_OPENAI_API_KEY
      optional: true
- name: LLM_ANTHROPIC_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: LLM_ANTHROPIC_API_KEY
      optional: true
- name: LLM_GEMINI_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: LLM_GEMINI_API_KEY
      optional: true
{{- if .Values.envVars.honcho.baseUrl }}
- name: LLM_OPENAI_BASE_URL
  value: {{ .Values.envVars.honcho.baseUrl | quote }}
{{- end }}
- name: LOG_LEVEL
  value: {{ .Values.envVars.honcho.logLevel | quote }}
- name: NAMESPACE
  value: {{ .Values.envVars.honcho.namespace | quote }}
- name: VECTOR_STORE_TYPE
  value: {{ .Values.envVars.honcho.vectorStoreType | quote }}
- name: AUTH_USE_AUTH
  value: {{ .Values.auth.enabled | quote }}
{{- if .Values.auth.enabled }}
- name: AUTH_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: AUTH_JWT_SECRET
{{- end }}
{{- if .Values.redis.enabled }}
- name: CACHE_ENABLED
  value: "true"
- name: CACHE_URL
  value: {{ include "honcho.cacheUrl" . | quote }}
{{- if .Values.redis.password }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: REDIS_PASSWORD
      optional: true
{{- end }}
{{- end }}
- name: METRICS_ENABLED
  value: {{ .Values.envVars.honcho.metricsEnabled | quote }}
{{- if .Values.envVars.honcho.sentryEnabled }}
- name: SENTRY_ENABLED
  value: "true"
- name: SENTRY_DSN
  value: {{ .Values.envVars.honcho.sentryDsn | quote }}
{{- end }}
{{- $chatModel := .Values.envVars.honcho.chatModel | default "gpt-5.4-mini" }}
{{- $embeddingModel := .Values.envVars.honcho.embeddingModel | default "text-embedding-3-small" }}
{{- $embeddingDimensions := .Values.envVars.honcho.embeddingDimensions | default 1536 }}
- name: DERIVER_MODEL_CONFIG__MODEL
  value: {{ $chatModel | quote }}
- name: SUMMARY_MODEL_CONFIG__MODEL
  value: {{ $chatModel | quote }}
{{- range $level := list "minimal" "low" "medium" "high" "max" }}
- name: DIALECTIC_LEVELS__{{ $level }}__MODEL_CONFIG__MODEL
  value: {{ $chatModel | quote }}
{{- end }}
- name: EMBEDDING_MODEL_CONFIG__MODEL
  value: {{ $embeddingModel | quote }}
- name: EMBEDDING_VECTOR_DIMENSIONS
  value: {{ $embeddingDimensions | toString | quote }}
{{- range .Values.extraEnv }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- end }}

{{/*
Init container that applies the database migrations. It runs
"python scripts/provision_db.py", which takes a Postgres advisory lock, so the
API and the deriver can both run it at the same time without racing: one
migrates, the others wait for the lock and then become no-ops.
*/}}
{{- define "honcho.migrateInitContainer" -}}
- name: run-migrations
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
    - /app/.venv/bin/python
    - scripts/provision_db.py
  env:
    {{- include "honcho.env" . | nindent 4 }}
{{- end }}

{{/*
Init container that waits for the cache to accept connections. Honcho opens the
cache connection once at startup and falls back to a process-local in-memory
cache when it fails, so a pod that starts before Redis is ready would stay
without the shared cache until it is restarted. Waiting here removes that race.
*/}}
{{- define "honcho.waitForCacheInitContainer" -}}
{{- if .Values.redis.enabled -}}
{{- $host := .Values.redis.host -}}
{{- $port := .Values.redis.port -}}
{{- if eq .Values.redis.type "internal" -}}
{{- $host = printf "%s-redis-cip" (include "honcho.fullname" .) -}}
{{- $port = 6379 -}}
{{- end -}}
- name: wait-for-cache
  image: busybox:1.35.0
  imagePullPolicy: IfNotPresent
  command:
    - /bin/sh
    - -c
    - |
      i=0
      until nc -z {{ $host }} {{ $port }}; do
        i=$((i+1))
        if [ "$i" -ge 60 ]; then
          echo "cache at {{ $host }}:{{ $port }} not reachable after 60 tries" >&2
          exit 1
        fi
        sleep 2
      done
      echo "cache at {{ $host }}:{{ $port }} is reachable"
{{- end -}}
{{- end }}
