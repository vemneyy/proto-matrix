# Proto-Matrix

Fast, parallel CLI to audit domains for TLS 1.2/1.3, HTTP/1.1/2/3 (QUIC), HSTS and response time — printed as a single, colorized table.

## What it does

For each domain in `domains.txt`, the script:

- Ensures the URL has a scheme (adds `https://` if missing).
- Tries up to **3** curl attempts per check with a **1s** per-request timeout.
- Probes:
  - **TLS 1.2** (capped via `--tls-max 1.2`)
  - **TLS 1.3** (forced via `--tlsv1.3 --tls-max 1.3`)
  - **HTTP/1.1** (`--http1.1`)
  - **HTTP/2** (`--http2`)
  - **HTTP/3 / QUIC** (`--http3-only`)
- Measures total time (ms) from the TLS 1.3 request (falls back to the TLS 1.2 request if 1.3 fails).
- Checks **HSTS** via a HEAD request (`Strict-Transport-Security` header).
- Prints a row per domain with Y/N flags and an **OK/FAIL** status:
  - A domain is **OK** if the main response code is **2xx–4xx**; **5xx** or no response is **FAIL**.
- Runs checks **in parallel** across all domains using `xargs -P "$(nproc)"`.

## Requirements

- **bash** 4+
- **curl** with:
  - TLS 1.2/1.3 support
  - HTTP/2 support
  - HTTP/3/QUIC support (for the QUIC column). If curl lacks HTTP/3 support, QUIC checks will fail and show `N`.
- **GNU coreutils**: `xargs`, `printf`, `nproc`
- **awk**, **sed**, **grep**

> Note: On macOS you may need to install `coreutils` (for `nproc`) and a curl build with HTTP/3 (e.g., via Homebrew).

## Quick start

1. Put your domains (one per line) into `domains.txt`:
