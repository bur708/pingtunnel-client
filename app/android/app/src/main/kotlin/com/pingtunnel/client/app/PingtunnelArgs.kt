package com.pingtunnel.client.app

fun buildPingtunnelArgs(
    binPath: String,
    config: TunnelConfig,
    localSocksPort: Int = config.localSocksPort
): List<String> {
    val args = mutableListOf(
        binPath,
        "-type",
        "client",
        "-l",
        "127.0.0.1:$localSocksPort",
        "-s",
        config.serverAddress(),
        "-sock5",
        "1"
    )

    if (!config.encryptMode.isNullOrBlank()) {
        args.add("-encrypt")
        args.add(config.encryptMode!!)
        if (config.encryptKey.isNullOrBlank()) {
            throw IllegalArgumentException("encrypt key missing")
        }
        args.add("-encrypt-key")
        args.add(config.encryptKey!!)
    } else {
        val key = config.key ?: throw IllegalArgumentException("key missing")
        args.add("-key")
        args.add(key.toString())
    }

    when (config.reliabilityMode) {
        "fec" -> {
            args.add("-fec")
            args.add("-fec-data")
            args.add(config.fecDataShards.toString())
            args.add("-fec-parity")
            args.add(config.fecParityShards.toString())
        }
        "kcp" -> args.add("-kcp")
    }

    return args
}
