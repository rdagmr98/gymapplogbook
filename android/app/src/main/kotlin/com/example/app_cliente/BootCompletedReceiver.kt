package com.example.app_cliente

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON") return

        // Aggiorna il widget home screen dopo il riavvio
        try {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, GymWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) {
                GymWidgetProvider.updateWidget(context, manager, id)
            }
        } catch (_: Exception) {}

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val nextFireStr = prefs.getString("flutter.streak_reminder_next_fire_c", null) ?: return
        val nextFireAt = nextFireStr.toLongOrNull() ?: return

        val now = System.currentTimeMillis()
        // If the alarm time has passed, schedule for the next day at the same time-of-day
        val targetTime = if (nextFireAt > now) nextFireAt else {
            val overdue = now - nextFireAt
            val daysLate = (overdue / AlarmManager.INTERVAL_DAY) + 1
            nextFireAt + daysLate * AlarmManager.INTERVAL_DAY
        }

        val title = prefs.getString("flutter.streak_reminder_title_c", "💪 Non perdere la tua streak!") ?: "💪 Non perdere la tua streak!"
        val body = prefs.getString("flutter.streak_reminder_body_c", "Non ti alleni da 2 giorni. Allenati oggi per mantenere i tuoi progressi!") ?: "Non ti alleni da 2 giorni. Allenati oggi per mantenere i tuoi progressi!"
        val streakIntent = Intent(context, StreakReminderReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            1991,
            streakIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, targetTime, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, targetTime, pendingIntent)
        }

        // Update stored next fire time
        prefs.edit().putString("flutter.streak_reminder_next_fire_c", targetTime.toString()).apply()
    }
}
