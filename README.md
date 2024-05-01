# Nectar lib

Contains helm templates to deploy openstack

## Config
Must define a template named `config-map.yaml` that contains

```
{{- include "nectarlib.configmap" (list . "blazar.configmap") -}}
{{- define "<my-project>.configmap" -}}
data: {}
{{- end -}}
```

Can add extra config files in here if required. By default  will create a <chart-name>.conf and a policy.yaml

Must define a template called `<chart-name>-conf` this will be used to create `/etc/<chart-name/<chart-name>.conf`

### oslo policy

Define in your values like:
```
oslo_policy:
  admin_or_cloudadmin: 'role:admin or role:cloud_admin'
  ...
```

### Vault
Must define a template called `<chart-name>.vaultAnnotations` that includes all required vault secrets.


## openstack_api

Will create a deployment, service and if enabled an ingress and pdb

```
{{- include "nectarlib.openstack_api.tpl" . -}}
```

### Values:

| Name        | Value |
| ----------- | ----- |
| api.port    | 5000  |


## openstack-worker
To define multiple services per openstack project (chart) you can create a values dict per service and pass that in to the template.

```
{{- include "nectarlib.openstack_worker.tpl" (list $ . .Values.<service>) -}}
```

### Values:

| Name           | Value     |
| -------------- | --------- |
| <service>.name | "worker"  |



## Values common to API and Workers

| Name                                | Value |
| ----------------------------------- | ----- |
| <service>.image.repository          |       |
| <service>.command                   | null  |
| <service>.replicaCount              |   1   |
| <service>.pdb.enabled               | false |
| <service>.pdb.minAvailable          |   0   |
| <service>.podAffinityPreset         |  ""   |
| <service>.podAntiAffinityPreset     |  soft |
| <service>.nodeAffinityPreset.type   |  ""   |
| <service>.nodeAffinityPreset.key    |  ""   |
| <service>.nodeAffinityPreset.values |  []   |
| <service>.affinity                  |  {}   |
| <service>.resources                 |  {}   |


