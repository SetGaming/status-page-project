{{/*
Chart name.
*/}}
{{- define "status-page.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified application name.
*/}}
{{- define "status-page.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels.
These are metadata labels and can safely use the recommended Kubernetes labels.
*/}}
{{- define "status-page.labels" -}}
app.kubernetes.io/name: {{ include "status-page.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Status Page selector labels.
Keep the existing selector so Helm can adopt/update the current Deployment
without changing the immutable selector.
*/}}
{{- define "status-page.appSelectorLabels" -}}
app: status-page
{{- end }}

{{/*
Redis selector labels.
Keep the existing selector used by the current StatefulSet and Service.
*/}}
{{- define "status-page.redisSelectorLabels" -}}
app: redis
{{- end }}

{{/*
RQ Worker selector labels.
Keep the existing selector used by the current Deployment.
*/}}
{{- define "status-page.workerSelectorLabels" -}}
app: rq-worker
{{- end }}

{{/*
RQ Scheduler selector labels.
Keep the existing selector used by the current Deployment.
*/}}
{{- define "status-page.schedulerSelectorLabels" -}}
app: rq-scheduler
{{- end }}
