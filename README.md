# Ech0 on Railway

One-click Railway template for [Ech0](https://github.com/lin-snow/Ech0), a lightweight self-hosted personal microblog: publish short notes, links and media to your own timeline, with RSS, optional comments, passkeys and OAuth2 sign-in.

- **Ech0 version:** v6.0.0, official image `sn0wl1n/ech0:v6.0.0@sha256:ff35b895353e35f018dec0abccc6516a8b49ee4ce4d166067182a74a307fbb1b` (pinned by version and digest in the [`Dockerfile`](Dockerfile)).
- **One service**, built from this repo, with one Railway volume at `/app/data` (SQLite database and uploaded files).
- **No open sign-up and no claimable setup page:** on first boot the start script creates the owner account on a loopback-only instance before the public port opens, then checks that registration is off. If that fails, the service stops instead of serving an unclaimed instance.
- A small Caddy front on `$PORT` passes each visitor's real IP to Ech0, so its per-IP sign-in and comment limits work behind Railway's proxy.
- Fits Railway's Free plan (0.5 GB RAM, 1 vCPU). The Go runtime is sized from the container's limits.

## Variables

| Variable | Default | What it is |
|---|---|---|
| `ECH0_ADMIN_USERNAME` | `admin` | Username of the owner account created on first boot. |
| `ECH0_ADMIN_PASSWORD` | `${{secret(24)}}` | Owner password, generated per deploy. Read it in the service's Variables tab. Used only on first boot; change it later in Ech0's panel. |
| `PORT` | `8080` | Port Caddy listens on (Railway routes the public domain here). |

The public URL (`https://${RAILWAY_PUBLIC_DOMAIN}`) is seeded as the server URL and passkey origin on first boot. Comments, S3 storage, OAuth2/OIDC, passkeys, webhooks, MCP and the AI agent are set up in Ech0's admin panel after you sign in.

## After deploy

1. Open the public URL and sign in with `ECH0_ADMIN_USERNAME` and `ECH0_ADMIN_PASSWORD`.
2. In the panel, set your email and site details, and change the password if you like.
3. To let others sign up, turn on registration in the panel's system settings (up to 5 users).

## Updates

This template builds from this repo. When the pinned Ech0 version is bumped on `main`, Railway shows an "update available" notice on your project, and you choose when to apply it. Read [`CHANGELOG.md`](CHANGELOG.md) first. Your data stays on the volume.

## Licence and source

Ech0 is © L1nSn0w and contributors, licensed AGPL-3.0-or-later. This template runs the unmodified official image; its source is at <https://github.com/lin-snow/Ech0>. Upstream's notice is kept in [`NOTICE.ech0`](NOTICE.ech0). The wrapper files in this repo (`Dockerfile`, `start.sh`, `Caddyfile`) are under the same licence.
