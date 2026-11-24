# Changelog

Deployers: read the entry for a version before you apply Railway's "update available" notice. Breaking changes are listed first.

## 6.0.0-railway.1 (2026-11-24)

- First release of this template: Ech0 v6.0.0 (`sn0wl1n/ech0:v6.0.0@sha256:ff35b895353e35f018dec0abccc6516a8b49ee4ce4d166067182a74a307fbb1b`).
- The owner account is created on first boot from `ECH0_ADMIN_USERNAME` / `ECH0_ADMIN_PASSWORD` on a loopback-only instance, before the public port opens. Open sign-up is off.
- Caddy 2.11.9 in front on `$PORT` passes the visitor's real IP to Ech0, so sign-in and comment rate limits work per visitor behind Railway's proxy.
- Health check `/healthz`; any crash of Ech0 or Caddy exits non-zero so Railway restarts the service.
