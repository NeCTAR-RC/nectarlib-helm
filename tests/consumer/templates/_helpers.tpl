{{/*
The library expects three templates named after the consumer chart:
  <chart-name>-conf
  <chart-name>.configmap
  <chart-name>.vaultAnnotations
This fixture's chart name is "consumer".
*/}}

{{- define "consumer-conf" }}
[DEFAULT]
debug = false
{{- end }}

{{/*
The fixture's `consumer.configmap` extends the base ConfigMap with optional
keys driven by `.Values.extraConfigData`. This lets tests exercise the merge
behaviour in nectarlib.util.merge (sprig merge — first-arg wins).
*/}}
{{- define "consumer.configmap" -}}
data:
{{- range $k, $v := .Values.extraConfigData }}
  {{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "consumer.vaultAnnotations" -}}
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "consumer"
{{- end -}}
