{{- define "route-registry.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "route-registry.fullname" -}}
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

{{- define "route-registry.workerFullname" -}}
{{- printf "%s-worker" (include "route-registry.fullname" .) -}}
{{- end -}}

{{- define "route-registry.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "route-registry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "route-registry.selectorLabels" -}}
app.kubernetes.io/name: {{ include "route-registry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "route-registry.postgresServiceName" -}}
{{- default (printf "%s-postgres" .Release.Name) .Values.dependencies.postgres.serviceName -}}
{{- end -}}

{{- define "route-registry.postgresSecretName" -}}
{{- default (printf "%s-postgres-credentials" .Release.Name) .Values.dependencies.postgres.secretName -}}
{{- end -}}

{{- define "route-registry.postgresURL" -}}
{{- printf "%s://%s@%s:%v/%s" .Values.dependencies.postgres.protocol .Values.dependencies.postgres.username (include "route-registry.postgresServiceName" .) .Values.dependencies.postgres.port .Values.dependencies.postgres.database -}}
{{- end -}}

{{- define "route-registry.rabbitmqServiceName" -}}
{{- default (printf "%s-rabbitmq" .Release.Name) .Values.dependencies.rabbitmq.serviceName -}}
{{- end -}}

{{- define "route-registry.rabbitmqSecretName" -}}
{{- default (printf "%s-rabbitmq-secret" .Release.Name) .Values.dependencies.rabbitmq.secretName -}}
{{- end -}}

{{- define "route-registry.tokenServiceName" -}}
{{- default (printf "%s-token-service" .Release.Name) .Values.dependencies.tokenService.serviceName -}}
{{- end -}}

{{- define "route-registry.holepunchAdminName" -}}
{{- default (printf "%s-holepunch-admin" .Release.Name) .Values.dependencies.holepunch.adminServiceName -}}
{{- end -}}

{{- define "route-registry.pikoServiceName" -}}
{{- default (printf "%s-piko" .Release.Name) .Values.dependencies.piko.serviceName -}}
{{- end -}}

{{/*
Custom CA volume - mounts ConfigMap as volume
*/}}
{{- define "route-registry.customCAVolume" -}}
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
{{- define "route-registry.customCAVolumeMount" -}}
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
{{- define "route-registry.customCAEnvVars" -}}
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
