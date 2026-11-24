#!/usr/bin/env bash
# Usage: ./scripts/fault.sh <service> <latency|errors|leak|reset> [value]
#   ./scripts/fault.sh payment latency 3000   # add 3s latency
#   ./scripts/fault.sh payment errors 0.5     # 50% of requests fail
#   ./scripts/fault.sh payment leak 100       # leak 100 MB
#   ./scripts/fault.sh payment reset
set -euo pipefail
case "$1" in
  frontend) PORT=8080;; order) PORT=8001;; payment) PORT=8002;; inventory) PORT=8003;;
  *) echo "unknown service: $1"; exit 1;;
esac
URL=localhost:$PORT/faults
H='Content-Type: application/json'
case "$2" in
  latency) curl -s -X POST $URL -H "$H" -d "{\"latency_ms\": $3}";;
  errors)  curl -s -X POST $URL -H "$H" -d "{\"error_rate\": $3}";;
  leak)    curl -s -X POST $URL/leak -H "$H" -d "{\"mb\": $3}";;
  reset)   curl -s -X DELETE $URL;;
  *) echo "unknown fault: $2"; exit 1;;
esac
echo
