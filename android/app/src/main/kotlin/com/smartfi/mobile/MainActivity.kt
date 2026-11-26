package com.smartfi.mobile

import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "SmartFiNative"
        private const val UPDATER_CHANNEL = "com.smartfi.mobile/app_updater"
        private const val WIDGET_CHANNEL = "com.smartfi.mobile/home_widget"
        private const val SFX_CHANNEL = "com.smartfi.mobile/sfx"
        private const val HTTP_CHANNEL = "com.smartfi.mobile/http"
    }

    private var widgetChannel: MethodChannel? = null
    private var pendingTabIndex: Int? = null

    private var soundPool: SoundPool? = null
    private var clickSoundId: Int = 0
    private var chatSoundId: Int = 0
    private var clickLoaded: Boolean = false
    private var chatLoaded: Boolean = false

    private val httpExecutor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractTabFromIntent(intent, notifyFlutter = false)
    }

    override fun onDestroy() {
        soundPool?.release()
        soundPool = null
        clickSoundId = 0
        chatSoundId = 0
        clickLoaded = false
        chatLoaded = false
        httpExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun loadSoundAsset(pool: SoundPool, assetPath: String, cacheFileName: String): Int {
        val loader = FlutterInjector.instance().flutterLoader()
        try {
            loader.ensureInitializationComplete(applicationContext, null)
        } catch (_: Exception) {}

        val lookupKey = loader.getLookupKeyForAsset(assetPath)

        // 1. Coba buka langsung sebagai AssetFileDescriptor (jika tidak terkompresi)
        try {
            assets.openFd(lookupKey).use { afd ->
                return pool.load(afd, 1)
            }
        } catch (e: Exception) {
            Log.w(TAG, "openFd gagal untuk $lookupKey, menyalin ke cache: ${e.message}")
        }

        // 2. Fallback salin ke cacheDir agar tetap bisa dimuat meski terkompresi di APK
        return try {
            val outFile = File(cacheDir, cacheFileName)
            assets.open(lookupKey).use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            }
            pool.load(outFile.absolutePath, 1)
        } catch (e: Exception) {
            Log.e(TAG, "Gagal memuat aset audio $assetPath: ${e.message}")
            0
        }
    }

    private fun initSoundPool() {
        if (soundPool != null) return
        try {
            // Gunakan USAGE_MEDIA agar suara klik & chat tetap terdengar di volume media
            // meskipun mode dering/notifikasi HP sedang senyap (Silent/DND).
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            val pool = SoundPool.Builder()
                .setMaxStreams(4)
                .setAudioAttributes(attrs)
                .build()

            pool.setOnLoadCompleteListener { _, sampleId, status ->
                if (status == 0) {
                    if (sampleId == clickSoundId) clickLoaded = true
                    if (sampleId == chatSoundId) chatLoaded = true
                } else {
                    Log.w(TAG, "SoundPool load gagal sampleId=$sampleId status=$status")
                }
            }

            clickSoundId = loadSoundAsset(pool, "assets/sounds/click.mp3", "sfx_click.mp3")
            chatSoundId = loadSoundAsset(pool, "assets/sounds/chat.mp3", "sfx_chat.mp3")

            soundPool = pool
        } catch (e: Exception) {
            Log.e(TAG, "Error initSoundPool: ${e.message}")
            soundPool = null
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

        // Preload efek suara dengan Android SoundPool (USAGE_MEDIA) untuk respons instan
        initSoundPool()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SFX_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playClick" -> {
                        if (soundPool == null || clickSoundId == 0) initSoundPool()
                        val pool = soundPool
                        if (pool != null && clickLoaded && clickSoundId != 0) {
                            val streamId = pool.play(clickSoundId, 1.0f, 1.0f, 1, 0, 1.0f)
                            result.success(streamId != 0)
                        } else {
                            result.success(false)
                        }
                    }

                    "playChat" -> {
                        if (soundPool == null || chatSoundId == 0) initSoundPool()
                        val pool = soundPool
                        if (pool != null && chatLoaded && chatSoundId != 0) {
                            val streamId = pool.play(chatSoundId, 1.0f, 1.0f, 1, 0, 1.0f)
                            result.success(streamId != 0)
                        } else {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // Transport HTTPS native Android (menggunakan Happy Eyeballs & stack jaringan OS Android)
        // agar permintaan AI selalu lancar di Wi-Fi maupun 4G/seluler tanpa kabel USB.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HTTP_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "postJson") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val urlStr = call.argument<String>("url")
                val bodyStr = call.argument<String>("body") ?: ""
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 30000

                if (urlStr.isNullOrBlank()) {
                    result.error("INVALID_URL", "URL tujuan kosong.", null)
                    return@setMethodCallHandler
                }

                httpExecutor.execute {
                    var conn: HttpURLConnection? = null
                    try {
                        val url = URL(urlStr)
                        conn = (url.openConnection() as HttpURLConnection).apply {
                            requestMethod = "POST"
                            connectTimeout = 15000
                            readTimeout = timeoutMs
                            doInput = true
                            doOutput = true
                            useCaches = false
                            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                            setRequestProperty("Accept", "application/json")
                            for ((k, v) in headers) {
                                setRequestProperty(k, v)
                            }
                        }

                        conn.outputStream.use { os ->
                            os.write(bodyStr.toByteArray(Charsets.UTF_8))
                            os.flush()
                        }

                        val statusCode = conn.responseCode
                        val stream = if (statusCode in 200..299) conn.inputStream else conn.errorStream
                        val responseText = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""

                        mainHandler.post {
                            result.success(
                                mapOf(
                                    "statusCode" to statusCode,
                                    "body" to responseText
                                )
                            )
                        }
                    } catch (e: java.net.SocketTimeoutException) {
                        mainHandler.post {
                            result.error("TIMEOUT", e.message ?: "Timeout menghubungi server AI.", null)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("NETWORK_ERROR", e.message ?: "Gagal terhubung ke server AI.", null)
                        }
                    } finally {
                        conn?.disconnect()
                    }
                }
            }
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
}
