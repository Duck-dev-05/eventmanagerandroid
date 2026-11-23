package com.example.eventmanagerandroid

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val STORAGE_CHANNEL = "eventpulse/secure_storage"
        private const val NOTIFICATIONS_CHANNEL = "eventpulse/notifications"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "read" -> {
                            val key = call.argument<String>("key")
                            result.success(if (key == null) null else EventPulseCrypto.read(this, key))
                        }
                        "write" -> {
                            val key = call.argument<String>("key")
                            val value = call.argument<String>("value")
                            if (key == null || value == null) {
                                result.error("invalid_arguments", "A storage key and value are required.", null)
                            } else {
                                EventPulseCrypto.write(this, key, value)
                                if (key == "device-id") EventPulseBackgroundSync.schedule(this)
                                result.success(null)
                            }
                        }
                        "schedule-background-sync" -> {
                            EventPulseBackgroundSync.schedule(this)
                            result.success(null)
                        }
                        "delete" -> {
                            val key = call.argument<String>("key")
                            if (key == null) {
                                result.error("invalid_arguments", "A storage key is required.", null)
                            } else {
                                EventPulseCrypto.delete(this, key)
                                result.success(null)
                            }
                        }
                        "clear" -> {
                            EventPulseCrypto.preferences(this).edit().clear().apply()
                            EventPulseBackgroundSync.cancel(this)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("secure_storage_error", "Could not access secure sign-in storage.", error.message)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "requestPermission" -> {
                            EventPulseNotifications.requestPermission(this)
                            result.success(null)
                        }
                        "notifyNew" -> {
                            val notifications =
                                call.argument<List<Map<String, Any?>>>("notifications") ?: emptyList()
                            EventPulseNotifications.notifyNew(this, notifications)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "notification_error",
                        "Could not update EventPulse notifications.",
                        error.message,
                    )
                }
            }
    }

}
