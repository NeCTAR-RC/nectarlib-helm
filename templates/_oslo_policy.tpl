{{- define "nectarlib.oslo_policy" -}}
{{- if .Values.oslo_policy }}
{{- range $k, $v := .Values.oslo_policy }}
{{ $k | quote }}: {{ $v | quote }}
{{- end }}
{{- end }}
{{- end -}}
