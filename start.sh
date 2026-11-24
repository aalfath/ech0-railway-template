#!/bin/sh
# Railway start script for Ech0 (aalfath/ech0-railway-template).
# 1. On a fresh volume, create the owner account on a loopback-only instance
#    before any public port opens, and check that open sign-up is off.
# 2. Run Ech0 on 127.0.0.1 behind Caddy on $PORT. If either process dies,
#    stop the other and exit non-zero so Railway's ON_FAILURE policy restarts us.
set -eu

DATA_DIR=/app/data
MARKER="$DATA_DIR/.railway-owner-created"
INTERNAL_PORT=6277
BOOT_PORT=6279
export ECH0_INTERNAL_PORT="$INTERNAL_PORT"
export PORT="${PORT:-8080}"

log() { echo "railway-start: $*"; }
die() { echo "railway-start: ERROR: $*" >&2; exit 1; }

# Go runtime sized to the container, not the host (Railway shows 32 CPUs).
cpus=1
if [ -r /sys/fs/cgroup/cpu.max ]; then
	read -r q p < /sys/fs/cgroup/cpu.max || true
	if [ "${q:-max}" != "max" ] && [ -n "${p:-}" ]; then
		cpus=$(( (q + p - 1) / p ))
	else
		cpus=2
	fi
fi
[ "$cpus" -ge 1 ] || cpus=1
[ "$cpus" -le 4 ] || cpus=4
export GOMAXPROCS="${GOMAXPROCS:-$cpus}"
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
	m=$(cat /sys/fs/cgroup/memory.max)
	if [ "$m" != "max" ]; then
		export GOMEMLIMIT="$(( m * 70 / 100 / 1048576 ))MiB"
	fi
fi

# Public URL and passkey defaults, seeded into Ech0's settings on first boot only.
dom="${RAILWAY_PUBLIC_DOMAIN:-}"
case "$dom" in
	*.*) ;;
	*) dom="" ;;
esac
if [ -n "$dom" ]; then
	export ECH0_SETTING_SERVER_URL="${ECH0_SETTING_SERVER_URL:-https://$dom}"
	export ECH0_AUTH_WEBAUTHN_RP_ID="${ECH0_AUTH_WEBAUTHN_RP_ID:-$dom}"
	export ECH0_AUTH_WEBAUTHN_ORIGINS="${ECH0_AUTH_WEBAUTHN_ORIGINS:-https://$dom}"
fi
case "${ECH0_SETTING_SERVER_URL:-}" in
	http://?*.*|https://?*.*) ;;
	*) unset ECH0_SETTING_SERVER_URL ;;
esac
export ECH0_SETTING_ALLOW_REGISTER="${ECH0_SETTING_ALLOW_REGISTER:-false}"

mkdir -p "$DATA_DIR"
if [ "$(stat -c %u "$DATA_DIR")" != "10001" ]; then
	chown -R 10001:10001 "$DATA_DIR" || die "could not take ownership of $DATA_DIR"
fi
mkdir -p /tmp/caddy && chown 10001:10001 /tmp/caddy

http_get() { wget -q -T 5 -O - "$1"; }
wait_health() { # port seconds
	i=0
	while [ "$i" -lt "$2" ]; do
		if http_get "http://127.0.0.1:$1/healthz" 2>/dev/null | grep -q '"status":"ok"'; then
			return 0
		fi
		i=$((i + 1)); sleep 1
	done
	return 1
}

