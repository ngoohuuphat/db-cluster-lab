#!/usr/bin/env bash
# Stops the current primary, verifies automatic promotion and write recovery, then rejoins the old primary.
set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CLIENT=(docker compose --profile tools run --rm --no-deps client)
cd "${PROJECT_DIR}"

# Resolve the primary through role-aware REST checks instead of assuming a fixed node.
leader=""
for node_number in 1 2 3; do
  if curl --fail --silent "http://127.0.0.1:800${node_number}/primary" >/dev/null; then
    leader="patroni${node_number}"
    break
  fi
done

if [[ -z "${leader}" ]]; then
  printf 'No primary is currently available; aborting failover demo.\n' >&2
  exit 1
fi

printf 'Stopping current primary: %s\n' "${leader}"
docker compose stop "${leader}"

# Patroni normally promotes within the configured TTL; HAProxy then needs two successful health checks.
printf 'Waiting for a new primary and HAProxy write route'
ready="false"
for _ in $(seq 1 30); do
  if "${CLIENT[@]}" -h haproxy -p 5432 -U postgres -d postgres -Atc \
    "SELECT NOT pg_is_in_recovery();" 2>/dev/null | grep -qx t; then
    ready="true"
    break
  fi
  printf '.'
  sleep 2
done
printf '\n'

if [[ "${ready}" != "true" ]]; then
  printf 'A writable primary was not available within 60 seconds.\n' >&2
  docker compose start "${leader}"
  exit 1
fi

printf 'Automatic failover succeeded. Rejoining %s as a replica.\n' "${leader}"
docker compose start "${leader}"

printf 'Use scripts/cluster-status.sh after the old primary becomes healthy.\n'
