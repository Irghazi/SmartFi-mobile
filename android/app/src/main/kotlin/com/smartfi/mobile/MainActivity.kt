package com.smartfi.mobile

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val UPDATER_CHANNEL = "com.smartfi.mobile/app_updater"
        private const val WIDGET_CHANNEL = "com.smartfi.mobile/home_widget"
    }

    private var widgetChannel: MethodChannel? = null
    private var pendingTabIndex: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractTabFromIntent(intent, notifyFlutter = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractTabFromIntent(intent, notifyFlutter = true)
    }

    private fun extractTabFromIntent(intent: Intent?, notifyFlutter: Boolean) {
        if (intent == null) return
        if (intent.hasExtra(SmartFiWidgetProvider.EXTRA_TAB_INDEX)) {
            val tabIndex = intent.getIntExtra(SmartFiWidgetProvider.EXTRA_TAB_INDEX, -1)
            intent.removeExtra(SmartFiWidgetProvider.EXTRA_TAB_INDEX)
            if (tabIndex in 0..4) {
                if (notifyFlutter && widgetChannel != null) {
                    widgetChannel?.invokeMethod("onOpenTab", tabIndex)
                } else {
                    pendingTabIndex = tabIndex
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppVersion" -> {
                        try {
                            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                packageManager.getPackageInfo(
                                    packageName,
                                    PackageManager.PackageInfoFlags.of(0)
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                packageManager.getPackageInfo(packageName, 0)
                            }
                            val buildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                packageInfo.longVersionCode.toInt()
                            } else {
                                @Suppress("DEPRECATION")
                                packageInfo.versionCode
                            }
                            result.success(
                                mapOf(
                                    "versionName" to (packageInfo.versionName ?: "1.0.0"),
                                    "buildNumber" to buildNumber
                                )
                            )
                        } catch (e: Exception) {
                            result.error("VERSION_ERROR", e.message, null)
                        }
                    }

                    "canInstallPackages" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            result.success(packageManager.canRequestPackageInstalls())
                        } else {
                            result.success(true)
                        }
                    }

                    "openInstallPermissionSettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }

                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Path file APK kosong.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val apkFile = File(filePath)
                            if (!apkFile.exists()) {
                                result.error("FILE_NOT_FOUND", "File APK tidak ditemukan.", null)
                                return@setMethodCallHandler
                            }
                            val authority = "${applicationContext.packageName}.updater.fileprovider"
                            val apkUri = FileProvider.getUriForFile(this, authority, apkFile)
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    try {
                        val isLoggedIn = call.argument<Boolean>("isLoggedIn") ?: false
                        val balanceText = call.argument<String>("balanceText") ?: "Rp 0"
                        val incomeMonthText = call.argument<String>("incomeMonthText") ?: "Rp 0"
                        val expenseMonthText = call.argument<String>("expenseMonthText") ?: "Rp 0"
                        val targetPercent = call.argument<Int>("targetPercent") ?: 0
                        val isDark = call.argument<Boolean>("isDark") ?: false

                        SmartFiWidgetProvider.saveAndUpdateAll(
                            context = applicationContext,
                            isLoggedIn = isLoggedIn,
                            balanceText = balanceText,
                            incomeMonthText = incomeMonthText,
                            expenseMonthText = expenseMonthText,
                            targetPercent = targetPercent,
                            isDark = isDark
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WIDGET_UPDATE_ERROR", e.message, null)
                    }
                }

                "consumeInitialTabIndex" -> {
                    val tab = pendingTabIndex
                    pendingTabIndex = null
                    result.success(tab)
                }

                else -> result.notImplemented()
            }
        }
    }
}
