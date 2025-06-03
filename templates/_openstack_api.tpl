{{- define "nectarlib.openstack_api" -}}
{{- $ := index . 0 }}
{{- $service := index . 2 }}
{{- with index . 1 }}
{{- $apiName := $service.name | default "api" -}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $apiName }}
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $apiName }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ $service.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "nectarlib.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ $apiName }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/config-map.yaml") . | sha256sum }}
        {{- if ne (toString .Values.vault.enabled) "false" }}
        {{- include (print .Chart.Name ".vaultAnnotations") . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "nectarlib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: {{ $apiName }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "nectarlib.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ $service.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- if $service.command }}
          command:
            {{- toYaml $service.command | nindent 12 }}
          {{- end }}
          {{- if $service.apache.enabled }}
          env:
            - name: APACHE_LOG_DIR
              value: /apache/
            - name: APACHE_PID_FILE
              value: /apache/apache.pid
            - name: APACHE_RUN_GROUP
              value: {{ .Chart.Name }}
            - name: APACHE_LOCK_DIR
              value: /apache/
            - name: APACHE_RUN_DIR
              value: /apache/
            - name: APACHE_RUN_USER
              value: {{ .Chart.Name }}
          {{- end }}
          {{- if .Values.conf.envSecretRef }}
          envFrom:
          - secretRef:
              name: {{ .Values.conf.envSecretRef }}
          {{- end }}
          ports:
            - name: {{ $service.port_name | default "http" }}
              containerPort: {{ $service.port | default 80 }}
              protocol: {{ $service.protocol | default "TCP" }}
          {{- if ne (toString $service.healthchecks) "false" }}
          livenessProbe:
            httpGet:
              path: /healthcheck
              port: {{ $service.port_name | default "http" }}
          startupProbe:
            httpGet:
              path: /healthcheck
              port: {{ $service.port_name | default "http" }}
            initialDelaySeconds: 30
            timeoutSeconds: 5
            failureThreshold: 10
          {{- end }}
          volumeMounts:
            - name: {{ include "nectarlib.fullname" . }}
              mountPath: "/etc/{{ include "nectarlib.name" . }}/"
            {{- with $service.volume_mounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- if $service.apache.enabled }}
            - name: {{ include "nectarlib.fullname" . }}-apache
              mountPath: "/etc/apache2/sites-enabled/"
            - name: {{ include "nectarlib.fullname" . }}-apache-work
              mountPath: "/apache/"
            {{- end }}
          resources:
            {{- toYaml $service.resources | nindent 12 }}
        {{ if $service.extra_container }}
        - name: {{ $service.extra_container.name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ $service.extra_container.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- if $service.command }}
          command:
            {{- toYaml $service.extra_container.command | nindent 12 }}
          {{- end }}
          {{- if .Values.conf.envSecretRef }}
          envFrom:
          - secretRef:
              name: {{ .Values.conf.envSecretRef }}
          {{- end }}
          volumeMounts:
            - name: {{ include "nectarlib.fullname" . }}
              mountPath: "/etc/{{ include "nectarlib.name" . }}/"
            {{- with $service.volume_mounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          resources:
            {{- toYaml $service.extra_container.resources | nindent 12 }}
          {{- end }}
      volumes:
        - name: {{ include "nectarlib.fullname" . }}
          configMap:
            name: {{ include "nectarlib.fullname" . }}
        {{- with $service.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if $service.apache.enabled }}
        - name: {{ include "nectarlib.fullname" . }}-apache
          configMap:
            name: {{ include "nectarlib.fullname" . }}-{{ $apiName }}-apache
        - name: {{ include "nectarlib.fullname" . }}-apache-work
          emptyDir: {}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if $service.affinity }}
      affinity: {{- include "common.tplvalues.render" (dict "value" $service.affinity "context" $) | nindent 8 }}
      {{- else }}
      affinity:
        podAffinity: {{- include "common.affinities.pods" (dict "type" $service.podAffinityPreset "component" $apiName "context" $) | nindent 10 }}
        podAntiAffinity: {{- include "common.affinities.pods" (dict "type" $service.podAntiAffinityPreset "component" $apiName "context" $) | nindent 10 }}
        nodeAffinity: {{- include "common.affinities.nodes" (dict "type" $service.nodeAffinityPreset.type "key" $service.nodeAffinityPreset.key "values" $service.nodeAffinityPreset.values) | nindent 10 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}


---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $apiName }}
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $apiName }}
spec:
  type: {{ .Values.service.type }}
  {{- if ne .Values.service.type "ClusterIP" }}
  externalTrafficPolicy: Local
  {{- end }}
  ports:
    - port: {{ $service.port }}
      targetPort: {{ $service.port_name | default "http" }}
      protocol: {{ $service.protocol | default "TCP" }}
      name: {{ $service.port_name | default "http" }}
  selector:
    {{- include "nectarlib.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $apiName }}


{{- if $service.apache.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $apiName }}-apache
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "2"
data:
  wsgi-{{ include "nectarlib.fullname" . }}.conf: |-
{{ include "nectarlib.apache_wsgi" (list $ . $service) | indent 4 }}

{{- end }}

{{- if $service.pdb.enabled }}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $apiName }}
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $apiName }}
spec:
  minAvailable: {{ $service.pdb.minAvailable | default 0 }}
  selector:
    matchLabels:
      {{- include "nectarlib.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ $apiName }}

{{ end }}

{{ if $service.ingress.enabled }}
{{- $fullName := include "nectarlib.fullname" . -}}
{{ $svcPort := $service.port }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}-{{ $apiName }}
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
  {{- with $service.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ $service.ingress.className }}
  {{- if $service.ingress.tls }}
  tls:
    {{- range $service.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $service.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $fullName }}-{{ $apiName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
---
{{ if $service.gateway.enabled  }}
{{- $fullName := include "nectarlib.fullname" . -}}
{{ $svcPort := $service.port }}
---
apiVersion: {{ $service.gateway.apiVersion | default "gateway.networking.k8s.io/v1" }}
kind: {{ $service.gateway.kind | default "HTTPRoute" }}
metadata:
  name: {{ $fullName }}-{{ $apiName }}
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
  {{- with $service.gateway.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $service.gateway.parentRefs }}
  parentRefs:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{ if $service.gateway.hostnames }}
  {{- with $service.gateway.hostnames }}
  hostnames:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- else if $service.gateway.hostname }}
  hostnames:
    - {{ $service.gateway.hostname }}
  {{- end }}
  rules:
    - backendRefs:
        - group: ""
          kind: Service
          name: {{ $fullName }}-{{ $apiName }}
          port: {{ $svcPort }}
          weight: 1
      {{ if ne $service.gateway.kind "UDPRoute" }}
      matches:
        - path:
            type: PathPrefix
            value: /
      {{- end }}
      {{- with $service.gateway.timeouts }}
      timeouts:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $apiName }}
spec:
  podSelector:
    matchLabels:
      {{- include "nectarlib.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ $apiName }}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - {}
  ingress:
    - ports:
        - port: {{ $service.port }}
          protocol: {{ $service.protocol | default "TCP" }}

{{- end -}}
{{- end -}}
