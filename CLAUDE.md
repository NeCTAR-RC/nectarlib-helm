# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Helm **library chart** (`type: library` in `Chart.yaml`) — it produces no resources on its own. It is consumed as a dependency by per-service Nectar/OpenStack charts (blazar, nova, etc.), which `include` its named templates to render their Deployments, Services, ConfigMaps, PDBs, HTTPRoutes, NetworkPolicies, and db-sync Jobs.

Bumping `version:` in `Chart.yaml` is required for any template change to flow downstream — consumer charts pin to a version.

## Validating changes

This chart cannot be rendered standalone. To test a change, render it from a consumer chart that depends on it (after pointing the dependency at your local copy or pushing a new version):

```
helm dependency update <consumer-chart>
helm lint <consumer-chart>
helm template <consumer-chart>
```

### Unit tests

`tests/consumer/` is a fixture consumer chart with `file://../..` dependency on the library. helm-unittest suites live in `tests/consumer/tests/`. Run them with:

```
./tests/run-tests.sh
```

Requires the `helm-unittest` plugin (see the script for install).

When testing a template that uses `include $.Template.BasePath "/config-map.yaml"` (the api template, for the `checksum/config` annotation), include `config-map.yaml` in the suite's `templates:` list — helm-unittest only parses files declared there.

In helm-unittest v1.x, `containsDocument` and `documentIndex` behave unexpectedly with multi-doc renders. Prefer `documentSelector` at the asserter-sibling level to pick a kind, then assert with `equal` / `exists` / etc.

## Submitting changes

Review is via Gerrit (`.gitreview` → `review.rc.nectar.org.au`, project `NeCTAR-RC/nectarlib-helm`), not GitHub PRs. Use `git review` to submit. The GitHub repo is a mirror.

## Template calling convention

Most templates take a **3-element list** rather than the usual single context:

```
{{- include "nectarlib.openstack_api"    (list $ . .Values.api)      -}}
{{- include "nectarlib.openstack_worker" (list $ . .Values.worker)   -}}
{{- include "nectarlib.configmap"        (list . "blazar.configmap") -}}
```

- `$` — root context from the consumer (needed because `$.Template.BasePath` resolves to the consumer's template dir for `checksum/config` annotations).
- `.` — current chart context (`.Values`, `.Chart`, `.Release`).
- third element — the per-service values sub-dict (`api`, `worker`, or any named worker). A consumer chart can call `openstack_worker` multiple times with different sub-dicts to define several worker Deployments (e.g. `.Values.worker`, `.Values.cleaner`).

Templates unpack with `index . 0`, `index . 1`, `index . 2` and then `with index . 1` to set the chart context.

## What the consumer chart must provide

The library expects the consumer to define several named templates (named after the consumer's chart name):

- `<chart-name>-conf` — body of `/etc/<chart-name>/<chart-name>.conf`. Rendered into the ConfigMap by `nectarlib.config-map.tpl`.
- `<chart-name>.configmap` — extra keys merged into the ConfigMap. Merging is done by `nectarlib.util.merge` (`_util.yaml`), which deep-merges the consumer's template over the library's base ConfigMap.
- `<chart-name>.vaultAnnotations` — pod annotations for the Vault agent injector. Included on every Deployment and Job pod template unless `.Values.vault.enabled` is the literal string/bool `false`.

The consumer must also place a `templates/config-map.yaml` that calls `nectarlib.configmap` — `_openstack_api.tpl` and `_openstack_worker.tpl` checksum that exact file path (`$.Template.BasePath "/config-map.yaml"`) for rollout-on-config-change.

## Per-service values surface

Each `$service` dict (e.g. `.Values.api`) commonly carries: `name`, `image.repository`, `command`, `replicaCount`, `port`/`port_name`/`protocol`, `healthchecks` (set string `"false"` to disable), `healthcheck_path`, `volumes`, `volume_mounts`, `resources`, `extra_container`, `pdb.{enabled,minAvailable}`, `apache.{enabled,...}`, `uwsgi.{enabled,module,...}`, `gateway.{enabled,kind,parentRefs,hostnames,timeouts,...}`, `podAffinityPreset`/`podAntiAffinityPreset`/`nodeAffinityPreset`, `affinity` (overrides presets).

When `apache.enabled` or `uwsgi.enabled` is set, an extra ConfigMap is rendered (`{fullname}-{apiName}-{apache|uwsgi}`) holding `wsgi-{fullname}.conf` or `uwsgi.ini`, generated from `_apache_wsgi.tpl` / `_uwsgi_ini.tpl`, and mounted into the api pod.

## Gotchas

- `vault.enabled` is checked with `ne (toString .Values.vault.enabled) "false"` — it defaults to *on* if unset. To disable, set it explicitly to `false`.
- `_names.tpl`, `_labels.tpl`, `_tplvalues.tpl`, `_affinities.tpl` are Bitnami-derived (SPDX Apache-2.0 headers). The chart used to depend on `bitnami/common`; that dependency was removed (see commit `153eb49`) and these helpers were vendored in. Don't reintroduce the dependency.
- `nectarlib.util.merge` uses sprig `merge` (first-arg wins), so keys in the consumer's `<chart-name>.configmap` override the library's defaults.
