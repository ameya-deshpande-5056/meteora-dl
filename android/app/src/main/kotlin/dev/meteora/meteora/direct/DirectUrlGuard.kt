package dev.meteora.meteora.direct

import java.net.URI

/**
 * SSRF guard for the plain-HTTP transport.
 *
 * The downloader fetches whatever URL the Flutter layer hands it, so the native
 * side re-validates instead of trusting the caller: only http/https, no
 * loopback, no link-local/metadata endpoints, no unspecified address. Private
 * LAN ranges are allowed on purpose — pointing Meteora at a NAS on the same
 * network is a legitimate use, while loopback is where local services and cloud
 * metadata live.
 */
object DirectUrlGuard {

    fun validate(rawUrl: String): String? {
        val url = rawUrl.trim()
        if (url.isEmpty()) return "Download URL is empty"

        val uri = try {
            URI(url)
        } catch (_: Throwable) {
            return "Download URL is not a valid URI"
        }

        val scheme = uri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") {
            return "Only http and https downloads are supported (got ${scheme ?: "none"})"
        }

        val host = uri.host?.lowercase()
        if (host.isNullOrBlank()) return "Download URL has no host"

        if (host == "localhost" || host.endsWith(".localhost")) {
            return "Downloads from localhost are blocked"
        }
        if (host == "metadata.google.internal") {
            return "Downloads from link-local metadata endpoints are blocked"
        }

        if (isBlockedIpv4(host)) {
            return "Downloads from loopback or link-local addresses are blocked"
        }
        if (isBlockedIpv6(host)) {
            return "Downloads from loopback or link-local addresses are blocked"
        }

        return null
    }

    private fun isBlockedIpv4(host: String): Boolean {
        val parts = host.split('.')
        if (parts.size != 4) return false
        val octets = parts.map { it.toIntOrNull() ?: return false }
        if (octets.any { it < 0 || it > 255 }) return false
        val first = octets[0]
        val second = octets[1]
        return when {
            first == 0 -> true // 0.0.0.0/8 "this network"
            first == 127 -> true // loopback
            first == 169 && second == 254 -> true // link-local + cloud metadata
            else -> false
        }
    }

    private fun isBlockedIpv6(host: String): Boolean {
        val normalized = host.trim('[', ']').lowercase()
        if (normalized == "::1" || normalized == "::") return true
        if (normalized.startsWith("fe80:")) return true // link-local
        if (normalized.startsWith("fd00:ec2:")) return true // AWS metadata ULA
        return false
    }
}
