#!/bin/sh
# Migrate the schema, create the default namespace once the server is up, run the server.
set -eu
: "${POSTGRES_SEEDS:?}" "${POSTGRES_USER:?}" "${POSTGRES_PWD:?}"
NS="${DEFAULT_NAMESPACE:-default}"
SCHEMA=/etc/temporal/schema/postgresql/v12

sql() {
  db=$1; shift
  temporal-sql-tool --plugin postgres12 --ep "$POSTGRES_SEEDS" -p "${DB_PORT:-5432}" \
    -u "$POSTGRES_USER" --pw "$POSTGRES_PWD" --db "$db" "$@"
}

migrate() {
  for pair in temporal:temporal temporal_visibility:visibility; do
    name=${pair%%:*} dir=${pair#*:}
    # "already exists" is fine; any real error shows up in the next two steps.
    sql "$name" create >/dev/null 2>&1 || true
    sql "$name" setup-schema -v 0.0 && sql "$name" update-schema -d "$SCHEMA/$dir/versioned" || return 1
  done
}

# Postgres may still be starting on the first deploy.
i=0
until migrate; do
  i=$((i + 1)); [ "$i" -ge 40 ] && { echo "schema migration failed" >&2; exit 1; }
  echo "waiting for Postgres ($i)..."; sleep 3
done

# The stock server image has no CLI; the frontend's HTTP API (7243) registers namespaces.
(
  api="http://127.0.0.1:${FRONTEND_HTTP_PORT:-7243}/api/v1/namespaces"
  for _ in $(seq 60); do
    sleep 3
    wget -q -O /dev/null "$api/$NS" 2>/dev/null && exit 0
    wget -q -O /dev/null --header 'Content-Type: application/json' \
      --post-data "{\"namespace\":\"$NS\",\"workflowExecutionRetentionPeriod\":\"259200s\"}" "$api" 2>/dev/null \
      && { echo "created namespace $NS (3 day retention)"; exit 0; }
  done
  echo "could not create namespace $NS" >&2
) &

exec temporal-server start
