{{- define "holepunch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "holepunch.fullname" -}}
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

{{- define "holepunch.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "holepunch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "holepunch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "holepunch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "holepunch.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end -}}

{{- define "holepunch.routeRegistryName" -}}
{{- default (printf "%s-route-registry" .Release.Name) .Values.dependencies.routeRegistry.serviceName -}}
{{- end -}}

{{- define "holepunch.tokenServiceName" -}}
{{- default (printf "%s-token-service" .Release.Name) .Values.dependencies.tokenService.serviceName -}}
{{- end -}}

{{- define "holepunch.oauth2ProxyName" -}}
{{- default (printf "%s-oauth2-proxy" .Release.Name) .Values.dependencies.oauth2Proxy.serviceName -}}
{{- end -}}

{{- define "holepunch.natsName" -}}
{{- default (printf "%s-nats" .Release.Name) .Values.dependencies.nats.serviceName -}}
{{- end -}}

{{- define "holepunch.natsHost" -}}
{{- if .Values.dependencies.nats.host -}}
{{- .Values.dependencies.nats.host -}}
{{- else -}}
{{- printf "%s:%d" (include "holepunch.natsName" .) (int .Values.dependencies.nats.port) -}}
{{- end -}}
{{- end -}}
