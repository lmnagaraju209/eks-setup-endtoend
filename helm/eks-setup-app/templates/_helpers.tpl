{{/*
Common labels and naming helpers
*/}}

{{- define "eks-setup-app.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "eks-setup-app.fullname" -}}
{{- if .Values.global.fullnameOverride -}}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" (include "eks-setup-app.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "eks-setup-app.labels" -}}
app.kubernetes.io/name: {{ include "eks-setup-app.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "eks-setup-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eks-setup-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "eks-setup-app.componentLabels" -}}
{{ include "eks-setup-app.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "eks-setup-app.backend.serviceAccountName" -}}
{{- if .Values.backend.serviceAccount.create -}}
{{- default (printf "%s-backend" (include "eks-setup-app.fullname" .)) .Values.backend.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.backend.serviceAccount.name -}}
{{- end -}}
{{- end -}}


