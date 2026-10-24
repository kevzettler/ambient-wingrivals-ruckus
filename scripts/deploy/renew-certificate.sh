#!/usr/bin/env bash
set -euo pipefail
exec 9>/var/lock/wingrivals-certificate.lock
flock -n 9 || exit 0
cert=/etc/letsencrypt/live/wingrivals.com/fullchain.pem
state=/root/wingrivals-deploy/certificate-loaded.sha256
before=$(cat "$state" 2>/dev/null || true)
# Port 80 is reserved for this standalone ACME challenge responder.
docker run --rm -p 80:80 \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v /var/lib/letsencrypt:/var/lib/letsencrypt \
    certbot/certbot:latest renew --cert-name wingrivals.com --non-interactive --quiet
after=$(sha256sum "$cert")
if [[ "$before" != "$after" ]]; then
    docker exec nginx-https nginx -t
    docker exec nginx-https nginx -s reload
    # Ambient loads its QUIC certificate at startup. Reconnect clients after renewal.
    docker restart ambient_serve_remote
    printf '%s\n' "$after" > "$state"
fi
