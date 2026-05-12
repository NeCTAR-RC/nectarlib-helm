#!/usr/bin/env bash
# Runs the helm-unittest suite against the fixture consumer chart.
#
# Prerequisites:
#   - helm v3+
#   - helm-unittest plugin
#     install: helm plugin install https://github.com/helm-unittest/helm-unittest.git --verify=false
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$HERE/consumer"

if ! helm plugin list 2>/dev/null | grep -qE '^unittest\b'; then
  echo "helm-unittest plugin is not installed." >&2
  echo "  helm plugin install https://github.com/helm-unittest/helm-unittest.git --verify=false" >&2
  exit 1
fi

# Refresh the local copy of the library chart in the fixture's charts/ dir.
# Uses --skip-refresh so we don't hit the network for unrelated repos.
helm dependency update "$FIXTURE" --skip-refresh >/dev/null

helm lint "$FIXTURE"
helm unittest "$FIXTURE" "$@"
