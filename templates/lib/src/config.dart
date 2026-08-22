enum TunnelMode { proxy, vpn, proxyPerApp }

/// The pingtunnel binary's two reliability layers are alternatives, not
/// composable: -kcp and -fec cannot both be passed on the same
/// invocation. `none` matches today's default (plain resend logic only).
enum ReliabilityMode { none, fec, kcp }

class TunnelConfig {
  TunnelConfig({
    required this.serverHost,
    this.serverPort,
    required this.localSocksPort,
    this.key,
    required this.mode,
    this.encryptMode,
    this.encryptKey,
    this.interfaceName,
    this.tunDevice,
    this.dns,
    this.proxyPerAppPackages = const <String>[],
    this.reliabilityMode = ReliabilityMode.none,
    this.fecDataShards = 10,
    this.fecParityShards = 3,
  });

  final String serverHost;
  final int? serverPort;
  final int localSocksPort;
  final int? key;
  final TunnelMode mode;
  final String? encryptMode;
  final String? encryptKey;
  final String? interfaceName;
  final String? tunDevice;
  final String? dns;
  final List<String> proxyPerAppPackages;
  final ReliabilityMode reliabilityMode;
  final int fecDataShards;
  final int fecParityShards;

  TunnelConfig copyWith({
    String? serverHost,
    int? serverPort,
    int? localSocksPort,
    int? key,
    TunnelMode? mode,
    String? encryptMode,
    String? encryptKey,
    String? interfaceName,
    String? tunDevice,
    String? dns,
    List<String>? proxyPerAppPackages,
    ReliabilityMode? reliabilityMode,
    int? fecDataShards,
    int? fecParityShards,
  }) {
    return TunnelConfig(
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      localSocksPort: localSocksPort ?? this.localSocksPort,
      key: key ?? this.key,
      mode: mode ?? this.mode,
      encryptMode: encryptMode ?? this.encryptMode,
      encryptKey: encryptKey ?? this.encryptKey,
      interfaceName: interfaceName ?? this.interfaceName,
      tunDevice: tunDevice ?? this.tunDevice,
      dns: dns ?? this.dns,
      proxyPerAppPackages: proxyPerAppPackages != null
          ? List<String>.from(proxyPerAppPackages)
          : this.proxyPerAppPackages,
      reliabilityMode: reliabilityMode ?? this.reliabilityMode,
      fecDataShards: fecDataShards ?? this.fecDataShards,
      fecParityShards: fecParityShards ?? this.fecParityShards,
    );
  }

  String serverAddress() {
    if (serverPort == null) {
      return serverHost;
    }
    return "$serverHost:$serverPort";
  }

  int localProxyBackendSocksPort() {
    if (localSocksPort < 1 || localSocksPort > 65535) {
      return 1081;
    }
    if (localSocksPort == 65535) {
      return 65534;
    }
    return localSocksPort + 1;
  }

  Map<String, Object?> toMap() {
    return {
      'serverHost': serverHost,
      'serverPort': serverPort,
      'localSocksPort': localSocksPort,
      'key': key,
      'mode': switch (mode) {
        TunnelMode.proxy => 'proxy',
        TunnelMode.vpn => 'vpn',
        TunnelMode.proxyPerApp => 'proxy_per_app',
      },
      'encryptMode': encryptMode,
      'encryptKey': encryptKey,
      'interfaceName': interfaceName,
      'tunDevice': tunDevice,
      'dns': dns,
      'proxyPerAppPackages': proxyPerAppPackages,
      'reliabilityMode': switch (reliabilityMode) {
        ReliabilityMode.none => 'none',
        ReliabilityMode.fec => 'fec',
        ReliabilityMode.kcp => 'kcp',
      },
      'fecDataShards': fecDataShards,
      'fecParityShards': fecParityShards,
    };
  }

