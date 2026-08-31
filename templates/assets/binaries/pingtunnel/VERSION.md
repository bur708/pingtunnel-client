# Bundled pingtunnel binaries

The `android-arm64`, `linux-amd64`, `windows-amd64`, and `windows-arm64`
binaries in this directory are built from
https://github.com/bur708/pingtunnel (a fork of esrrhs/pingtunnel),
commit `1bcdd58` (2026-08-31).

That commit includes, among other fixes accumulated since the
`95dfbac` self-reflection fix originally noted here: the Android
ICMP-ident mismatch fix that made KCP mode work over real cellular/
Wi-Fi links, HMAC authentication for FEC packets, opt-in KCP
congestion control and tunable send/receive windows, and a set of
pre-release security fixes (removed a real DNS-query-domain logging
leak, stopped logging the tunnel key/passphrase in cleartext, and
moved the `-encrypt-key` passphrase to the `PINGTUNNEL_ENCRYPT_KEY`
environment variable instead of a CLI flag).

`darwin-amd64`/`darwin-arm64` are **not** rebuilt from this commit -
still from 2026-08-22 - since no macOS app build exists yet to bundle
them into (see the client repo's CI: no macOS job, `app/macos/` is
still just Flutter's default scaffold).

To rebuild: Linux/Windows are a plain
`GOOS=<os> GOARCH=<arch> CGO_ENABLED=0 go build ./cmd` from the
pingtunnel repo, no special toolchain needed. Android requires
`CGO_ENABLED=1` with the Android NDK's clang as the C compiler
(e.g. `aarch64-linux-android21-clang` for arm64).
