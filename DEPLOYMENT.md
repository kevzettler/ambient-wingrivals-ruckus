# Wingrivals deployment

The DigitalOcean host is `ssh wingrivals` (Linux x86_64). Build the engine for
Linux; the Mac executable cannot run there. Build the browser runtime with
`scripts/local-browser.sh build-web` when its Rust sources change.

## Build

```bash
cd Ambient
docker build --platform linux/amd64 \
  --build-arg AMBIENT_BUILD_REVISION="$(git rev-parse HEAD)" \
  -f Dockerfile.server -t wingrivals-ambient:RELEASE .
cd ../wingrivals
PATH="$HOME/.cargo/bin:$PATH" RUSTUP_TOOLCHAIN=1.83.0 \
  CARGO_PROFILE_RELEASE_DEBUG=0 CARGO_INCREMENTAL=0 CARGO_BUILD_JOBS=2 \
  ../Ambient/target/debug/ambient build --release
cd ../Ambient/web/www
VITE_AMBIENT_SERVER_URL=https://wingrivals.com:9000 npm run build
cd ../../..
python3 scripts/deploy/stage-release.py RELEASE
```

Use a unique release name in place of `RELEASE`. Staging refuses to overwrite a
release directory. It collects the browser bundle, both game packages, source
revision/status metadata, and checksums under `Ambient/tmp/deploy/RELEASE`.
The source revision identifies the base commit; uncommitted recovery changes
are also part of the build. The Docker runtime serves prebuilt artifacts and
does not contain a Rust compiler.

On this Apple Silicon Mac, Docker's Apple virtualization and Rosetta options
were enabled with the owner's approval to accelerate Linux x86_64 compilation.
The previous Docker settings are backed up at
`/tmp/wingrivals-docker-settings-before-rosetta-20261023.json`.

## Remote layout

- `/root/wingrivals-deploy/releases/RELEASE/{web,game}`: versioned assets.
- `/root/wingrivals-deploy/current`: active website symlink.
- `/root/wingrivals-deploy/config/nginx.conf`: HTTPS configuration.
- `/etc/letsencrypt`: public certificates; mount the directory read-only so
  symlink changes during renewal are visible inside containers.
- Game transport: UDP 9000. Keep the HTTP status port private to localhost.
- Game startup URL:
  `https://wingrivals.com/releases/RELEASE/game/lsvr7wpee4biw3sleyscm7har4xzjvoa/`.
  Serve the package by URL to preserve sibling nameplates dependency URLs and
  ensure browser assets are loaded over public HTTPS.
- Nginx supplies COOP/COEP headers and the `application/wasm` MIME type.

Upload a release with `rsync -az`, then run `sha256sum -c SHA256SUMS --quiet`
inside the remote release directory. Transfer the image using `docker save |
ssh wingrivals docker load`. Keep the old server container/image until the new
one passes health and Chrome gameplay checks. Switch `current` atomically only
after the new server starts. Test the browser, not just the HTTP status route.

## Recovery deployment — live October 24, 2026

The old server was stopped and its certificate had expired in May 2024.
The certificate was renewed successfully through January 21, 2027. The
replacement Nginx and optimized Linux runtime are running. `current` points to
`releases/recovery-20261023`, and https://wingrivals.com serves the matching
optimized browser and game builds. Public HTTPS and WASM response headers pass
checks. Both containers use `unless-stopped` restart policies.

Image: `wingrivals-ambient:recovery-20261023` (190 MB), ID
`sha256:dcc54454e9f1df6a7a1d50a312c0702de163c9898d616a2e8bed55731711bfdf`.
The native optimized build completed successfully, and the executable's version
check passed locally and on the host. The remote server initialized the game
module and used about 52 MiB while idle.

Chrome verification: public WebTransport connection succeeded, both guest
client modules loaded, the ship/terrain/HUD rendered, and flight, boost, and
firing input responded. The private status route reported one player over a
multi-minute session. No client errors were captured; frame-delay warnings
remain (about 12–15% dropped frames in two reported windows). This is a gameplay
smoke test, not a performance or load certification. Screenshot:
`Ambient/tmp/deploy/deployed-chrome.png`.

The uploaded release also passed a startup check using the recovered Mac
runtime against the public package URL: `server_aceclone` loaded and completed
its startup event, and `/status` returned `{"playerCount":0}`. The temporary
localhost test server was stopped afterward.

Rollback material:

- `/root/wingrivals-backups/pre-recovery-20261023/deployment.tar.gz`: old website,
  Nginx config, and certificate state (private, root-only backup directory).
- `containers.json` in the same directory: old container configuration.
- `nginx-https-pre-recovery-20261023`: stopped original frontend container.
- `ambient-before-recovery-20261023`: original, already-stopped game server.
- `legacy/web`: copy of the original website. Restore the old homepage with
  `ln -s legacy current-next && mv -Tf current-next current` from the deployment
  directory. The old game server was already broken before this deployment;
  restoring it is not a known-working game rollback. Keep the renewed TLS setup.

`scripts/deploy/renew-certificate.sh` is installed through
`/etc/cron.d/wingrivals-certificate` (04:17 and 16:17, server time). It renews
through port 80, reloads Nginx, and restarts
Ambient to load the QUIC certificate. This disconnects players during renewal.
The successful certificate fingerprint is saved only after both services have
updated, so a later run retries a failed reload. Cron is active; output goes to
`/var/log/wingrivals-certificate-renewal.log`.

For subsequent releases, upload assets and load the image, run
`bash /root/wingrivals-deploy/config/start-server.sh RELEASE IMAGE`, inspect the
logs and health route, then atomically point `current` at `releases/RELEASE`.
Keep previous release assets available for clients already connected.
