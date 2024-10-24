{{- define "nectarlib.apache_wsgi" -}}
{{- $ := index . 0 }}
{{- $service := index . 2 }}
{{- with index . 1 }}
{{- $wsgiScriptDefault := printf "%s-%s" .Chart.Name "api" -}}
Listen 0.0.0.0:{{ $service.port }}

ServerSignature Off
ServerTokens Prod
TraceEnable off
TimeOut {{ $service.apache.timeout | default "60" }}
KeepAliveTimeout 15
WSGISocketPrefix /apache/wsgi

<Directory "/var/lib/kolla/venv/bin">
    <FilesMatch "^{{ $service.apache.wsgi_script | default $wsgiScriptDefault }}$">
      Options Indexes FollowSymLinks MultiViews
      Require all granted
    </FilesMatch>
</Directory>

<VirtualHost *:{{ $service.port }}>
  ## Logging
  CustomLog /dev/stdout logformat
  ErrorLog /dev/stdout

  ServerSignature Off
  LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %b %D \"%{Referer}i\" \"%{User-Agent}i\"" logformat
  WSGIApplicationGroup %{GLOBAL}
  WSGIDaemonProcess {{ .Chart.Name }} group={{ .Chart.Name }} processes={{ $service.apache.processes | default "4" }} threads={{ $service.apache.threads | default "2" }} user={{ .Chart.Name }} {{ $service.apache.extra_config | default "" }}
  WSGIProcessGroup {{ .Chart.Name }}
  WSGIScriptAlias {{ $service.apache.script_alias | default "/" }} "/var/lib/kolla/venv/bin/{{ $service.apache.wsgi_script | default $wsgiScriptDefault }}"
</VirtualHost>
{{- end -}}
{{- end -}}
