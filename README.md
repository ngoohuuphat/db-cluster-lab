<!-- Documents how to run, observe, and safely experiment with the local PostgreSQL load-balancing lab. -->
# PostgreSQL HA and load-balancing lab

This lab runs three PostgreSQL 17 nodes managed by Patroni, a three-member etcd quorum, and one HAProxy instance. It is designed for learning on one Docker host, not for production deployment.

## Architecture

| Client endpoint | HAProxy health check | Eligible nodes | Purpose |
| --- | --- | --- | --- |
| `localhost:15432` | Patroni `/primary` | Current primary only | Reads that require the latest data and all writes |
| `localhost:15433` | Patroni `/replica?lag=16MB` | Healthy replicas below the lag limit | Read scaling, balanced per new TCP connection |
| `localhost:7000` | N/A | HAProxy statistics | Visual routing and health status |

Patroni uses etcd as its distributed configuration store and leader lock. HAProxy asks each Patroni REST API which PostgreSQL role is safe for a route; it does not infer roles from a basic TCP check.

```text
                         +--> PostgreSQL / Patroni 1
Application --> HAProxy +--> PostgreSQL / Patroni 2 --> etcd quorum (3 members)
                         +--> PostgreSQL / Patroni 3

                :15432 write -> primary only
                :15433 read  -> healthy replicas, round-robin per connection
```

## Requirements

- Docker Engine with Docker Compose v2 or newer
- At least 4 GB of free memory for a comfortable run
- `curl` on the host for the status and failover scripts

## Start the lab

Optionally copy `.env.example` to `.env` and change the disposable credentials. The defaults work without an `.env` file.

```bash
make up
make wait
make status
```

The first build installs Patroni into the PostgreSQL image and can take several minutes. `make status` should show one `Leader` and two `Replica` members.

## Verify write and read routing

Run the automated demonstration:

```bash
make demo
```

The command creates and inserts into `routing_events` through the internal write endpoint. It then opens six independent connections through the internal read endpoint; the server address should alternate between the two replicas, and `pg_is_in_recovery()` should return `t`.

HAProxy balances connections, not individual SQL statements. A connection pool that keeps a small number of long-lived connections will therefore show less even distribution than many short connections.

Manual connections are also available through the disposable client container:

```bash
# Read/write endpoint
docker compose --profile tools run --rm client -h haproxy -p 5432 -U postgres -d postgres

# Read-only routing endpoint
docker compose --profile tools run --rm client -h haproxy -p 5433 -U postgres -d postgres
```

Applications running on the host should connect to `localhost:15432` for writes and strongly consistent reads, or `localhost:15433` for replica reads. These host ports can be changed with `WRITE_PORT` and `READ_PORT` in `.env`; the container examples keep using the fixed internal ports.

## Test automatic failover

```bash
make failover
make status
make demo
```

The failover script discovers and stops the current primary, waits up to 60 seconds for Patroni to promote a replica and HAProxy to restore the write route, then starts the old primary so Patroni can rejoin it as a replica. Existing client transactions can fail during promotion; applications must retry aborted transactions safely.

## Observe the lab

- HAProxy statistics: <http://localhost:7000/>
- Patroni node APIs: <http://localhost:8001/patroni>, <http://localhost:8002/patroni>, and <http://localhost:8003/patroni>
- Logs: `make logs`
- Cluster membership: `make status`

## Stop or reset

`make down` removes containers and the network but preserves database and etcd volumes. `make destroy` also deletes all lab data volumes and cannot recover their data.

```bash
make down
# Or, to erase the cluster completely:
make destroy
```

## Important limitations

- All containers run on one Docker host, so this demonstrates database failover but does not survive host failure.
- Traffic and credentials are unencrypted and intended only for a private local lab.
- The replication mode is asynchronous. A primary failure can lose transactions that were not replicated yet.
- The read endpoint is eventually consistent. Send read-after-write operations to host port `15432` when consistency matters.
- HAProxy is a single point of failure in this lab. Production deployments require redundant load balancers or a managed endpoint.
- Backups, PITR, monitoring, TLS, secret management, fencing, capacity planning, and application retry policy are intentionally outside this small lab.