bootstrap() {
	user="${ECH0_ADMIN_USERNAME:-admin}"
	pass="${ECH0_ADMIN_PASSWORD:-}"
	email="${ECH0_ADMIN_EMAIL:-admin@example.com}"
	[ "${#pass}" -ge 12 ] || die "ECH0_ADMIN_PASSWORD must be set and at least 12 characters (the template generates one)."
	[ "$(printf %s "$pass" | wc -c)" -le 72 ] || die "ECH0_ADMIN_PASSWORD must be at most 72 bytes."
	for v in "$user" "$pass" "$email"; do
		case "$v" in *'"'*|*'\'*) die "admin username, password and email must not contain \" or \\" ;; esac
	done
	[ -n "$user" ] || die "ECH0_ADMIN_USERNAME is empty."

	log "first boot: creating the owner account on a loopback-only instance"
	ECH0_SERVER_HOST=127.0.0.1 ECH0_SERVER_PORT="$BOOT_PORT" su-exec 10001:10001 /app/ech0 serve >/tmp/ech0-boot.log 2>&1 &
	bpid=$!
	if ! wait_health "$BOOT_PORT" 120; then
		tail -n 40 /tmp/ech0-boot.log >&2 || true
		kill "$bpid" 2>/dev/null || true
		die "Ech0 did not become healthy on the loopback port"
	fi
	status=$(http_get "http://127.0.0.1:$BOOT_PORT/api/init/status")
	case "$status" in
		*'"initialized":true'*) log "instance already initialised; keeping the existing owner" ;;
		*'"initialized":false'*)
			body=$(printf '{"username":"%s","password":"%s","email":"%s","locale":"en-US","site_title":"Ech0"}' "$user" "$pass" "$email")
			res=$(wget -q -T 20 -O - --header 'Content-Type: application/json' --post-data "$body" "http://127.0.0.1:$BOOT_PORT/api/init/owner" 2>&1) || true
			case "$res" in *'"code":1'*) ;; *) kill "$bpid" 2>/dev/null || true; die "owner creation failed: $res" ;; esac
			;;
		*) kill "$bpid" 2>/dev/null || true; die "unexpected init status: $status" ;;
	esac
	status=$(http_get "http://127.0.0.1:$BOOT_PORT/api/init/status")
	case "$status" in *'"initialized":true'*'"owner_exists":true'*|*'"owner_exists":true'*'"initialized":true'*) ;; *) kill "$bpid" 2>/dev/null || true; die "instance still not initialised: $status" ;; esac
	settings=$(http_get "http://127.0.0.1:$BOOT_PORT/api/settings")
	case "$settings" in
		*'"allow_register":false'*) ;;
		*) kill "$bpid" 2>/dev/null || true; die "open sign-up is not off after bootstrap: $settings" ;;
	esac
	kill "$bpid" 2>/dev/null || true
	wait "$bpid" 2>/dev/null || true
	su-exec 10001:10001 sh -c "date -u > '$MARKER'" || die "could not write $MARKER"
	log "owner '$user' created; open sign-up is off"
}

if [ ! -f "$MARKER" ]; then
	bootstrap
fi

ECH0_SERVER_HOST=127.0.0.1 ECH0_SERVER_PORT="$INTERNAL_PORT" su-exec 10001:10001 /app/ech0 serve &
epid=$!
wait_health "$INTERNAL_PORT" 120 || { kill "$epid" 2>/dev/null || true; die "Ech0 did not become healthy"; }
su-exec 10001:10001 caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
cpid=$!
log "Ech0 $(http_get "http://127.0.0.1:$INTERNAL_PORT/healthz" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p') listening on :$PORT (GOMAXPROCS=$GOMAXPROCS GOMEMLIMIT=${GOMEMLIMIT:-none})"

stop() { kill "$epid" "$cpid" 2>/dev/null || true; wait 2>/dev/null || true; exit 143; }
trap stop TERM INT

# BusyBox `wait -n` doesn't return on the first child exit, so poll.
while kill -0 "$epid" 2>/dev/null && kill -0 "$cpid" 2>/dev/null; do
	sleep 2
done
kill -0 "$epid" 2>/dev/null && echo "railway-start: Caddy exited" >&2 || echo "railway-start: Ech0 exited" >&2
kill "$epid" "$cpid" 2>/dev/null || true
exit 1
