{{- define "token-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "token-service.fullname" -}}
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

{{- define "token-service.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "token-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "token-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "token-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "token-service.postgresServiceName" -}}
{{- default (printf "%s-postgres" .Release.Name) .Values.dependencies.postgres.serviceName -}}
{{- end -}}

{{- define "token-service.postgresSecretName" -}}
{{- default (printf "%s-postgres-credentials" .Release.Name) .Values.dependencies.postgres.secretName -}}
{{- end -}}

{{- define "token-service.postgresURL" -}}
{{- printf "%s://%s@%s:%v/%s" .Values.dependencies.postgres.protocol .Values.dependencies.postgres.username (include "token-service.postgresServiceName" .) .Values.dependencies.postgres.port .Values.dependencies.postgres.database -}}
{{- end -}}

{{/*
Custom CA volume - mounts ConfigMap as volume
*/}}
{{- define "token-service.customCAVolume" -}}
{{- $globalCA := .Values.global.customCA | default dict -}}
{{- $serviceCA := .Values.customCA | default dict -}}
{{- $enabled := or $serviceCA.enabled $globalCA.enabled -}}
{{- if $enabled }}
- name: custom-ca
  configMap:
    name: {{ $serviceCA.configMapName | default $globalCA.configMapName }}
    items:
      - key: {{ $serviceCA.key | default $globalCA.key }}
        path: {{ $serviceCA.key | default $globalCA.key }}
{{- end }}
{{- end }}

{{/*
Custom CA volume mount - mounts CA bundle into container
*/}}
{{- define "token-service.customCAVolumeMount" -}}
{{- $globalCA := .Values.global.customCA | default dict -}}
{{- $serviceCA := .Values.customCA | default dict -}}
{{- $enabled := or $serviceCA.enabled $globalCA.enabled -}}
{{- if $enabled }}
- name: custom-ca
  mountPath: {{ $serviceCA.mountPath | default $globalCA.mountPath }}
  readOnly: true
{{- end }}
{{- end }}

{{/*
Custom CA environment variables - points apps to mounted CA
*/}}
{{- define "token-service.customCAEnvVars" -}}
{{- $globalCA := .Values.global.customCA | default dict -}}
{{- $serviceCA := .Values.customCA | default dict -}}
{{- $enabled := or $serviceCA.enabled $globalCA.enabled -}}
{{- if $enabled }}
{{- range $globalCA.envVars }}
- name: {{ .name }}
  value: {{ .value }}
{{- end }}
{{- range $serviceCA.additionalEnvVars }}
- name: {{ .name }}
  value: {{ .value }}
{{- end }}
{{- end }}
{{- end }}
