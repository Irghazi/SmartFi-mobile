package com.smartfi.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class SmartFiWidgetProvider : AppWidgetProvider() {
    companion object {
        const val PREFS_NAME = "smartfi_home_widget"
        const val ACTION_TOGGLE_PRIVACY = "com.smartfi.mobile.ACTION_TOGGLE_PRIVACY"
        const val EXTRA_TAB_INDEX = "smartfi_tab_index"

        private const val KEY_IS_LOGGED_IN = "is_logged_in"
        private const val KEY_IS_HIDDEN = "is_hidden"
        private const val KEY_IS_DARK = "is_dark"
        private const val KEY_BALANCE_TEXT = "balance_text"
        private const val KEY_INCOME_MONTH_TEXT = "income_month_text"
        private const val KEY_EXPENSE_MONTH_TEXT = "expense_month_text"
        private const val KEY_TARGET_PERCENT = "target_percent"

        fun saveAndUpdateAll(
            context: Context,
            isLoggedIn: Boolean,
            balanceText: String,
            incomeMonthText: String,
            expenseMonthText: String,
            targetPercent: Int,
            isDark: Boolean
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_IS_LOGGED_IN, isLoggedIn)
                .putString(KEY_BALANCE_TEXT, balanceText)
                .putString(KEY_INCOME_MONTH_TEXT, incomeMonthText)
                .putString(KEY_EXPENSE_MONTH_TEXT, expenseMonthText)
                .putInt(KEY_TARGET_PERCENT, targetPercent.coerceIn(0, 100))
                .putBoolean(KEY_IS_DARK, isDark)
                .apply()

            updateAllWidgets(context)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SmartFiWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }

        private fun createOpenAppIntent(
            context: Context,
            tabIndex: Int,
            requestCode: Int
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.smartfi.mobile.OPEN_TAB_$tabIndex"
                putExtra(EXTRA_TAB_INDEX, tabIndex)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getActivity(context, requestCode, intent, flags)
        }

        private fun createTogglePrivacyIntent(context: Context): PendingIntent {
            val intent = Intent(context, SmartFiWidgetProvider::class.java).apply {
                action = ACTION_TOGGLE_PRIVACY
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(context, 203, intent, flags)
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isLoggedIn = prefs.getBoolean(KEY_IS_LOGGED_IN, false)
            val isHidden = prefs.getBoolean(KEY_IS_HIDDEN, false)
            val isDark = prefs.getBoolean(KEY_IS_DARK, false)
            val balanceText = prefs.getString(KEY_BALANCE_TEXT, "Rp 0") ?: "Rp 0"
            val incomeText = prefs.getString(KEY_INCOME_MONTH_TEXT, "Rp 0") ?: "Rp 0"
            val expenseText = prefs.getString(KEY_EXPENSE_MONTH_TEXT, "Rp 0") ?: "Rp 0"
            val targetPercent = prefs.getInt(KEY_TARGET_PERCENT, 0).coerceIn(0, 100)

            val layoutRes = if (isDark) {
                R.layout.widget_smartfi_4x2_dark
            } else {
                R.layout.widget_smartfi_4x2
            }

            val views = RemoteViews(context.packageName, layoutRes)

            if (!isLoggedIn) {
                views.setTextViewText(R.id.txt_balance_label, "SMARTFI TERKUNCI")
                views.setTextViewText(R.id.txt_balance_value, "Masuk ke SmartFi")
                views.setTextViewText(R.id.txt_target_percent, "")
                views.setProgressBar(R.id.progress_target, 100, 0, false)
                views.setTextViewText(R.id.txt_income_month, "-")
                views.setTextViewText(R.id.txt_expense_month, "-")
                views.setImageViewResource(R.id.img_privacy_icon, R.drawable.ic_widget_eye)
            } else if (isHidden) {
                views.setTextViewText(R.id.txt_balance_label, "SALDO TERKINI")
                views.setTextViewText(R.id.txt_balance_value, "Rp ••••••")
                views.setTextViewText(R.id.txt_target_percent, "••% TARGET")
                views.setProgressBar(R.id.progress_target, 100, 0, false)
                views.setTextViewText(R.id.txt_income_month, "Rp ••••••")
                views.setTextViewText(R.id.txt_expense_month, "Rp ••••••")
                views.setImageViewResource(R.id.img_privacy_icon, R.drawable.ic_widget_eye_off)
            } else {
                views.setTextViewText(R.id.txt_balance_label, "SALDO TERKINI")
                views.setTextViewText(R.id.txt_balance_value, balanceText)
                views.setTextViewText(R.id.txt_target_percent, "$targetPercent% TARGET")
                views.setProgressBar(R.id.progress_target, 100, targetPercent, false)
                views.setTextViewText(R.id.txt_income_month, incomeText)
                views.setTextViewText(R.id.txt_expense_month, expenseText)
                views.setImageViewResource(R.id.img_privacy_icon, R.drawable.ic_widget_eye)
            }

            // Aksi klik 1-ketukan (Beranda, Transaksi Smart Input, Mentor AI, Sensor Saldo)
            val openDashboardIntent = createOpenAppIntent(context, 0, 200)
            views.setOnClickPendingIntent(R.id.widget_root, openDashboardIntent)
            views.setOnClickPendingIntent(R.id.section_balance, openDashboardIntent)
            views.setOnClickPendingIntent(R.id.section_flow, openDashboardIntent)
            views.setOnClickPendingIntent(
                R.id.btn_quick_add,
                createOpenAppIntent(context, 1, 201)
            )
            views.setOnClickPendingIntent(
                R.id.btn_open_ai,
                createOpenAppIntent(context, 2, 202)
            )
            views.setOnClickPendingIntent(
                R.id.btn_toggle_privacy,
                createTogglePrivacyIntent(context)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE_PRIVACY) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isLoggedIn = prefs.getBoolean(KEY_IS_LOGGED_IN, false)
            if (!isLoggedIn) return
            val currentHidden = prefs.getBoolean(KEY_IS_HIDDEN, false)
            prefs.edit().putBoolean(KEY_IS_HIDDEN, !currentHidden).apply()
            updateAllWidgets(context)
        }
    }
}
