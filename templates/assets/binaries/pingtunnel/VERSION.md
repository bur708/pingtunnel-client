# Bundled pingtunnel binaries

The `android-arm64` and `linux-amd64` binaries in this directory are
built from https://github.com/bur708/pingtunnel (a fork of
esrrhs/pingtunnel), commit `1bc4747c07b081cc5bd8926bb861cacfba42788b`.

That commit includes fixes from a security review: a SOCKS5
authentication-bypass fix, CRLF/HTTP request-injection validation on
forward-proxy target addresses, a much higher PBKDF2 iteration count
for passphrase-derived encryption keys, and HMAC-SHA256 authentication
of KCP segments (previously unauthenticated, letting an off-path
attacker forge ACKs into an established session's retransmit state).

It also adds an adaptive server mode (server auto-matches each client's
own -fec/-kcp/plain choice per connection when neither flag is pinned
on the server) and raises the tcpmode connect-handshake timeout default
from 5s to 15s (configurable via -connect-timeout) - the old 5s value
was too tight when many connections open at once over the tunnel (e.g.
a system-wide proxy client routing all apps' traffic), causing
"can not connect remote tcp" even though the underlying dial succeeded.

That fork adds two optional, independent reliability layers on top of
the standard pingtunnel ICMP tunnel protocol, both off by default and
byte-for-byte compatible with plain pingtunnel when disabled:

- `-fec` / `-fec-data` / `-fec-parity`: Reed-Solomon block erasure
  coding (github.com/klauspost/reedsolomon) applied per ICMP packet.
- `-kcp`: reliable ARQ transport built on the low-level engine from
  github.com/xtaci/kcp-go. Cannot be combined with `-fec` in this
  version - the two are alternative reliability layers, not composed.

Both sides of a tunnel must agree on which (if either) is enabled; a
mismatch is logged and the offending packets are dropped rather than
crashing.

Build command used for android-arm64:

```
GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o pingtunnel ./cmd/
```

(linux-amd64 built the same way with GOOS=linux GOARCH=amd64.)

darwin-amd64, darwin-arm64, windows-amd64 and windows-arm64 in sibling
directories are unrelated, older builds from the original app
maintainer and have not been rebuilt from this fork.
