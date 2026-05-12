{{- define "nectarlib.uwsgi_ini" -}}
{{- $ := index . 0 }}
{{- $service := index . 2 }}
{{- with index . 1 }}

[uwsgi]
add-header = Connection: close
buffer-size = 65535
die-on-term = true
enable-threads = true
exit-on-reload = false
hook-master-start = unix_signal:15 gracefully_kill_them_all
http = 0.0.0.0:{{ $service.port }}
http-auto-chunked = true
http-chunked-input = true
http-raw-body = true
lazy-apps = true
master = true
module = {{ $service.uwsgi.module }}
plugins-dir = /usr/lib/uwsgi/plugins
plugins = python3
processes = {{ $service.uwsgi.processes | default "4" }}
threads = {{ $service.uwsgi.threads | default "2" }}
socket-timeout = 30
thunder-lock = true
worker-reload-mercy = {{ $service.uwsgi.timeout | default "80" }}
log-master = true
threaded-logger = true
log-x-forwarded-for = true
log-format = {"time":"%(ltime)", "remote_addr":"%(addr)", "method":"%(method)", "uri":"%(uri)", "proto":"%(proto)", "status":%(status), "res_size":%(size), "req_body_size":%(cl), "res_time_ms":%(msecs)}

{{- end -}}
{{- end -}}
