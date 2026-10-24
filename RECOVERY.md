# Ambient and Wingrivals recovery

## Agreed direction

- First milestone: Wingrivals playable in Chrome on this Mac, with a local server.
- Native-only operation does not satisfy the milestone. Test multiplayer with localhost clients first.
- Restore the existing game content before changing gameplay or engine architecture.
- Maintain Ambient as a general-purpose Rust engine. Preserve its Rust guest API and declarative UI by default; modest API migrations are acceptable.
- Investigate Manifold (`thirdroom/src/manifold`) as a reference for separate game/render workers, shared-memory triple buffers, and input buffering.
- Reproduce the reported whole-game freeze on network failure before diagnosing lockstep or changing networking. The current client has a frame callback separate from incoming world diffs; both access shared game state.

## Starting revisions

- Ambient: `698cc2816` (April 6, 2026 compatibility fixes).
- Wingrivals: `49ee779` (April 6, 2026, "stabel build with latest ambient").
- Previous local browser gameplay was confirmed by the owner; the launch URL is forgotten.
- Rust installations and build outputs had subsequently been removed to recover disk space.

## Recovery in progress

Toolchains restored: Rust 1.88.0 for the engine, Rust 1.83.0 with `wasm32-wasi` for game packages, and `wasm32-unknown-unknown` for the browser engine. Use explicit toolchains; do not replace these with today's stable without testing.

The native engine and browser engine have separate Cargo lockfiles. The browser lockfile needs the same older-Rust compatibility corrections as the native engine: `time` 0.3.36 and `wasm-bindgen` 0.2.89. The matching wasm-bindgen CLI is stored under the ignored `Ambient/tmp/tools/` directory.

Builds disable debug symbols and incremental compilation to conserve disk space. Recovery was verified in Chrome on September 19, 2026: the island, ship, reticle, HUD, flight input, and firing render and operate locally. Two Chrome tabs with distinct `userId` values connected, and `/status` reported two players for more than two minutes without the earlier timeout errors. This is a smoke test, not a full gameplay or performance certification. See `RUN_BROWSER.md` and `scripts/local-browser.sh` for the reproducible procedure.

The browser runtime must use the optimized build from the script. The unoptimized bundle was about 63 MiB and showed timeout/backpressure during startup; the optimized bundle is about 28 MiB and passed the session checks. Chrome still reports frame-dropping warnings. The initial local verification used development server and guest builds; the October remote deployment uses optimized release builds for all three.

## Browser connection

`Ambient/web/www` is the local Vite page. Its default server is `https://127.0.0.1:9000`; Vite normally serves on port 5173. Ambient's `serve` command builds/hosts the game without opening a native client. Use `--no-proxy` for localhost to avoid the old Ambient proxy service.

The launcher generates a 13-day P-256 development certificate and passes its SHA-256 digest through Vite to the browser runtime's optional `serverCertificateHash` setting. Chrome uses WebTransport's certificate pinning; no custom profile, trust-store modification, or security flags are required. Both server listeners honor `--bind-address 127.0.0.1`.

## Compatibility fixes found during recovery

- Vendored the small wasm-bridge JS and macro crates with their MIT licenses and patch provenance. They needed an explicit WASM ABI bound and whitespace-tolerant removal of native-only generated assertions.
- Chrome rejected depth textures paired with filtering samplers. The shared screen-depth helper, sky, and water now use clamped `textureLoad` reads.
- The Vite production build needed an ES2022 target for the generated WASM loader's top-level await. TypeScript checking and bundling now pass.
- During slow debug startup, the server logs a 30-second timeout and the browser later reports a full outbound queue. This is an observed failure, not yet a confirmed explanation of the historical network-freeze report. Do not call it lockstep without further tracing.

## Existing game content and controls

Source references `Omega_Island_No_Sky_No_Sun_No_Trees.glb`, `fighter01.glb`, and `fighter04.glb`; these assets exist locally. The client maps mouse buttons to primary/secondary fire, Space to boost, S to brake, A/D to strafe, B to parking brake, and left Shift to target selection. Verify these in the restored browser build.

## DigitalOcean host

Access is available through `ssh wingrivals`. At initial inspection, `ambient_serve_remote` was stopped with exit code 1 and reported `Failed to find ambient.toml in package`. Its old source was `8cb81e2`, and the public TLS certificate had expired in May 2024.

On October 24, 2026, matching optimized Linux server, browser, and game builds were deployed as `recovery-20261023`. Public Chrome gameplay passed a smoke test: connection, guest modules, ship/terrain/HUD, flight/boost and firing. Frame-delay warnings persist. TLS was renewed and automated renewal installed. The old containers/files remain available for rollback. See `DEPLOYMENT.md` for the deployed image, commands, verification, and maintenance details.
