#!/usr/bin/env bash
# Writes through the primary endpoint and opens separate read connections to demonstrate replica balancing.
set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CLIENT=(docker compose --profile tools run --rm --no-deps client)
cd "${PROJECT_DIR}"

# The write path must always reach the elected primary; the table also provides data for replica reads.
"${CLIENT[@]}" -h haproxy -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -c '
CREATE TABLE IF NOT EXISTS routing_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  server_address inet NOT NULL DEFAULT inet_server_addr()
);
INSERT INTO routing_events DEFAULT VALUES;
'

printf '\nWrite endpoint (must report in_recovery = f):\n'
"${CLIENT[@]}" -h haproxy -p 5432 -U postgres -d postgres -Atc \
  "SELECT inet_server_addr(), pg_is_in_recovery(), count(*) FROM routing_events GROUP BY 1, 2;"

printf '\nRead endpoint (new connection per row; addresses should alternate):\n'
for attempt in 1 2 3 4 5 6; do
  "${CLIENT[@]}" -h haproxy -p 5433 -U postgres -d postgres -Atc \
    "SELECT ${attempt}, inet_server_addr(), pg_is_in_recovery(), count(*) FROM routing_events GROUP BY 1, 2, 3;"
done
