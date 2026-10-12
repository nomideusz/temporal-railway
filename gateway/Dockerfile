FROM caddy:2.11.7-alpine
COPY Caddyfile /etc/caddy/Caddyfile
# Caddy wants a bcrypt hash; derive it from the generated password on every boot.
# No password = no start, so the UI is never served open by accident.
CMD ["/bin/sh", "-c", ": \"${BASIC_AUTH_PASSWORD:?BASIC_AUTH_PASSWORD is required}\"; BASIC_AUTH_HASH=$(caddy hash-password --plaintext \"$BASIC_AUTH_PASSWORD\") && export BASIC_AUTH_HASH && exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile"]
