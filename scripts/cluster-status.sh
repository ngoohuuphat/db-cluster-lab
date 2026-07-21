#!/usr/bin/env bash
# Displays Patroni membership and HAProxy's current view of the PostgreSQL nodes.
set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

# Query one Patroni member because patronictl reads the complete cluster state from etcd.
docker compose exec -T patroni1 patronictl -c /etc/patroni/patroni.yml list

printf '\nPatroni role endpoints:\n'
for port in 8001 8002 8003; do
  response="$(curl --silent --show-error "http://127.0.0.1:${port}/patroni")"
  printf 'localhost:%s -> %s\n' "${port}" "${response}"
done

printf '\nHAProxy statistics: http://localhost:7000/\n'
