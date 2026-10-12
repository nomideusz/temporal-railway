# Deploy and Host Temporal on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/temporal-server?utm_medium=integration&utm_source=button&utm_campaign=temporal-server)

[Temporal](https://temporal.io/) is the open-source durable execution engine. You write workflows as ordinary code in Go, Java, TypeScript, Python, .NET, PHP or Ruby, and Temporal keeps them running through crashes, deploys and outages, with retries, timers, signals and full event history. This template runs the Temporal server with Postgres for both persistence and advanced visibility, so it needs no Elasticsearch, plus the Temporal Web UI behind a password.

## About Hosting Temporal

The stack has four services: Temporal, Temporal-UI, Gateway and Postgres.

- **The production image, not auto-setup.** `temporalio/auto-setup` is a development convenience image. Temporal stopped publishing it after 1.29, and it never ran migrations safely on upgrade. This template runs the official `temporalio/server` image (pinned at 1.32.1) with `temporal-sql-tool` copied in from the matching `temporalio/admin-tools` image.
- **Schema migrations on every deploy.** Before the server starts, the entrypoint creates the `temporal` and `temporal_visibility` databases if needed, then runs `update-schema` on both. Railway's health check only passes once the server is answering. To upgrade, bump the image tag.
- **Advanced visibility on Postgres.** List filters such as `WorkflowType='Order' AND ExecutionStatus='Running'`, custom search attributes and workflow counts all run on Postgres 12+. Elasticsearch would add a JVM using 1 GB or more, and this template leaves it out.
- **A `default` namespace is ready.** It is created on first boot with 3-day retention.
- **The Web UI is password-protected.** The Temporal UI has no login of its own. The Gateway (Caddy) holds the public domain and asks for HTTP basic auth (`admin` and the generated `BASIC_AUTH_PASSWORD`) before anything reaches the UI. Temporal-UI and Temporal are on the private network only.

## Common Use Cases

- Long-running business processes such as order fulfilment, onboarding, billing cycles and approvals, which must survive restarts
- Reliable background jobs and queues with retries, timeouts, rate limits and cron schedules
- Orchestrating AI agents and LLM pipelines, where each step can be retried and the whole run can be replayed
- Sagas and distributed transactions across microservices, with compensation on failure

## Dependencies for Temporal Hosting

- Postgres 17 (included, private network only)
- Your own worker processes using a Temporal SDK (deploy them to the same Railway project)

### Deployment Dependencies

- [Temporal self-hosting guide](https://docs.temporal.io/self-hosted-guide)
- [Temporal on GitHub](https://github.com/temporalio/temporal)
- [Temporal Web UI](https://github.com/temporalio/ui)
- [Template source on GitHub](https://github.com/nomideusz/temporal-railway)

### Implementation Details

**Connect your workers (same project).** Add your worker as a service in this Railway project and point its SDK at the frontend over private networking:

```
TEMPORAL_ADDRESS=${{Temporal.RAILWAY_PRIVATE_DOMAIN}}:7233
TEMPORAL_NAMESPACE=default
```

Temporal listens on `::`, so this works in both IPv6-only and dual-stack Railway environments. Traffic on the private network does not leave Railway, and no TLS or API key is needed.

**Workers outside Railway: secure the frontend first.** The frontend gRPC port (7233) has **no authentication** by default. Anyone who can reach it can start, terminate or read every workflow. That is why this template does not expose it publicly. If you need external workers or a local `temporal` CLI:

1. Turn on mTLS on the Temporal service (`TEMPORAL_TLS_SERVER_CERT_DATA`, `TEMPORAL_TLS_SERVER_KEY_DATA`, `TEMPORAL_TLS_SERVER_CA_CERT_DATA`, `TEMPORAL_TLS_REQUIRE_CLIENT_AUTH=true`), or JWT authorization (`TEMPORAL_AUTH_AUTHORIZER=default`, `TEMPORAL_AUTH_CLAIM_MAPPER=default`, `TEMPORAL_JWT_KEY_SOURCE1=<your JWKS URL>`). See [Temporal security](https://docs.temporal.io/self-hosted-guide/security).
2. Then open Temporal's Settings → Networking → **TCP Proxy** on port `7233`, and connect clients to the `xyz.proxy.rlwy.net:PORT` address it gives you.

**Open the Web UI.** Use the Gateway service's Railway domain. Sign in as `admin` with `BASIC_AUTH_PASSWORD` from the Gateway's Variables tab.

**Single sign-on (optional).** The UI supports OIDC (Google, Auth0, Okta, Keycloak and others). Register `https://<gateway domain>/auth/sso/callback` with your provider, then fill in `TEMPORAL_AUTH_PROVIDER_URL`, `TEMPORAL_AUTH_CLIENT_ID` and `TEMPORAL_AUTH_CLIENT_SECRET`, and set `TEMPORAL_AUTH_ENABLED=true` on Temporal-UI. You can keep the Gateway password as a second layer. If you want OIDC on its own, move the public domain to Temporal-UI, update the callback URL and `TEMPORAL_CORS_ORIGINS`, and delete the Gateway. **Never** give Temporal-UI a public domain without OIDC enabled.

**Custom domain.** Add it to the Gateway, then add `https://your-domain` to `TEMPORAL_CORS_ORIGINS` on Temporal-UI (comma-separated).

**History shards are permanent.** `NUM_HISTORY_SHARDS` (default 4) is fixed when the cluster is first created and can never be changed. 4 suits small and medium workloads on this single-node setup. If you expect heavy throughput, raise it before the first deploy. More shards use more memory and database connections.

**Upgrades.** The Temporal service builds from the [template repo](https://github.com/nomideusz/temporal-railway), which pins `temporalio/server` and `temporalio/admin-tools` to the same version in `server/Dockerfile`. Redeploying picks up the repo's current pin, and migrations run before the server starts (it refuses to start on a mismatched schema). To control upgrades yourself, fork the repo and point the service at your fork. Temporal supports upgrading one minor version at a time (1.31 → 1.32 → 1.33), so do not skip minors.

**CLI, more namespaces and retention.** The server image ships no CLI. For admin commands, add a service from the `temporalio/admin-tools:1.32.1` image with `TEMPORAL_ADDRESS=${{Temporal.RAILWAY_PRIVATE_DOMAIN}}:7233`, open it with `railway ssh`, and run for example `temporal operator namespace create --namespace orders --retention 30d`. Delete the service when you are done.

**Back up Postgres.** All workflow state, history and visibility live in the `temporal` and `temporal_visibility` databases on the Postgres volume.

**Resources.** In testing the whole stack idled at about 230 MB of RAM: Temporal 75 MB with 4 shards, Postgres 125 MB, and the UI and Gateway about 11 MB each. A cold first boot (migrations and namespace) was healthy in about 10 seconds. It fits the Hobby plan, and each service stays well under Trial's 512 MB.

## Why Deploy Temporal on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Temporal on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
