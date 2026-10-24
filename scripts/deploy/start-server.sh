#!/usr/bin/env bash
# Run on the remote host after loading the image and uploading the release.
set -euo pipefail
release=${1:?Usage: start-server.sh RELEASE IMAGE}
image=${2:?Usage: start-server.sh RELEASE IMAGE}
[[ "$release" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || exit 2
deployment=/root/wingrivals-deploy
cd "$deployment/releases/$release"
sha256sum -c SHA256SUMS --quiet
docker image inspect "$image" >/dev/null
package="https://wingrivals.com/releases/$release/game/lsvr7wpee4biw3sleyscm7har4xzjvoa/"
curl --fail --silent --show-error "${package}ambient.toml" >/dev/null
previous="ambient-before-$release"
was_running=false
if docker container inspect ambient_serve_remote >/dev/null 2>&1; then
    # Refuse to overwrite an existing rollback container.
    if docker container inspect "$previous" >/dev/null 2>&1; then
        echo "Rollback container already exists: $previous" >&2
        exit 1
    fi
    was_running=$(docker inspect -f '{{.State.Running}}' ambient_serve_remote)
    docker stop ambient_serve_remote
    docker rename ambient_serve_remote "$previous"
fi
rollback() {
    docker logs ambient_serve_remote > "$deployment/failed-$release.log" 2>&1 || true
    docker rm -f ambient_serve_remote || true
    if docker container inspect "$previous" >/dev/null 2>&1; then
        docker rename "$previous" ambient_serve_remote
        if [[ "$was_running" == true ]]; then docker start ambient_serve_remote; fi
    fi
}
trap rollback ERR
docker run -d --name ambient_serve_remote --restart unless-stopped \
    --log-opt max-size=10m --log-opt max-file=3 \
    -p 9000:9000/udp -p 127.0.0.1:8999:8999 \
    -v /etc/letsencrypt:/etc/letsencrypt:ro -e RUST_LOG=info \
    "$image" serve --no-build --no-proxy --public-host wingrivals.com \
    --cert /etc/letsencrypt/live/wingrivals.com/fullchain.pem \
    --key /etc/letsencrypt/live/wingrivals.com/privkey.pem "$package"
healthy=false
for attempt in $(seq 1 90); do
    if curl --fail --silent http://127.0.0.1:8999/status > "$deployment/status.json"; then
        healthy=true
        break
    fi
    sleep 2
done
[[ "$healthy" == true ]]
trap - ERR
cat "$deployment/status.json"
echo "Server is responding. Verify logs before switching the website's current symlink."
