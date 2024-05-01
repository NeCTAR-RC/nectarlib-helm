{{- define "nectarlib.config-map.tpl" -}}
{{- $confTemplate := printf "%s-%s" .Chart.Name "conf" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "nectarlib.fullname" . }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "2"
data:
  {{ .Chart.Name }}.conf: |-
{{- include $confTemplate . | indent 4 }}
  policy.yaml: |-
{{- include "nectarlib.oslo_policy" . | indent 4 }}
{{- end -}}
{{- define "nectarlib.configmap" -}}
{{- include "nectarlib.util.merge" (append . "nectarlib.config-map.tpl") -}}
{{- end -}}
