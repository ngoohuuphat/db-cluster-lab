# Provides short, repeatable commands for operating and demonstrating the database HA lab.
.PHONY: build up wait status demo failover logs down destroy validate

build:
	docker compose build

up:
	docker compose up -d --build

wait:
	@printf 'Waiting for HAProxy to become healthy...\n'
	@until [ "$$(docker inspect --format '{{.State.Health.Status}}' db-cluster-lab-haproxy-1 2>/dev/null)" = healthy ]; do sleep 2; done
	@printf 'Cluster is ready.\n'

status:
	./scripts/cluster-status.sh

demo:
	./scripts/routing-demo.sh

failover:
	./scripts/failover-demo.sh

logs:
	docker compose logs -f --tail=100

down:
	docker compose down

destroy:
	docker compose down --volumes --remove-orphans

validate:
	docker compose config --quiet
	docker run --rm -v "$(CURDIR)/config/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" haproxy:3.2.21-alpine haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
	bash -n scripts/*.sh
