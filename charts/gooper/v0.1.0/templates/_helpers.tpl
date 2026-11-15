{{/*
Expand the name of the chart.
*/}}
{{- define "gooper.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gooper.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gooper.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gooper.labels" -}}
helm.sh/chart: {{ include "gooper.chart" . }}
{{ include "gooper.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gooper.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gooper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "gooper.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gooper.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The name of the Service that fronts the jobs API.

The web frontend proxies the job API. In the compose setup the web container
reaches the jobs container by the compose service name ("jobs"), so this
Service keeps the same name and the app configuration does not have to change.
*/}}
{{- define "gooper.jobsServiceName" -}}
{{- printf "%s-jobs-cip" (include "gooper.fullname" .) -}}
{{- end }}

{{/*
The base URL of the job API, as seen from the web container.
*/}}
{{- define "gooper.jobsApiUrl" -}}
{{- printf "http://%s:%v" (include "gooper.jobsServiceName" .) .Values.service.jobsPort -}}
{{- end }}

{{/*
The [groups] section of the config file, with the group concurrency.

TOML forbids a duplicate table, so this cannot simply be appended to a manual
config that already has a [groups] section. The section is rewritten in place
when it exists and appended when it does not.
*/}}
{{- define "gooper.groupsSection" -}}
[groups]
# How many episodes of one group job download at the same time.
concurrency = {{ .Values.config.groupsConcurrency }}
{{- end -}}

{{/*
The manual TOML document with the [groups] section set to the configured
group concurrency.
*/}}
{{- define "gooper.manualToml" -}}
{{- $root := . -}}
{{- $toml := .Values.config.toml -}}
{{- if not (trim $toml) -}}
{{- fail "config.toml is required when config.mode is 'manual' - write the whole TOML document, or set config.mode=chart to let the chart generate it" -}}
{{- end -}}
{{- $lines := splitList "\n" $toml -}}
{{- $inGroups := false -}}
{{- $found := false -}}
{{- $out := list -}}
{{- range $raw := $lines -}}
{{- $line := trim $raw -}}
{{- if eq $line "[groups]" -}}
{{- $inGroups = true -}}
{{- $found = true -}}
{{- else if and $inGroups (hasPrefix "[" $line) -}}
{{/* The next table starts: close the [groups] section. */}}
{{- $inGroups = false -}}
{{- $out = append $out (include "gooper.groupsSection" $root) -}}
{{- $out = append $out $raw -}}
{{- else if $inGroups -}}
{{/* Inside [groups]: drop every key, the section is rewritten below. */}}
{{- else -}}
{{- $out = append $out $raw -}}
{{- end -}}
{{- end -}}
{{- if $inGroups -}}
{{/* The manual config ended inside [groups]: close it. */}}
{{- $out = append $out (include "gooper.groupsSection" $root) -}}
{{- else if not $found -}}
{{/* No [groups] section in the manual config: append one. */}}
{{- $out = append $out (include "gooper.groupsSection" $root) -}}
{{- end -}}
{{- $out | join "\n" -}}
{{- end }}
