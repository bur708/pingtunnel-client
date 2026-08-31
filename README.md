# Pingtunnel Client

A simple, cross-platform client for the pingtunnel proxy/VPN.

It lets you:
- Manage multiple connections from one place.
- Connect in Proxy or VPN mode.
- Use optional encryption for the tunnel.
- Protect the tunnel against packet loss on lossy links (satellite,
  airport wifi) with optional FEC or KCP.

## Install

Prebuilt packages for all platforms are on the [Releases page](https://github.com/bur708/pingtunnel-client/releases).

### Android (APK)
1. Download the APK from Releases.
2. Install it on your device (allow "install from unknown sources" if prompted - this build isn't signed with a Play Store key).

### Debian/Ubuntu (.deb)
```bash
sudo apt install ./pingtunnel-client_*.deb
```

If you used `dpkg -i`, fix dependencies with:
```bash
sudo apt -f install
```

### RPM-based distros (.rpm)
```bash
sudo rpm -i pingtunnel-client-*.rpm
```

## Versioning

- Keep `app/pubspec.yaml` `version:` as the human release version and bump it manually (for example `0.6.0+1`) in a release commit.
- CI sets `--build-number` from `GITHUB_RUN_NUMBER` for monotonic Android `versionCode`.
- On tag builds, CI sets `--build-name` from the tag (`vX.Y.Z` or `X.Y.Z`).
- Release tags should follow semantic versioning so app version metadata stays predictable.

## Requirements (Linux)

- `policykit-1` is required for VPN mode (route/TUN changes).
- For top-bar tray controls, install `libayatana-appindicator3-1` (or `libappindicator3-1`).
- Your system may show an authorization prompt when enabling VPN mode.

## Usage

1. Open the app.
2. Paste a connection URI to add it to the list.
3. Select a connection.
4. Tap **Connect** to start.
5. Tap **Test Tunnel** to verify.
6. On Linux, closing the window keeps the app running in the top bar menu.

Sample URI:
```
pingtunnel://example.com?key=123456&mode=proxy&lport=1080
```

Encrypted sample URI:
```
pingtunnel://example.com?encrypt=aes256&encrypt_key=encryption-key-here&mode=proxy&lport=1080
```

Sample URI with FEC (server must use the same `-fec-data`/`-fec-parity`):
```
pingtunnel://example.com?key=123456&mode=proxy&lport=1080&reliability=fec&fec_data=10&fec_parity=3
```

Sample URI with KCP (server must also enable `-kcp`):
```
pingtunnel://example.com?key=123456&mode=proxy&lport=1080&reliability=kcp
```

### Proxy vs VPN
- **Proxy**: only apps using the local SOCKS proxy are tunneled.
- **VPN**: routes system traffic through the tunnel.

In Proxy mode (Android and desktop), the client exposes one mixed local proxy port:
- SOCKS5 and HTTP on `127.0.0.1:<local port>`

### Encryption
- If **Encryption** is **Off**: provide the **Key**.
- If **Encryption** is **On**: provide the **Encrypt Key**.

### Reliability (FEC / KCP)
- **None**: default, matches plain pingtunnel behavior.
- **FEC**: Reed-Solomon erasure coding recovers moderate, bursty packet
  loss with no added latency; set **data shards** / **parity shards**
  to match the server (defaults 10/3 tolerate losing up to 3 packets
  per block of 13).
- **KCP**: a full ARQ (automatic repeat request) transport; degrades
  throughput under sustained loss instead of stalling, at the cost of
  more background traffic than FEC.
- FEC and KCP are alternatives, not combinable, and both sides of a
  tunnel must pick the same one (or neither).

## Troubleshooting

- **VPN mode fails on Linux**: ensure `policykit-1` is installed, and allow the authorization prompt.
- **No traffic in VPN mode**: confirm the connection is selected and the tunnel is connected before testing.
