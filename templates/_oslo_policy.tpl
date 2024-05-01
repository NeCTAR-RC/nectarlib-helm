{{- define "nectarlib.oslo_policy" -}}
{{- if .Values.oslo_policy }}
{{- range $k, $v := .Values.oslo_policy }}
'{{ $k }}': '{{ $v }}'
{{- end }}
{{- end }}
{{- end -}}
