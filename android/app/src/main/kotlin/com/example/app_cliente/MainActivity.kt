package com.example.app_cliente

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.view.WindowCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var timerNotificationToken: Long = 0

    private fun handleWorkoutStartIntent(intent: Intent?, warmStart: Boolean = false) {
        if (intent?.action == "com.example.app_cliente.START_WORKOUT") {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putString("flutter.widget_start_workout_ts",
                System.currentTimeMillis().toString()).apply()
            // On warm start (onNewIntent), app is already running → signal Flutter directly
            if (warmStart) {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, "gym_file_reader").invokeMethod("startWorkout", null)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        handleWorkoutStartIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWorkoutStartIntent(intent, warmStart = true)
    }

    private fun timerFinishedPendingIntent(title: String = "", body: String = ""): PendingIntent {
        val intent = Intent(this, TimerFinishedReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
        }
        return PendingIntent.getBroadcast(
            this,
            1002,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleTimerFinishedNotification(delayMs: Long, title: String, body: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = timerFinishedPendingIntent(title, body)
        alarmManager.cancel(pendingIntent)
        val triggerAt = System.currentTimeMillis() + delayMs.coerceAtLeast(0L)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun cancelScheduledTimerFinishedNotification() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = timerFinishedPendingIntent()
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun streakReminderPendingIntent(title: String = "", body: String = ""): PendingIntent {
        val intent = Intent(this, StreakReminderReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
        }
        return PendingIntent.getBroadcast(
            this,
            1991,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleStreakReminderNotification(delayMs: Long, title: String, body: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = streakReminderPendingIntent(title, body)
        alarmManager.cancel(pendingIntent)
        val triggerAt = System.currentTimeMillis() + delayMs.coerceAtLeast(0L)
        // setAlarmClock survives Doze and OEM battery optimizations (Xiaomi MIUI, etc.)
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val showIntent = PendingIntent.getActivity(
            this, 199, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val clockInfo = AlarmManager.AlarmClockInfo(triggerAt, showIntent)
        alarmManager.setAlarmClock(clockInfo, pendingIntent)
    }

    private fun cancelScheduledStreakReminderNotification() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = streakReminderPendingIntent()
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun cancelCountdownNotification() {
        timerNotificationToken += 1
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fun clearNow() {
            nm.cancel(1)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                nm.activeNotifications
                    .filter {
                        it.id == 1 || it.notification.channelId == "timer_gym_cd"
                    }
                    .forEach { active -> nm.cancel(active.id) }
            }
        }
        clearNow()
        Handler(Looper.getMainLooper()).postDelayed({ clearNow() }, 180)
    }

    private fun cancelTimerNotifications() {
        timerNotificationToken += 1
        cancelScheduledTimerFinishedNotification()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fun clearNow() {
            nm.cancel(0)
            nm.cancel(1)
            nm.cancel(2)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                nm.activeNotifications
                    .filter {
                        it.id == 0 ||
                            it.id == 1 ||
                            it.id == 2 ||
                            it.notification.channelId == "timer_gym" ||
                            it.notification.channelId == "timer_gym_alert" ||
                            it.notification.channelId == "timer_gym_cd"
                    }
                    .forEach { active -> nm.cancel(active.id) }
            }
        }
        clearNow()
        Handler(Looper.getMainLooper()).postDelayed({ clearNow() }, 180)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gym_file_reader")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readBytes" -> {
                        try {
                            val uri = Uri.parse(call.arguments as String)
                            val bytes = contentResolver.openInputStream(uri)?.readBytes()
                            if (bytes != null) result.success(bytes)
                            else result.error("NULL_STREAM", "Impossibile aprire lo stream", null)
                        } catch (e: Exception) {
                            result.error("READ_ERROR", e.message, null)
                        }
                    }
                    "playBeep" -> {
                        try {
                            val durationMs = (call.arguments as? Int) ?: 400
                            // STREAM_MUSIC: suona sovrapposto alla musica/YouTube senza interrompere
                            val toneMusic = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                            toneMusic.startTone(ToneGenerator.TONE_CDMA_SOFT_ERROR_LITE, durationMs)
                            Handler(Looper.getMainLooper()).postDelayed({
                                toneMusic.release()
                            }, (durationMs + 300).toLong())
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("BEEP_ERROR", e.message, null)
                        }
                    }
                    "showTimerNotification" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val timeStr = args["time"] as String
                            val subtitle = args["subtitle"] as String
                            val channelId = args["channel"] as String
                            val remainingSeconds = (args["remainingSeconds"] as? Number)?.toLong() ?: 0L
                            val token = (args["token"] as? Number)?.toLong() ?: 0L
                            if (token < timerNotificationToken) {
                                result.success(null)
                                return@setMethodCallHandler
                            }
                            timerNotificationToken = token

                            val durationMs = remainingSeconds.coerceAtLeast(0L) * 1000L
                            val chronometerBase = SystemClock.elapsedRealtime() + durationMs

                            // Adaptive text color
                            val nightMode = resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
                            val isDarkMode = nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
                            val textColor = if (isDarkMode) 0xFFFFFFFF.toInt() else 0xFF212121.toInt()

                            // Expanded view (big Chronometer)
                            val bigViews = RemoteViews(packageName, R.layout.notification_timer)
                            bigViews.setTextViewText(R.id.notif_label, subtitle)
                            bigViews.setInt(R.id.notif_time, "setTextColor", textColor)
                            bigViews.setInt(R.id.notif_label, "setTextColor", textColor)
                            bigViews.setChronometer(R.id.notif_time, chronometerBase, null, true)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                bigViews.setChronometerCountDown(R.id.notif_time, true)
                            } else {
                                bigViews.setTextViewText(R.id.notif_time, timeStr)
                            }

                            // Collapsed view (28sp Chronometer, fits in 64dp)
                            val collapsedViews = RemoteViews(packageName, R.layout.notification_timer_collapsed)
                            collapsedViews.setTextViewText(R.id.notif_label_c, subtitle)
                            collapsedViews.setInt(R.id.notif_time_c, "setTextColor", textColor)
                            collapsedViews.setInt(R.id.notif_label_c, "setTextColor", textColor)
                            collapsedViews.setChronometer(R.id.notif_time_c, chronometerBase, null, true)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                collapsedViews.setChronometerCountDown(R.id.notif_time_c, true)
                            } else {
                                collapsedViews.setTextViewText(R.id.notif_time_c, timeStr)
                            }

                            val launchIntent = Intent(this, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            }
                            val launchPendingIntent = PendingIntent.getActivity(
                                this, 100, launchIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            val notification = NotificationCompat.Builder(this, channelId)
                                .setSmallIcon(R.drawable.ic_notification)
                                .setColor(0xFFFF6B00.toInt())
                                .setOngoing(true)
                                .setSilent(true)
                                .setAutoCancel(false)
                                .setOnlyAlertOnce(true)
                                .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
                                .setCustomContentView(collapsedViews)
                                .setCustomBigContentView(bigViews)
                                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                                .setContentIntent(launchPendingIntent)
                                .build()

                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            nm.notify(1, notification)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("TIMER_NOTIF_ERROR", e.message, null)
                        }
                    }
                    "cancelTimerNotification" -> {
                        try {
                            cancelTimerNotifications()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }
                    "cancelCountdownNotification" -> {
                        try {
                            cancelCountdownNotification()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_COUNTDOWN_ERROR", e.message, null)
                        }
                    }
                    "scheduleTimerFinishedNotification" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val delayMs = (args["delayMs"] as? Number)?.toLong() ?: 0L
                            val title = args["title"] as? String ?: ""
                            val body = args["body"] as? String ?: ""
                            scheduleTimerFinishedNotification(delayMs, title, body)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_TIMER_FINISHED_ERROR", e.message, null)
                        }
                    }
                    "cancelTimerFinishedNotification" -> {
                        try {
                            cancelScheduledTimerFinishedNotification()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_TIMER_FINISHED_ERROR", e.message, null)
                        }
                    }
                    "scheduleStreakReminderNotification" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val delayMs = (args["delayMs"] as? Number)?.toLong() ?: 0L
                            val title = args["title"] as? String ?: ""
                            val body = args["body"] as? String ?: ""
                            scheduleStreakReminderNotification(delayMs, title, body)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_STREAK_REMINDER_ERROR", e.message, null)
                        }
                    }
                    "cancelStreakReminderNotification" -> {
                        try {
                            cancelScheduledStreakReminderNotification()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_STREAK_REMINDER_ERROR", e.message, null)
                        }
                    }
                    "shareFile" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val filePath = args["path"] as String
                            val fileName = args["name"] as String
                            val file = File(filePath)
                            val authority = "${packageName}.gym.provider"
                            val uri: Uri = FileProvider.getUriForFile(this, authority, file)
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/x-workout"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_SUBJECT, fileName)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "Condividi"))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    }
                    "updateWidget" -> {
                        try {
                            val manager = AppWidgetManager.getInstance(this)
                            val component = ComponentName(this, GymWidgetProvider::class.java)
                            val ids = manager.getAppWidgetIds(component)
                            for (id in ids) {
                                GymWidgetProvider.updateWidget(this, manager, id)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("WIDGET_UPDATE_ERROR", e.message, null)
                        }
                    }
                    "isMiui" -> {
                        result.success(isMiuiDevice())
                    }
                    "isSamsung" -> {
                        result.success(isSamsungDevice())
                    }
                    "openAutoStartSettings" -> {
                        try {
                            openAutoStartSettings()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("AUTOSTART_ERROR", e.message, null)
                        }
                    }
                    "openBatterySettings" -> {
                        try {
                            openBatterySettings()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("BATTERY_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isMiuiDevice(): Boolean {
        return Build.MANUFACTURER.lowercase() == "xiaomi" ||
            !getSystemProperty("ro.miui.ui.version.name").isNullOrEmpty() ||
            !getSystemProperty("ro.miui.ui.version.code").isNullOrEmpty()
    }

    private fun isSamsungDevice(): Boolean {
        return Build.MANUFACTURER.lowercase() == "samsung"
    }

    private fun getSystemProperty(key: String): String? {
        return try {
            val cls = Class.forName("android.os.SystemProperties")
            val method = cls.getMethod("get", String::class.java)
            method.invoke(null, key) as? String
        } catch (e: Exception) {
            null
        }
    }

    private fun openAutoStartSettings() {
        val miuiIntents = listOf(
            Intent().setComponent(ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )),
            Intent().setComponent(ComponentName(
                "com.miui.securitycenter",
                "com.miui.powercenter.PowerAndPerformanceActivity"
            )),
            Intent().setComponent(ComponentName(
                "com.miui.powerkeeper",
                "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
            )),
        )
        for (intent in miuiIntents) {
            try {
                startActivity(intent)
                return
            } catch (e: Exception) {}
        }
        try {
            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {}
    }

    private fun openBatterySettings() {
        val samsungIntents = listOf(
            Intent().setComponent(ComponentName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            )),
            Intent().setComponent(ComponentName(
                "com.samsung.android.sm",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            )),
        )
        for (intent in samsungIntents) {
            try {
                startActivity(intent)
                return
            } catch (e: Exception) {}
        }
        try {
            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {}
    }
}

