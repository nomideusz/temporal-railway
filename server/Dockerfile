# Temporal server plus the schema tool from admin-tools, so every deploy migrates
# the database before the server starts (the stock server image can't).
# Bump both tags together.
FROM temporalio/admin-tools:1.32.1 AS tools

FROM temporalio/server:1.32.1
COPY --from=tools /usr/local/bin/temporal-sql-tool /usr/local/bin/temporal-sql-tool
COPY --from=tools /etc/temporal/schema/postgresql/v12 /etc/temporal/schema/postgresql/v12
COPY dynamicconfig.yaml /etc/temporal/config/dynamicconfig/docker.yaml
COPY railway-entrypoint.sh /etc/temporal/railway-entrypoint.sh
# Listen on IPv6 and IPv4 (Railway's private network); members find each other on loopback.
# No authorizer by design: the frontend is private-network only (future versions need this opt-in).
ENV DB=postgres12 \
    BIND_ON_IP=:: \
    TEMPORAL_BROADCAST_ADDRESS=127.0.0.1 \
    TEMPORAL_ALLOW_NO_AUTH=true
CMD ["/etc/temporal/railway-entrypoint.sh"]
