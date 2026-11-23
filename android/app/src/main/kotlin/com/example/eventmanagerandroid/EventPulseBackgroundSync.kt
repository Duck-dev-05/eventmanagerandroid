package com.example.eventmanagerandroid

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.ListenableWorker.Result
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import org.json.JSONObject

internal object EventPulseBackgroundSync {
    private const val WORK_NAME = "eventpulse-background-sync"

    private fun origin(context: Context): String =
        context.getString(R.string.eventpulse_origin).trimEnd('/')

    /** True when the stored session token still matches the one this run used. */
    private fun isSessionTokenCurrent(context: Context, token: String): Boolean = try {
        EventPulseCrypto.read(context, "device-token") == token
    } catch (_: Exception) {
        false
    }

    fun schedule(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<EventPulseSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    internal fun run(context: Context): Result {
        val token = try {
            EventPulseCrypto.read(context, "device-token")
        } catch (_: Exception) {
            return Result.failure()
        } ?: return Result.success()
        val deviceId = try {
            EventPulseCrypto.read(context, "device-id")
        } catch (_: Exception) {
            return Result.failure()
        } ?: return Result.success()
        val cursorValue = try {
            EventPulseCrypto.read(context, "sync-cursor")
        } catch (_: Exception) {
            null
        }
        val cursor = cursorValue?.toLongOrNull() ?: 0L

        val connection = try {
            (URL("${origin(context)}/api/sync/pull").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 20000
                doOutput = true
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("X-Device-Id", deviceId)
                outputStream.use { it.write(JSONObject().put("cursor", cursor).toString().toByteArray(Charsets.UTF_8)) }
            }
        } catch (_: Exception) {
            return Result.retry()
        }

        return try {
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (code == 401) {
                EventPulseBackgroundSync.cancel(context)
                return Result.failure()
            }
            if (code !in 200..299) return Result.retry()

            val result = JSONObject(body)

            if (result.optString("mode") == "snapshot") {
                EventPulseCrypto.delete(context, "background-sync-batch")
            }
            val workConnection = (URL("${origin(context)}/api/sync/work").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 20000
                doOutput = true
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("X-Device-Id", deviceId)
                outputStream.use { it.write(JSONObject().put("action", "pull").toString().toByteArray(Charsets.UTF_8)) }
            }
            try {
                if (workConnection.responseCode in 200..299) {
                    val workBody = workConnection.inputStream.bufferedReader().use { it.readText() }
                    if (!isSessionTokenCurrent(context, token)) {
                        // The user signed out or switched accounts while this run was
                        // in flight. Discard everything so a new sign-in starts clean.
                        return Result.success()
                    }
                    EventPulseCrypto.write(context, "background-work-batch", workBody)
                } else if (workConnection.responseCode == 401) {
                    EventPulseBackgroundSync.cancel(context)
                    return Result.failure()
                } else {
                    return Result.retry()
                }
            } finally {
                workConnection.disconnect()
            }

            val cachedText = try {
                EventPulseCrypto.read(context, "background-sync-batch")
            } catch (_: Exception) {
                null
            }
            val combined = combineBatches(cachedText, result)
            if (!isSessionTokenCurrent(context, token)) {
                return Result.success()
            }
            EventPulseCrypto.write(context, "background-sync-batch", combined.toString())
            EventPulseCrypto.write(context, "sync-cursor", result.optLong("cursor", cursor).toString())
            EventPulseNotifications.notifyNew(context, result.optJSONArray("notifications"))
            Result.success()
        } catch (_: Exception) {
            Result.retry()
        } finally {
            connection.disconnect()
        }
    }
}

private fun combineBatches(cachedText: String?, latest: JSONObject): JSONObject {
    if (cachedText.isNullOrEmpty()) return latest
    return try {
        val cached = JSONObject(cachedText)
        val latestIsSnapshot = latest.optString("mode") == "snapshot"
        val cachedIsSnapshot = cached.optString("mode") == "snapshot"
        if (latestIsSnapshot) return latest

        if (cachedIsSnapshot) {
            val events = cached.optJSONArray("events") ?: org.json.JSONArray()
            val changes = latest.optJSONArray("changes") ?: org.json.JSONArray()
            for (index in 0 until changes.length()) {
                val change = changes.optJSONObject(index) ?: continue
                val id = change.optString("entityId")
                val existingIndex = (0 until events.length()).firstOrNull { eventIndex ->
                    events.optJSONObject(eventIndex)?.optString("id") == id
                }
                if (change.optString("action") == "delete") {
                    if (existingIndex != null) events.remove(existingIndex)
                } else {
                    val event = change.optJSONObject("event") ?: continue
                    if (existingIndex == null) events.put(event) else events.put(existingIndex, event)
                }
            }
            latest.put("mode", "snapshot")
            latest.put("events", events)
            latest.put("changes", org.json.JSONArray())
            return latest
        }

        val combinedChanges = cached.optJSONArray("changes") ?: org.json.JSONArray()
        val newChanges = latest.optJSONArray("changes") ?: org.json.JSONArray()
        for (index in 0 until newChanges.length()) combinedChanges.put(newChanges.get(index))
        latest.put("changes", combinedChanges)
        latest
    } catch (_: Exception) {
        latest
    }
}

internal class EventPulseSyncWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = EventPulseBackgroundSync.run(applicationContext)
}
