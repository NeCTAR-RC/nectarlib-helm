{{- define "nectarlib.openstack_worker" -}}
{{- $ := index . 0 }}
{{- $service := index . 2 }}
{{- with index . 1 }}
{{- $workerName := $service.name | default "worker" -}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $workerName }}
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $workerName }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ $service.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "nectarlib.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ $workerName }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/config-map.yaml") . | sha256sum }}
        {{- include (print .Chart.Name ".vaultAnnotations") . | nindent 8 }}
      labels:
        {{- include "nectarlib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: {{ $workerName }}
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
          command:
            {{- toYaml $service.command | nindent 12 }}
          volumeMounts:
            - name: {{ include "nectarlib.fullname" . }}
              mountPath: "/etc/{{ include "nectarlib.name" . }}/"
            {{- with $service.volume_mounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          resources:
            {{- toYaml $service.resources | nindent 12 }}
      volumes:
        - name: {{ include "nectarlib.fullname" . }}
          configMap:
            name: {{ include "nectarlib.fullname" . }}
        {{- with $service.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if $service.affinity }}
      affinity: {{- include "common.tplvalues.render" (dict "value" $service.affinity "context" $) | nindent 8 }}
      {{- else }}
      affinity:
        podAffinity: {{- include "common.affinities.pods" (dict "type" $service.podAffinityPreset "component" $workerName "context" $) | nindent 10 }}
        podAntiAffinity: {{- include "common.affinities.pods" (dict "type" $service.podAntiAffinityPreset "component" $workerName "context" $) | nindent 10 }}
        nodeAffinity: {{- include "common.affinities.nodes" (dict "type" $service.nodeAffinityPreset.type "key" $service.nodeAffinityPreset.key "values" $service.nodeAffinityPreset.values) | nindent 10 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}

{{- if $service.pdb.enabled }}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $workerName }}
  labels:
    {{- include "nectarlib.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $workerName }}
spec:
  minAvailable: {{ $service.pdb.minAvailable | default 0 }}
  selector:
    matchLabels:
      {{- include "nectarlib.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ $workerName }}

{{- end }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "nectarlib.fullname" . }}-{{ $workerName }}
spec:
  podSelector:
    matchLabels:
      {{- include "nectarlib.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ $workerName }}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - {}

{{- end -}}
{{- end }}
