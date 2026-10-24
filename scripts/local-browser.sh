#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
engine_dir="$repo_root/Ambient"
cert_dir="$engine_dir/tmp/local-browser"
export PATH="$HOME/.cargo/bin:$PATH"
export CARGO_PROFILE_DEV_DEBUG=0
export CARGO_PROFILE_DEV_INCREMENTAL=false
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_PROFILE_RELEASE_INCREMENTAL=false
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-3}"

prepare_certificate() {
    mkdir -p "$cert_dir"
    if [[ -f "$cert_dir/cert.pem" && -f "$cert_dir/key.pem" ]] &&
        openssl x509 -in "$cert_dir/cert.pem" -checkend 86400 -noout >/dev/null 2>&1; then
        return
    fi
    cat > "$cert_dir/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = extensions
prompt = no
[dn]
CN = localhost
[extensions]
subjectAltName = IP:127.0.0.1,DNS:localhost
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = serverAuth
EOF
    # WebTransport certificate pins require P-256 and at most 14 days validity.
    (umask 077; openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -nodes -days 13 -config "$cert_dir/openssl.cnf" \
        -keyout "$cert_dir/key.pem" -out "$cert_dir/cert.pem")
}

case "${1:-help}" in
    build-engine)
        cd "$engine_dir"
        exec cargo +1.88.0 build --locked -p ambient
        ;;
    build-web)
        cd "$engine_dir/web"
        cargo +1.88.0 build --locked --release -p ambient_web
        bindgen="$engine_dir/tmp/tools/wasm-bindgen-0.2.89-aarch64-apple-darwin/wasm-bindgen"
        if [[ ! -x "$bindgen" ]]; then
            echo "Missing wasm-bindgen 0.2.89; see RUN_BROWSER.md." >&2
            exit 1
        fi
        "$bindgen" --target bundler --out-dir pkg --out-name ambient_web \
            target/wasm32-unknown-unknown/release/ambient_web.wasm
        cat > pkg/package.json <<'EOF'
{"name":"ambient_web","version":"0.3.2-dev","type":"module","main":"ambient_web.js","types":"ambient_web.d.ts","sideEffects":["./ambient_web.js","./snippets/*"]}
EOF
        cd www
        npm ci --no-audit --no-fund
        ;;
    server)
        prepare_certificate
        cd "$repo_root/wingrivals"
        export RUSTUP_TOOLCHAIN=1.83.0
        export RUST_LOG="${RUST_LOG:-info}"
        exec "$engine_dir/target/debug/ambient" serve --debug --bind-address 127.0.0.1 \
            --no-proxy --cert "$cert_dir/cert.pem" --key "$cert_dir/key.pem"
        ;;
    web)
        prepare_certificate
        export VITE_AMBIENT_CERT_SHA256
        VITE_AMBIENT_CERT_SHA256="$(openssl x509 -in "$cert_dir/cert.pem" -outform DER | openssl dgst -sha256 | awk '{print $NF}')"
        cd "$engine_dir/web/www"
        exec npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
        ;;
    *)
        echo "Usage: bash scripts/local-browser.sh {build-engine|build-web|server|web}"
        ;;
esac
