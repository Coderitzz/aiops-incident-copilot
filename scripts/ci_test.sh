#!/usr/bin/env bash
# Lint + unit tests. Runs inside python:3.12-slim in Jenkins, or locally.
set -euo pipefail
cd "$(dirname "$0")/.."

VENV="${CI_VENV:-/tmp/ci-venv}"
python -m venv "$VENV"
# shellcheck disable=SC1091
. "$VENV/bin/activate"
pip install --quiet --disable-pip-version-check --no-cache-dir \
  -r services/common/requirements.txt pytest==8.3.4 ruff==0.8.4

echo "== lint =="
ruff check services

echo "== tests =="
for svc in payment-service frontend; do
  echo "-- $svc"
  (cd "services/$svc" && PYTHONPATH="$PWD:$PWD/.." python -m pytest -q -p no:cacheprovider tests)
done
