#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8080}
echo "stock before:"; curl -s localhost:8003/stock/laptop; echo
echo "checkout:"
curl -s -X POST "$BASE/api/checkout" -H 'Content-Type: application/json' \
  -d '{"item_id":"laptop","quantity":1,"amount":99.0}'; echo
echo "stock after:"; curl -s localhost:8003/stock/laptop; echo
