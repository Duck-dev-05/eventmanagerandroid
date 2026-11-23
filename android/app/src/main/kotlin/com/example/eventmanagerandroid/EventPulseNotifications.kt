package com.example.eventmanagerandroid

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.util.LinkedHashSet
import org.json.JSONArray
import org.json.JSONObject

/**
 * Posts Android notifications for EventPulse sync items.
 *
 * Foreground polling and the WorkManager sync worker both call this object.
 * Seen notification ids are stored in the encrypted preferences so the same
 * item is never posted twice, and the first sync only seeds the list instead
 * of dumping every existing notification on the user.
 */
internal object EventPulseNotifications {
    private const val CHANNEL_ID = "eventpulse_updates"
    private const val CHANNEL_NAME = "EventPulse updates"
    private const val SEEN_KEY = "notification-seen-ids"
    private const val MAX_SEEN = 200
    private const val MAX_POPUPS = 5
    private const val PERMISSION_REQUEST = 4201

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Invitations, reminders and changes across your events."
            enableVibration(true)
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    fun requestPermission(activity: Activity) {
        ensureChannel(activity)
        if (Build.VERSION.SDK_INT < 33) return
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST,
        )
    }

    fun notifyNew(context: Context, items: List<Map<String, Any?>>) {
        val array = JSONArray()
        for (item in items) array.put(JSONObject(item))
        notifyNew(context, array)
    }

    fun notifyNew(context: Context, items: JSONArray?) {
        try {
            ensureChannel(context)
            if (!canPost(context)) return

            val rawSeen = try {
                EventPulseCrypto.read(context, SEEN_KEY)
            } catch (_: Exception) {
                null
            }
            val seen = parseSeen(rawSeen)
            val firstRun = rawSeen.isNullOrBlank()
            var posted = 0

            if (items != null) {
                for (index in 0 until items.length()) {
                    val item = items.optJSONObject(index) ?: continue
                    val id = item.optString("id").trim()
                    if (id.isEmpty()) continue
                    val isNew = seen.add(id)
                    if (firstRun || !isNew || !item.isNull("readAt")) continue
                    if (posted >= MAX_POPUPS) continue
                    post(context, id, item)
                    posted++
                }
            }

            if (firstRun || posted > 0) writeSeen(context, seen)
        } catch (_: Exception) {
            // A notification failure must never break event or work sync.
        }
    }

    private fun canPost(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.areNotificationsEnabled()
    }

    private fun parseSeen(raw: String?): LinkedHashSet<String> {
        val seen = LinkedHashSet<String>()
        if (raw.isNullOrBlank()) return seen
        try {
            val array = JSONArray(raw)
            for (index in 0 until array.length()) {
                val id = array.optString(index).trim()
                if (id.isNotEmpty()) seen.add(id)
            }
        } catch (_: Exception) {
            // Treat an unreadable cache as empty and let the next sync reseed it.
        }
        return seen
    }

    private fun writeSeen(context: Context, seen: LinkedHashSet<String>) {
        val ids = if (seen.size <= MAX_SEEN) seen.toList() else seen.toList().takeLast(MAX_SEEN)
        val array = JSONArray()
        for (id in ids) array.put(id)
        EventPulseCrypto.write(context, SEEN_KEY, array.toString())
    }

    private fun post(context: Context, id: String, item: JSONObject) {
        val title = item.optString("title").trim().ifEmpty { "EventPulse" }
        val message = item.optString("message").trim()
            .ifEmpty { "You have a new EventPulse notification." }
        val notificationId = notificationId(id)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("eventpulse_event_id", item.optString("eventId"))
            putExtra("eventpulse_notification_id", id)
            val linkUrl = item.optString("linkUrl")
            if (linkUrl.isNotEmpty()) putExtra("eventpulse_link_url", linkUrl)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_eventpulse)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setCategory(Notification.CATEGORY_SOCIAL)
            .setPriority(Notification.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_ALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setChannelId(CHANNEL_ID)
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, builder.build())
    }

    private fun notificationId(id: String): Int {
        val value = id.hashCode() and 0x7fffffff
        return if (value == 0) 1 else value
    }
}
