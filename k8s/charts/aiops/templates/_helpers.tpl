{{/* Pass a dict with "root" (the top-level context) and "name" (the service name) */}}
{{- define "aiops.labels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: aiops-incident-copilot
{{- end -}}
