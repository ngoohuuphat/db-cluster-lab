# Builds a PostgreSQL image with Patroni and etcd v3 client support for the HA lab.
FROM postgres:17.10-bookworm

ARG PATRONI_VERSION=4.1.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        python3 \
        python3-pip \
        python3-psycopg2 \
    && pip3 install --break-system-packages --no-cache-dir "patroni[etcd3]==${PATRONI_VERSION}" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER postgres
ENTRYPOINT ["patroni"]
CMD ["/etc/patroni/patroni.yml"]
