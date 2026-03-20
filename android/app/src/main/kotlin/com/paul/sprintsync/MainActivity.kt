package com.paul.sprintsync

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.ConnectionsStatusCodes
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity(), ActivityCompat.OnRequestPermissionsResultCallback {
    companion object {
        private const val METHOD_CHANNEL_NAME = "com.paul.sprintsync/nearby_methods"
        private const val EVENT_CHANNEL_NAME = "com.paul.sprintsync/nearby_events"
        private const val PERMISSIONS_REQUEST_CODE = 7301
        private val STRATEGY = Strategy.P2P_STAR
    }

    private val connectedEndpointIds = mutableSetOf<String>()
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var connectionsClient: ConnectionsClient
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectionsClient = Nearby.getConnectionsClient(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL_NAME,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermissions" -> requestPermissions(result)
            "startHosting" -> {
                val serviceId = stringArg(call, "serviceId", result) ?: return
                val endpointName = stringArg(call, "endpointName", result) ?: return
                startHosting(serviceId, endpointName, result)
            }

            "stopHosting" -> {
                connectionsClient.stopAdvertising()
                result.success(null)
            }

            "startDiscovery" -> {
                val serviceId = stringArg(call, "serviceId", result) ?: return
                startDiscovery(serviceId, result)
            }

            "stopDiscovery" -> {
                connectionsClient.stopDiscovery()
                result.success(null)
            }

            "requestConnection" -> {
                val endpointId = stringArg(call, "endpointId", result) ?: return
                val endpointName = stringArg(call, "endpointName", result) ?: return
                requestConnection(endpointId, endpointName, result)
            }

            "sendBytes" -> {
                val endpointId = stringArg(call, "endpointId", result) ?: return
                val messageJson = stringArg(call, "messageJson", result) ?: return
                sendBytes(endpointId, messageJson, result)
            }

            "disconnect" -> {
                val endpointId = stringArg(call, "endpointId", result) ?: return
                disconnect(endpointId)
                result.success(null)
            }

            "stopAll" -> {
                stopAll()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun stringArg(
        call: MethodCall,
        key: String,
        result: MethodChannel.Result,
    ): String? {
        val value = call.argument<String>(key)
        if (value.isNullOrBlank()) {
            result.error("bad_args", "Missing required argument '$key'.", null)
            return null
        }
        return value
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("permissions_in_flight", "A permission request is already running.", null)
            return
        }
        val denied = deniedPermissions()
        if (denied.isEmpty()) {
            result.success(
                mapOf(
                    "granted" to true,
                    "denied" to emptyList<String>(),
                ),
            )
            emitEvent(
                mapOf(
                    "type" to "permission_status",
                    "granted" to true,
                    "denied" to emptyList<String>(),
                ),
            )
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            denied.toTypedArray(),
            PERMISSIONS_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSIONS_REQUEST_CODE) {
            return
        }

        val callback = pendingPermissionResult ?: return
        pendingPermissionResult = null
        val denied = deniedPermissions()
        val granted = denied.isEmpty()
        val payload = mapOf(
            "granted" to granted,
            "denied" to denied,
        )
        callback.success(payload)
        emitEvent(
            mapOf(
                "type" to "permission_status",
                "granted" to granted,
                "denied" to denied,
            ),
        )
    }

    private fun startHosting(
        serviceId: String,
        endpointName: String,
        result: MethodChannel.Result,
    ) {
        val options = AdvertisingOptions.Builder()
            .setStrategy(STRATEGY)
            .build()
        connectionsClient
            .startAdvertising(endpointName, serviceId, connectionLifecycleCallback, options)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { error ->
                emitError("startHosting failed: ${error.localizedMessage ?: "unknown"}")
                result.error("start_hosting_failed", error.localizedMessage, null)
            }
    }

    private fun startDiscovery(
        serviceId: String,
        result: MethodChannel.Result,
    ) {
        val options = DiscoveryOptions.Builder()
            .setStrategy(STRATEGY)
            .build()
        connectionsClient
            .startDiscovery(serviceId, endpointDiscoveryCallback, options)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { error ->
                emitError("startDiscovery failed: ${error.localizedMessage ?: "unknown"}")
                result.error("start_discovery_failed", error.localizedMessage, null)
            }
    }

    private fun requestConnection(
        endpointId: String,
        endpointName: String,
        result: MethodChannel.Result,
    ) {
        connectionsClient
            .requestConnection(endpointName, endpointId, connectionLifecycleCallback)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { error ->
                emitError("requestConnection failed: ${error.localizedMessage ?: "unknown"}")
                result.error("request_connection_failed", error.localizedMessage, null)
            }
    }

    private fun sendBytes(
        endpointId: String,
        messageJson: String,
        result: MethodChannel.Result,
    ) {
        val payload = Payload.fromBytes(messageJson.toByteArray(StandardCharsets.UTF_8))
        connectionsClient
            .sendPayload(endpointId, payload)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { error ->
                emitError("sendBytes failed: ${error.localizedMessage ?: "unknown"}")
                result.error("send_payload_failed", error.localizedMessage, null)
            }
    }

    private fun disconnect(endpointId: String) {
        connectionsClient.disconnectFromEndpoint(endpointId)
        connectedEndpointIds.remove(endpointId)
        emitEvent(
            mapOf(
                "type" to "endpoint_disconnected",
                "endpointId" to endpointId,
            ),
        )
    }

    private fun stopAll() {
        connectionsClient.stopAdvertising()
        connectionsClient.stopDiscovery()
        connectionsClient.stopAllEndpoints()
        connectedEndpointIds.clear()
    }

    private fun deniedPermissions(): List<String> {
        return requiredPermissions()
            .filter { permission ->
                ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
            }
    }

    private fun requiredPermissions(): List<String> {
        val permissions = mutableListOf(Manifest.permission.CAMERA)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
        } else {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        return permissions
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: com.google.android.gms.nearby.connection.DiscoveredEndpointInfo) {
            emitEvent(
                mapOf(
                    "type" to "endpoint_found",
                    "endpointId" to endpointId,
                    "endpointName" to info.endpointName,
                    "serviceId" to info.serviceId,
                ),
            )
        }

        override fun onEndpointLost(endpointId: String) {
            emitEvent(
                mapOf(
                    "type" to "endpoint_lost",
                    "endpointId" to endpointId,
                ),
            )
        }
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            // Auto-accept for local open sessions in v1.
            connectionsClient
                .acceptConnection(endpointId, payloadCallback)
                .addOnFailureListener { error ->
                    emitError("acceptConnection failed: ${error.localizedMessage ?: "unknown"}")
                    emitEvent(
                        mapOf(
                            "type" to "connection_result",
                            "endpointId" to endpointId,
                            "connected" to false,
                        ),
                    )
                }
        }

        override fun onConnectionResult(
            endpointId: String,
            resolution: ConnectionResolution,
        ) {
            val isConnected = resolution.status.statusCode == ConnectionsStatusCodes.STATUS_OK
            if (isConnected) {
                connectedEndpointIds.add(endpointId)
            } else {
                connectedEndpointIds.remove(endpointId)
            }
            emitEvent(
                mapOf(
                    "type" to "connection_result",
                    "endpointId" to endpointId,
                    "connected" to isConnected,
                    "statusCode" to resolution.status.statusCode,
                    "statusMessage" to resolution.status.statusMessage,
                ),
            )
        }

        override fun onDisconnected(endpointId: String) {
            connectedEndpointIds.remove(endpointId)
            emitEvent(
                mapOf(
                    "type" to "endpoint_disconnected",
                    "endpointId" to endpointId,
                ),
            )
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            val bytes = payload.asBytes() ?: return
            val message = String(bytes, StandardCharsets.UTF_8)
            emitEvent(
                mapOf(
                    "type" to "payload_received",
                    "endpointId" to endpointId,
                    "message" to message,
                ),
            )
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // Byte payloads are handled in onPayloadReceived; transfer progress is not needed for v1.
        }
    }

    private fun emitError(message: String) {
        emitEvent(
            mapOf(
                "type" to "error",
                "message" to message,
            ),
        )
    }

    private fun emitEvent(event: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post {
            sink.success(event)
        }
    }
}
