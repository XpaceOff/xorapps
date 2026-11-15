{{/*
Expand the name of the chart.
*/}}
{{- define "goojara.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "goojara.fullname" -}}
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
{{- define "goojara.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "goojara.labels" -}}
helm.sh/chart: {{ include "goojara.chart" . }}
{{ include "goojara.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "goojara.selectorLabels" -}}
app.kubernetes.io/name: {{ include "goojara.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "goojara.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "goojara.fullname" .) .Values.serviceAccount.name }}
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
{{- define "goojara.jobsServiceName" -}}
{{- printf "%s-jobs-cip" (include "goojara.fullname" .) -}}
{{- end }}

{{/*
The base URL of the job API, as seen from the web container.
*/}}
{{- define "goojara.jobsApiUrl" -}}
{{- printf "http://%s:%v" (include "goojara.jobsServiceName" .) .Values.service.jobsPort -}}
{{- end }}
