# Run Wingrivals locally in Chrome

Verified September 19, 2026 on this Apple Silicon Mac: game rendering, flight
input, visible firing, and two connected Chrome clients. Frame-dropping warnings
remain; engine performance work and deliberate network-disconnect testing are
separate follow-ups.

Run these commands from the root of this repository. The engine, browser client,
and game must use matching local source revisions. The old production HTML under
`wingrivals/nginx/html` loads a 2023 hosted client and is not this development page.

## Start

In one terminal:

```sh
bash scripts/local-browser.sh server
```

In another:

```sh
bash scripts/local-browser.sh web
```

Open **http://127.0.0.1:5173/** in Chrome. The server builds the game and assets
before accepting connections. A second tab at the same address is a second client.
Stop each terminal with Ctrl-C.

The game connection uses WebTransport on `127.0.0.1:9000`; assets and the
`/status` endpoint use HTTP on `127.0.0.1:8999`. Vite serves the browser engine
on `127.0.0.1:5173`. No Ambient cloud or proxy service is needed for this path.

The launcher generates a local P-256 certificate valid for 13 days and passes
its SHA-256 digest to the browser through Vite. Chrome authenticates the
WebTransport server against that exact certificate. No system certificate
installation or browser security flags are needed. Certificates and keys live
under ignored `Ambient/tmp/local-browser/`; do not commit them. Restart both
terminals after certificate renewal (the launcher renews within a day of expiry).
The Vite pin is used only in development and only for `https://127.0.0.1:9000`.

## Rebuild after engine changes

```sh
bash scripts/local-browser.sh build-engine
bash scripts/local-browser.sh build-web
```

Restart the server and web terminals, then reload Chrome. Game-only source or
asset changes are rebuilt when the server starts. The browser runtime is optimized
because an unoptimized WASM-to-JavaScript translator can block long enough to
time out the connection while loading game modules. The server and guest modules
remain development builds; this setup is not a production deployment.

## First-time prerequisites (Apple Silicon Mac)

Install Rust using the official installer at https://rustup.rs if absent, plus
Node/npm, CMake, and the Xcode command-line tools. Then:

```sh
rustup toolchain install 1.88.0 --profile minimal
rustup component add rustfmt --toolchain 1.88.0
rustup target add --toolchain 1.88.0 wasm32-unknown-unknown
rustup toolchain install 1.83.0 --profile minimal --target wasm32-wasi
rustup component add rustfmt --toolchain 1.83.0

mkdir -p Ambient/tmp/tools
curl --proto '=https' --tlsv1.2 -fL \
  https://github.com/rustwasm/wasm-bindgen/releases/download/0.2.89/wasm-bindgen-0.2.89-aarch64-apple-darwin.tar.gz \
  -o Ambient/tmp/tools/wasm-bindgen.tar.gz
tar -xzf Ambient/tmp/tools/wasm-bindgen.tar.gz -C Ambient/tmp/tools

bash scripts/local-browser.sh build-engine
bash scripts/local-browser.sh build-web
```

The script expects that exact wasm-bindgen CLI; it must match the browser
lockfile. It disables Rust debug symbols and incremental caches to save disk
space. The server toolchain differs from the guest toolchain: Rust 1.83 still
provides the legacy `wasm32-wasi` target used by this Ambient revision.

## Controls recovered from source

- Mouse: steer/aim; buttons: primary and secondary fire.
- Space: boost; S: brake; A/D: strafe.
- B: parking brake; left Shift: select target.

## Recovery changes

- Browser lockfile compatibility pins: time 0.3.36 and wasm-bindgen 0.2.89.
- Small vendored wasm-bridge patches under `Ambient/web/vendor`, with provenance
  and patch descriptions alongside the original MIT licenses.
- Optional explicit WebTransport certificate pin in browser settings.
- HTTP listener now honors the server's `--bind-address`.
- Screen-depth reads use `textureLoad`, avoiding invalid filtering-sampler
  bindings on depth textures in Chrome WebGPU.

See `RECOVERY.md` for project scope and the read-only DigitalOcean inspection.
