{{- define "rabbitmq.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "rabbitmq.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "rabbitmq.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "rabbitmq.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "rabbitmq.serviceAccountName" -}}
{{- if .Values.global.serviceAccount.create -}}
{{- default (include "rabbitmq.fullname" .) .Values.global.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.global.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "rabbitmq.secretName" -}}
{{- default (printf "%s-credentials" (include "rabbitmq.fullname" .)) .Values.auth.existingSecret -}}
{{- end -}}

{{/*
Pod security context based on image variant
*/}}
{{- define "rabbitmq.podSecurityContext" -}}
{{- if .Values.global.podSecurityContext -}}
{{- toYaml .Values.global.podSecurityContext -}}
{{- else if eq .Values.imageVariant "redhat" -}}
runAsNonRoot: true
{{- else -}}
fsGroup: 999
runAsUser: 999
runAsNonRoot: true
{{- end -}}
{{- end -}}

{{/*
Container security context based on image variant
*/}}
{{- define "rabbitmq.containerSecurityContext" -}}
{{- $defaultContext := .Values.global.containerSecurityContext -}}
{{- if eq .Values.imageVariant "redhat" -}}
allowPrivilegeEscalation: {{ $defaultContext.allowPrivilegeEscalation | default false }}
capabilities:
  drop:
    - ALL
readOnlyRootFilesystem: {{ $defaultContext.readOnlyRootFilesystem | default false }}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- else -}}
allowPrivilegeEscalation: {{ $defaultContext.allowPrivilegeEscalation | default false }}
capabilities:
  drop:
    - ALL
readOnlyRootFilesystem: {{ $defaultContext.readOnlyRootFilesystem | default false }}
runAsNonRoot: true
runAsUser: 999
seccompProfile:
  type: RuntimeDefault
{{- end -}}
{{- end -}}
