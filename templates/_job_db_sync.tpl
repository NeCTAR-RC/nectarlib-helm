{{- define "nectarlib.job_db_sync" -}}
{{- if .Values.job.db_sync.enabled | default false }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "nectarlib.fullname" . }}-db-sync
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "3"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      annotations:
        {{- include (print .Chart.Name ".vaultAnnotations") . | nindent 8 }}
      labels:
        {{- include "nectarlib.selectorLabels" . | nindent 8 }}
    spec:
      restartPolicy: Never
      serviceAccountName: {{ include "nectarlib.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
{{- if .Values.wait_for }}
{{- if .Values.wait_for.db }}
{{- if .Values.wait_for.db.host }}
      initContainers:
        - name: wait-for-mariadb
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: cgr.dev/chainguard/wait-for-it:latest
          args:
            - '-h'
            - '{{ .Values.wait_for.db.host }}'
            - '-p'
            - '{{ .Values.wait_for.db.port }}'
            - '-t'
            - '120'
{{- end }}
{{- end }}
{{- end }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.api.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command:
            {{- toYaml .Values.job.db_sync.command | nindent 12 }}
          args:
            {{- toYaml .Values.job.db_sync.args | nindent 12 }}
          volumeMounts:
            - name: {{ include "nectarlib.fullname" . }}
              mountPath: "/etc/{{ include "nectarlib.name" . }}/"
      volumes:
        - name: {{ include "nectarlib.fullname" . }}
          configMap:
            name: {{ include "nectarlib.fullname" . }}
{{- end }}
{{- end }}
