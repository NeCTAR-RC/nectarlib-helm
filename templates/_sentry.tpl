{{/*
Sentry/GlitchTip environment variables for kolla-based containers.

The nectar-kolla openstack service images ship a sentry bootstrap shim
(sentry_init.py) that is inert unless SENTRY_DSN is present in the
container environment. This helper renders env list entries that switch
it on, mirroring nectar::profile::kolla::run in puppet-nectar.

Takes a 4-element list:
  0: chart context (.Values, .Chart, .Release)
  1: dict that may carry a per-container `sentry` override sub-dict
     (usually the $service dict; may be nil)
  2: component name, appended to the fullname for the automatic
     `service` tag (matches the Deployment/Job name)
  3: effective image tag, used for the default release

Site-wide settings live in .Values.sentry: dsn, environment,
tags (map), traces_sample_rate, enable_logs, ca_certs, debug,
env_file. Sentry is on when .Values.sentry.dsn is set, or when
.Values.sentry.enabled is true (use the latter when the DSN is
delivered out of band: via the conf.envSecretRef secret, or via a
KEY=VALUE env file rendered into the pod by the Vault agent injector
and pointed at with env_file — the shim reads SENTRY_ENV_FILE, with
process env taking precedence over the file).
Per-container `sentry.enabled` overrides the site-wide switch;
`sentry.release` replaces the default <chart>@<tag> release and
`sentry.tags` is merged over the site-wide tags.
*/}}
{{- define "nectarlib.sentry_env" -}}
{{- $ctx := index . 0 -}}
{{- $service := index . 1 | default dict -}}
{{- $component := index . 2 -}}
{{- $imageTag := index . 3 -}}
{{- $sentry := $ctx.Values.sentry | default dict -}}
{{- $override := $service.sentry | default dict -}}
{{- $enabled := or $sentry.enabled (not (empty $sentry.dsn)) -}}
{{- if hasKey $override "enabled" -}}
{{- $enabled = $override.enabled -}}
{{- end -}}
{{- if and $enabled (ne (toString $enabled) "false") -}}
{{- with $sentry.env_file }}
- name: SENTRY_ENV_FILE
  value: {{ . | quote }}
{{- end }}
{{- with $sentry.dsn }}
- name: SENTRY_DSN
  value: {{ . | quote }}
{{- end }}
{{- with $sentry.environment }}
- name: SENTRY_ENVIRONMENT
  value: {{ . | quote }}
{{- end }}
- name: SENTRY_RELEASE
  value: {{ $override.release | default (printf "%s@%s" $ctx.Chart.Name $imageTag) | quote }}
{{- $tags := mergeOverwrite (dict "service" (printf "%s-%s" (include "nectarlib.fullname" $ctx) $component)) ($sentry.tags | default dict) ($override.tags | default dict) -}}
{{- $pairs := list -}}
{{- range $k, $v := $tags -}}
{{- $pairs = append $pairs (printf "%s:%s" $k (toString $v)) -}}
{{- end }}
- name: SENTRY_TAGS
  value: {{ join "," $pairs | quote }}
{{- with $sentry.traces_sample_rate }}
- name: SENTRY_TRACES_SAMPLE_RATE
  value: {{ . | quote }}
{{- end }}
{{- if $sentry.enable_logs }}
- name: SENTRY_ENABLE_LOGS
  value: "1"
{{- end }}
{{- with $sentry.ca_certs }}
- name: SENTRY_CA_CERTS
  value: {{ . | quote }}
{{- end }}
{{- if $sentry.debug }}
- name: SENTRY_DEBUG
  value: "1"
{{- end }}
{{- end -}}
{{- end -}}
