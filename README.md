# nectarlib

A Helm **library chart** (`type: library`) providing the common templates used
by Nectar's per-service OpenStack charts (blazar, nova, etc.). It produces no
resources on its own — consumer charts depend on it and `include` its named
templates to render their Deployments, Services, ConfigMaps, PDBs, Ingresses,
HTTPRoutes, NetworkPolicies and db-sync Jobs.

Repository: <https://github.com/NeCTAR-RC/nectarlib-helm> (mirror of the
canonical Gerrit project `NeCTAR-RC/nectarlib-helm`).

## Using the library

Add it as a dependency in your consumer chart's `Chart.yaml`:

```yaml
dependencies:
  - name: nectarlib
    version: 3.3.0
    repository: <chart-repo-url>
```

Bumping the library `version:` is required for any template change to flow
downstream — consumer charts pin to a version.

## Calling convention

Most public templates take a **3-element list** rather than a single context:

```gotemplate
{{- include "nectarlib.openstack_api"    (list $ . .Values.api)    -}}
{{- include "nectarlib.openstack_worker" (list $ . .Values.worker) -}}
{{- include "nectarlib.job_db_sync"      (list $ . .Values.api)    -}}
```

- `$` — root context from the consumer. Needed because
  `$.Template.BasePath` must resolve to the consumer's `templates/` directory
  for `checksum/config` annotations.
- `.` — current chart context (`.Values`, `.Chart`, `.Release`).
- third arg — the per-service values sub-dict (`api`, `worker`, or any named
  worker dict). `openstack_worker` may be called multiple times with different
  sub-dicts to define several worker Deployments (e.g. `.Values.worker`,
  `.Values.cleaner`).

## What the consumer chart must provide

The library expects the consumer to define three named templates, named after
the consumer's chart name (e.g. `blazar`):

| Template                       | Purpose                                                                  |
| ------------------------------ | ------------------------------------------------------------------------ |
| `<chart-name>-conf`            | Body of `/etc/<chart-name>/<chart-name>.conf`.                           |
| `<chart-name>.configmap`       | Extra keys merged (deep merge, consumer wins) into the rendered ConfigMap. |
| `<chart-name>.vaultAnnotations`| Pod annotations for the Vault agent injector. Included on every Deployment and Job pod unless `.Values.vault.enabled` is explicitly `false`. |

The consumer must also place a `templates/config-map.yaml` that calls
`nectarlib.configmap`. The api and worker templates checksum that exact path
(`$.Template.BasePath "/config-map.yaml"`) so pods roll on config change.

### Minimal `templates/config-map.yaml`

```gotemplate
{{- include "nectarlib.configmap" (list . "<chart-name>.configmap") -}}

{{- define "<chart-name>.configmap" -}}
data: {}
{{- end -}}

{{- define "<chart-name>-conf" -}}
[DEFAULT]
# ...
{{- end -}}
```

### oslo policy

Define policy rules in values and they will be rendered into `policy.yaml`:

```yaml
oslo_policy:
  admin_or_cloudadmin: 'role:admin or role:cloud_admin'
```

## Public templates

| Template                  | Renders                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------- |
| `nectarlib.openstack_api` | Deployment + Service + NetworkPolicy, plus PDB / Ingress / HTTPRoute / Apache or uWSGI ConfigMap when enabled. |
| `nectarlib.openstack_worker` | Deployment + NetworkPolicy for a worker.                                                 |
| `nectarlib.configmap`     | The chart's main ConfigMap (`<chart-name>.conf`, `policy.yaml`, merged consumer keys).      |
| `nectarlib.job_db_sync`   | A `db-sync` Job (Helm pre-install / pre-upgrade hook).                                      |
| `nectarlib.serviceaccount`| ServiceAccount.                                                                             |

## Per-service values surface

Each `$service` dict (e.g. `.Values.api`, `.Values.worker`) commonly carries:

| Key                                 | Default       | Notes                                                                |
| ----------------------------------- | ------------- | -------------------------------------------------------------------- |
| `name`                              | `"api"` / `"worker"` | Used as `app.kubernetes.io/component` and name suffix.         |
| `image.repository`                  | —             | Tag comes from `.Values.image.tag` or `.Chart.AppVersion`.           |
| `command`                           | unset         | Container `command`.                                                 |
| `replicaCount`                      | `1`           | Ignored when `.Values.autoscaling.enabled`.                          |
| `port` / `port_name` / `protocol`   | `80` / `http` / `TCP` | api only.                                                    |
| `healthchecks`                      | enabled       | Set string `"false"` to disable liveness + startup probes.           |
| `healthcheck_path`                  | `/healthcheck`| HTTP path probed.                                                    |
| `volumes` / `volume_mounts`         | `[]`          | Extra volumes/mounts merged into the pod.                            |
| `resources`                         | `{}`          | Standard `resources:` block.                                         |
| `extra_container`                   | unset         | Optional sidecar with its own `image`, `command`, `resources`.       |
| `pdb.enabled` / `pdb.minAvailable`  | `false` / `1` | Renders a PodDisruptionBudget when enabled.                          |
| `apache.enabled`                    | `false`       | Renders a `wsgi-<fullname>.conf` ConfigMap and mounts it on the api pod. |
| `uwsgi.enabled` / `uwsgi.module`    | `false`       | Renders a `uwsgi.ini` ConfigMap and mounts it on the api pod.        |
| `ingress.{enabled,className,tls,hosts,annotations}` | `enabled: false` | Standard `networking.k8s.io/v1` Ingress. |
| `gateway.{enabled,kind,apiVersion,parentRefs,hostnames,timeouts,annotations}` | `enabled: false` | Gateway API route (defaults to `HTTPRoute`). |
| `podAffinityPreset` / `podAntiAffinityPreset` / `nodeAffinityPreset` | `""` / `soft` / `{}` | Bitnami-style affinity presets. |
| `affinity`                          | unset         | Raw `affinity:` block — overrides presets when set.                  |

## Gotchas

- `vault.enabled` is checked with `ne (toString .Values.vault.enabled) "false"`,
  so it defaults to *on* when unset. Set it explicitly to `false` to disable.
- `_names.tpl`, `_labels.tpl`, `_tplvalues.tpl`, `_affinities.tpl` are
  Bitnami-derived (Apache-2.0). The chart used to depend on `bitnami/common`;
  that dependency was removed and these helpers were vendored in — don't
  reintroduce the dependency.
- `nectarlib.util.merge` uses sprig `merge` (first-arg wins), so keys in the
  consumer's `<chart-name>.configmap` override the library's defaults.

## Validating changes

This chart cannot be rendered standalone. To test a change, render it from a
consumer chart that depends on it (after pointing the dependency at your local
copy or pushing a new version):

```sh
helm dependency update <consumer-chart>
helm lint <consumer-chart>
helm template <consumer-chart>
```

## Submitting changes

Review is via Gerrit, not GitHub PRs. The GitHub repo is a mirror.

```sh
git review
```

See `.gitreview` for the Gerrit host and project.