  static TunnelConfig parse(String uriText) {
    final uri = Uri.parse(uriText.trim());
    if (uri.scheme != 'pingtunnel') {
      throw const FormatException('URI scheme must be pingtunnel://');
    }

    String host = uri.host;
    if (host.isEmpty) {
      host = uri.path;
    }
    if (host.isEmpty) {
      throw const FormatException('Missing server host');
    }

    final params = uri.queryParameters;
    final keyText = params['key'] ?? '';
    final key = keyText.isEmpty ? null : int.tryParse(keyText);

    final localPort =
        int.tryParse(params['lport'] ?? params['local_port'] ?? '') ?? 1080;
    final serverPort = int.tryParse(
      params['port'] ?? params['server_port'] ?? '',
    );

    final modeValue = (params['mode'] ?? params['vpn'] ?? 'proxy')
        .toLowerCase();
    final mode = switch (modeValue) {
      'vpn' || '1' => TunnelMode.vpn,
      'proxy_per_app' ||
      'proxy-per-app' ||
      'per_app' ||
      'app' ||
      'app_proxy' => TunnelMode.proxyPerApp,
      _ => TunnelMode.proxy,
    };
    final proxyPerAppPackages =
        (params['apps'] ?? '')
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final encryptValue =
        (params['encrypt'] ??
                params['encrypt_mode'] ??
                params['encryptMode'] ??
                params['enc'] ??
                '')
            .toLowerCase();
    final validEncryptModes = {'aes128', 'aes256', 'chacha20'};
    final encryptMode =
        encryptValue.isEmpty ||
            encryptValue == '0' ||
            encryptValue == 'none' ||
            !validEncryptModes.contains(encryptValue)
        ? null
        : encryptValue;
    final encryptKey =
        params['encrypt-key'] ?? params['encrypt_key'] ?? params['encryptKey'];

    if (encryptMode == null && key == null) {
      throw const FormatException('Missing key');
    }
    if (encryptMode != null && (encryptKey == null || encryptKey.isEmpty)) {
      throw const FormatException('Missing encrypt_key');
    }
    if (keyText.isNotEmpty && key == null) {
      throw const FormatException('Key must be an integer');
    }

    final reliabilityValue = (params['reliability'] ?? params['kcp'] ?? '')
        .toLowerCase();
    final reliabilityMode = switch (reliabilityValue) {
      'fec' => ReliabilityMode.fec,
      'kcp' || '1' => ReliabilityMode.kcp,
      _ => ReliabilityMode.none,
    };
    final fecDataShards =
        int.tryParse(params['fec_data'] ?? params['fec-data'] ?? '') ?? 10;
    final fecParityShards =
        int.tryParse(params['fec_parity'] ?? params['fec-parity'] ?? '') ?? 3;
    if (reliabilityMode == ReliabilityMode.fec &&
        (fecDataShards < 1 || fecParityShards < 1)) {
      throw const FormatException(
        'fec_data and fec_parity must be positive integers',
      );
    }

    final interfaceName = _validateIfaceName(
      params['iface'] ?? params['interface'],
      'iface',
    );
    final tunDevice = _validateIfaceName(
      params['tun'] ?? params['tun_device'],
      'tun',
    );
    final dns = _validateDns(params['dns']);

    return TunnelConfig(
      serverHost: host,
      serverPort: serverPort,
      localSocksPort: localPort,
      key: key,
      mode: mode,
      encryptMode: encryptMode,
      encryptKey: encryptKey,
      interfaceName: interfaceName,
      tunDevice: tunDevice,
      dns: dns,
      proxyPerAppPackages: proxyPerAppPackages,
      reliabilityMode: reliabilityMode,
      fecDataShards: fecDataShards,
      fecParityShards: fecParityShards,
    );
  }

  // interfaceName/tunDevice/dns all flow, unmodified, as argv/script
  // parameters into privileged code paths: a pkexec'd root shell script on
  // Linux (vpn_up.sh, which unquoted-expands DNS_SERVERS on purpose so
  // resolvectl sees one argument per address) and a PowerShell script on
  // Windows (vpn_up.ps1, netsh). A `pingtunnel://` URI is untrusted input
  // (pasted, imported, or deep-linked), so reject anything outside a safe
  // character set here rather than relying on the scripts to quote
  // correctly - this closes off argument injection into those privileged
  // commands regardless of how the scripts end up handling the value.
  static final _ifaceNamePattern = RegExp(r'^[A-Za-z0-9_.:-]{1,15}$');
  static final _dnsListPattern = RegExp(r'^[0-9a-fA-F.:]+(,\s*[0-9a-fA-F.:]+)*$');

  static String? _validateIfaceName(String? value, String fieldName) {
    if (value == null || value.isEmpty) return value;
    if (!_ifaceNamePattern.hasMatch(value)) {
      throw FormatException('Invalid $fieldName: $value');
    }
    return value;
  }

  static String? _validateDns(String? value) {
    if (value == null || value.isEmpty) return value;
    if (!_dnsListPattern.hasMatch(value)) {
      throw FormatException('Invalid dns: $value');
    }
    return value;
  }
}
