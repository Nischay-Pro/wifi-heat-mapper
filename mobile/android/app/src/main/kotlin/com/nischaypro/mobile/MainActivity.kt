package com.nischaypro.mobile

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.net.SocketException
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val wifiMetadataChannelName = "wifi_metadata"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            wifiMetadataChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> result.success(loadWifiMetadata())
                else -> result.notImplemented()
            }
        }
    }

    private fun loadWifiMetadata(): Map<String, Any?> {
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val connectivityManager =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
        val isWifiTransport =
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true

        if (!wifiManager.isWifiEnabled) {
            return mapOf(
                "platform" to "android",
                "status" to "wifi_disabled",
            )
        }

        if (!isWifiTransport) {
            return mapOf(
                "platform" to "android",
                "status" to "wifi_not_connected",
            )
        }

        if (!hasWifiAccessPermissions()) {
            return mapOf(
                "platform" to "android",
                "status" to "permissions_missing",
            )
        }

        @Suppress("DEPRECATION")
        val wifiInfo = wifiManager.connectionInfo ?: return mapOf(
            "platform" to "android",
            "status" to "unavailable",
        )

        val rawSsid = wifiInfo.ssid?.trim()?.removePrefix("\"")?.removeSuffix("\"")
        val ssid = rawSsid?.takeUnless { it.equals("<unknown ssid>", ignoreCase = true) }
        val rawBssid: String? = wifiInfo.bssid
        val bssid = rawBssid?.takeUnless { value ->
            value.equals("02:00:00:00:00:00", ignoreCase = true)
        }
        val frequencyMhz = if (wifiInfo.frequency > 0) wifiInfo.frequency else null
        val rssi = if (wifiInfo.rssi != Int.MIN_VALUE) wifiInfo.rssi else null
        val signalPercent = rssi?.let(::calculateSignalPercent)
        val signalQuality = signalPercent?.roundToInt()

        return mapOf(
            "platform" to "android",
            "status" to "available",
            "ssid" to ssid,
            "bssid" to bssid,
            "rssi" to rssi,
            "signal_strength" to rssi,
            "signal_quality" to signalQuality,
            "signal_quality_percent" to signalPercent,
            "frequency_mhz" to frequencyMhz,
            "channel_frequency" to frequencyMhz,
            "channel" to frequencyMhz?.let(::channelFromFrequency),
            "client_ip" to wifiInfo.ipAddress
                .takeIf { value -> value != 0 }
                ?.let { value -> toIpv4Address(value) },
            "interface_name" to findWifiInterfaceName(),
        )
    }

    private fun hasWifiAccessPermissions(): Boolean {
        val hasLocationPermission =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED

        val hasNearbyWifiPermission =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.NEARBY_WIFI_DEVICES,
                ) == PackageManager.PERMISSION_GRANTED

        return hasLocationPermission && hasNearbyWifiPermission
    }

    private fun calculateSignalPercent(rssi: Int): Double {
        @Suppress("DEPRECATION")
        val level = WifiManager.calculateSignalLevel(rssi, 101)
        return level.toDouble()
    }

    private fun channelFromFrequency(frequencyMhz: Int): Int? {
        return when {
            frequencyMhz == 2484 -> 14
            frequencyMhz in 2412..2472 -> (frequencyMhz - 2407) / 5
            frequencyMhz in 5000..5895 -> (frequencyMhz - 5000) / 5
            frequencyMhz in 5955..7115 -> ((frequencyMhz - 5955) / 5) + 1
            else -> null
        }
    }

    private fun toIpv4Address(address: Int): String {
        val octet1 = address and 0xff
        val octet2 = address shr 8 and 0xff
        val octet3 = address shr 16 and 0xff
        val octet4 = address shr 24 and 0xff
        return "$octet1.$octet2.$octet3.$octet4"
    }

    private fun findWifiInterfaceName(): String? {
        return try {
            NetworkInterface.getNetworkInterfaces()
                ?.toList()
                ?.firstOrNull { networkInterface ->
                    val name = networkInterface.name.lowercase()
                    !networkInterface.isLoopback &&
                        networkInterface.isUp &&
                        (name.startsWith("wlan") || name.startsWith("wifi"))
                }
                ?.name
        } catch (_: SocketException) {
            null
        }
    }
}
