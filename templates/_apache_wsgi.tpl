{{- define "nectarlib.apache_wsgi" -}}
{{- $wsgiScriptDefault := printf "%s-%s" .Chart.Name "api" -}}
Listen 0.0.0.0:{{ .Values.api.port }}

ServerSignature Off
ServerTokens Prod
TraceEnable off
TimeOut {{ .Values.api.apache.timeout | default "60" }}
KeepAliveTimeout 15
WSGISocketPrefix /apache/wsgi

<Directory "/var/lib/kolla/venv/bin">
    <FilesMatch "^{{ .Values.api.apache.wsgi_script | default $wsgiScriptDefault }}$">
      Options Indexes FollowSymLinks MultiViews
      AllowOverride None
      Require all granted
    </FilesMatch>
</Directory>

<VirtualHost *:{{ .Values.api.port }}>
  ## Logging
  CustomLog /dev/stdout logformat
  ErrorLog /dev/stdout

  ServerSignature Off
  LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %b %D \"%{Referer}i\" \"%{User-Agent}i\"" logformat
  WSGIApplicationGroup %{GLOBAL}
  WSGIDaemonProcess {{ .Chart.Name }} group={{ .Chart.Name }} processes={{ .Values.api.apache.threads | default "4" }} threads={{ .Values.api.apache.threads | default "2" }} user={{ .Chart.Name }} {{ .Values.api.apache.extra_config | default "" }}
  WSGIProcessGroup {{ .Chart.Name }}
  WSGIScriptAlias {{ .Values.api.apache.script_alias | default "/" }} "/var/lib/kolla/venv/bin/{{ .Values.api.apache.wsgi_script | default $wsgiScriptDefault }}"
</VirtualHost>

{{- end -}}
