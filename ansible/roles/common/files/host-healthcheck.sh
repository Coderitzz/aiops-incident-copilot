#!/usr/bin/env bash
# Logs a warning to the journal when the host looks unhealthy.
# View with: journalctl -t host-healthcheck
set -uo pipefail

DISK_LIMIT="${DISK_LIMIT:-85}"
MEM_LIMIT="${MEM_LIMIT:-90}"
status=0

warn() { logger -t host-healthcheck -p user.warning "$1"; status=1; }

disk=$(df --output=pcent / | tail -1 | tr -dc '0-9')
[ "$disk" -ge "$DISK_LIMIT" ] && warn "root disk at ${disk}% (limit ${DISK_LIMIT}%)"

mem=$(free | awk '/Mem:/ {printf "%d", $3 / $2 * 100}')
[ "$mem" -ge "$MEM_LIMIT" ] && warn "memory at ${mem}% (limit ${MEM_LIMIT}%)"

failed=$(systemctl --failed --no-legend --plain | wc -l)
[ "$failed" -gt 0 ] && warn "${failed} failed systemd unit(s): $(systemctl --failed --no-legend --plain | awk '{print $1}' | paste -sd, -)"

[ "$status" -eq 0 ] && logger -t host-healthcheck -p user.info "ok disk=${disk}% mem=${mem}%"
exit "$status"
