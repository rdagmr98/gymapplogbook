package com.example.app_cliente

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

class GymWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 130)
            updateWidget(context, appWidgetManager, widgetId, minWidth, minHeight)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val minWidth = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        val minHeight = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 130)
        updateWidget(context, appWidgetManager, appWidgetId, minWidth, minHeight)
    }

    companion object {

        private fun parseJsonArray(json: String): List<String> {
            if (json.length <= 2) return emptyList()
            val inner = json.trim().trimStart('[').trimEnd(']')
            return inner.split(",").map { it.trim().trim('"') }.filter { it.isNotEmpty() }
        }

        private fun muscleDrawable(muscleName: String): Int {
            return when (muscleName) {
                "petto"   -> R.drawable.wm_petto
                "gambe"   -> R.drawable.wm_gambe
                "spalle"  -> R.drawable.wm_spalle
                "braccia" -> R.drawable.wm_braccia
                "dorso"   -> R.drawable.wm_dorso
                "glutei"  -> R.drawable.wm_glutei
                "pull"    -> R.drawable.wm_pull
                "push"    -> R.drawable.wm_push
                else      -> 0
            }
        }

        private val badgeIds = intArrayOf(
            R.id.widget_badge_1, R.id.widget_badge_2, R.id.widget_badge_3,
            R.id.widget_badge_4, R.id.widget_badge_5, R.id.widget_badge_6,
            R.id.widget_badge_7
        )

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            widgetWidth: Int = 250,
            widgetHeight: Int = 130
        ) {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

                val streak = try {
                    prefs.getLong("flutter.widget_streak", 0L)
                } catch (e: ClassCastException) {
                    prefs.getInt("flutter.widget_streak", 0).toLong()
                }

                val nextWorkout = prefs.getString("flutter.widget_next_workout", "—") ?: "—"
                val nextMuscle = prefs.getString("flutter.widget_next_muscle", "") ?: ""

                val sessionNamesJson = prefs.getString("flutter.widget_session_names", "[]") ?: "[]"
                val sessionNames = parseJsonArray(sessionNamesJson)

                val sessionMusclesJson = prefs.getString("flutter.widget_session_muscles", "[]") ?: "[]"
                val sessionMuscles = parseJsonArray(sessionMusclesJson)

                val doneJson = prefs.getString("flutter.microcycle_done_c", "[]") ?: "[]"
                val doneSessions = parseJsonArray(doneJson).toSet()

                // Use large layout when widget is big
                val isLarge = widgetWidth >= 340 || widgetHeight >= 200
                val layoutId = if (isLarge) R.layout.gym_widget_large else R.layout.gym_widget
                val views = RemoteViews(context.packageName, layoutId)

                views.setTextViewText(R.id.widget_streak, "\uD83D\uDD25 $streak")
                views.setTextViewText(R.id.widget_workout, nextWorkout)

                // Main muscle image
                val drawableId = muscleDrawable(nextMuscle)
                if (drawableId != 0) {
                    views.setImageViewResource(R.id.widget_muscle, drawableId)
                    views.setViewVisibility(R.id.widget_muscle, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_muscle, View.INVISIBLE)
                }

                // Session badge ImageViews: show muscle icon + colored background per status
                val doneCount = doneSessions.size
                val totalCount = sessionNames.size

                for (i in 0 until 7) {
                    val badgeId = badgeIds[i]
                    if (i < sessionNames.size) {
                        val name = sessionNames[i]
                        val muscle = if (i < sessionMuscles.size) sessionMuscles[i] else ""
                        val muscleDrId = muscleDrawable(muscle)

                        // Set muscle image on badge
                        if (muscleDrId != 0) {
                            views.setImageViewResource(badgeId, muscleDrId)
                        } else {
                            // No image: use app icon as fallback
                            views.setImageViewResource(badgeId, R.mipmap.ic_launcher)
                        }

                        // Set background based on done/pending (next looks same as pending)
                        val bgDrawable = if (doneSessions.contains(name))
                            R.drawable.widget_badge_done
                        else
                            R.drawable.widget_badge_pending
                        views.setInt(badgeId, "setBackgroundResource", bgDrawable)

                        // Alpha: full for done, dimmed for not-yet-done
                        val alpha = if (doneSessions.contains(name)) 255 else 35
                        views.setInt(badgeId, "setImageAlpha", alpha)

                        views.setViewVisibility(badgeId, View.VISIBLE)
                    } else {
                        views.setViewVisibility(badgeId, View.GONE)
                    }
                }

                views.setTextViewText(R.id.widget_progress_label, "$doneCount/$totalCount")

                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val pi = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)

                val startWorkoutIntent = Intent(context, MainActivity::class.java).apply {
                    action = "com.example.app_cliente.START_WORKOUT"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val startWorkoutPi = PendingIntent.getActivity(
                    context, 2, startWorkoutIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_start_btn, startWorkoutPi)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                try {
                    val views = RemoteViews(context.packageName, R.layout.gym_widget)
                    views.setTextViewText(R.id.widget_streak, "\uD83D\uDD25 0")
                    views.setTextViewText(R.id.widget_workout, "Apri app")
                    appWidgetManager.updateAppWidget(widgetId, views)
                } catch (_: Exception) {}
            }
        }
    }
}