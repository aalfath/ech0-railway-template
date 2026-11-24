# Ech0 for Railway: the official image, pinned by version and digest,
# plus a loopback-only first-boot owner bootstrap and a small Caddy front
# that passes the real client IP through Railway's proxy.
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM sn0wl1n/ech0:v6.0.0@sha256:ff35b895353e35f018dec0abccc6516a8b49ee4ce4d166067182a74a307fbb1b

COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --chmod=0644 Caddyfile /etc/railway/Caddyfile
COPY --chmod=0755 start.sh /usr/local/bin/railway-start.sh

ENV ECH0_SETTING_ALLOW_REGISTER=false \
    ECH0_LOG_FILE_ENABLE=false \
    XDG_CONFIG_HOME=/tmp/caddy \
    XDG_DATA_HOME=/tmp/caddy

EXPOSE 8080
USER root
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
CMD []
