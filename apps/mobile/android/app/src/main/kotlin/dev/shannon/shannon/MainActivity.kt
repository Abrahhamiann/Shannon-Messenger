package dev.shannon.shannon

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.zxing.integration.android.IntentIntegrator
import com.google.zxing.client.android.Intents
import com.google.zxing.BinaryBitmap
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import android.graphics.BitmapFactory
import java.io.File

class MainActivity : FlutterActivity() {
    private lateinit var appLock: AppLock
    private var backgrounded = false
    private val leases = mutableSetOf<String>()
    private var starting = true
    private var channel: MethodChannel? = null
    private var pendingInvite: String? = null
    private var pendingScan: MethodChannel.Result? = null
    private fun applyPrivacy() {
        if (starting || backgrounded || (::appLock.isInitialized && appLock.locked) || leases.isNotEmpty()) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        // Fail closed during engine startup/restoration; content waits for a lease.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(false)
        appLock = AppLock(this) { applyPrivacy() }
        appLock.resume()
        if (Build.VERSION.SDK_INT >= 29) {
            (getSystemService(AUDIO_SERVICE) as AudioManager).setAllowedCapturePolicy(AudioAttributes.ALLOW_CAPTURE_BY_NONE)
        }
        pendingInvite = inviteFrom(intent)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shannon/privacy")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "appLockState" -> result.success(appLock.state())
                "configureAppLock" -> appLock.configure(call.argument<Boolean>("enabled") == true, call.argument<Int>("seconds") ?: 0, result)
                "lockNow" -> { appLock.lockNow(); result.success(null) }
                "ready" -> { starting = false; applyPrivacy(); result.success(null) }
                "isProtected" -> result.success((window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0)
                "acquire" -> {
                    val id = call.arguments as? String
                    if (id == null) result.error("invalid", "Missing privacy lease", null)
                    else { leases.add(id); applyPrivacy(); result.success(null) }
                }
                "release" -> {
                    leases.remove(call.arguments as? String)
                    // A new acquire prevents a stale clear after retiring route frames.
                    window.decorView.postOnAnimation {
                        window.decorView.postOnAnimation { applyPrivacy() }
                    }
                    result.success(null)
                }
                "initialInvite" -> { result.success(pendingInvite); pendingInvite = null }
                "scanInvite" -> {
                    if (pendingScan != null) {
                        result.error("busy", "Scanner is already open", null)
                    } else {
                        pendingScan = result
                        try {
                            IntentIntegrator(this)
                                .setCaptureActivity(ShannonScanActivity::class.java)
                                .setDesiredBarcodeFormats(listOf("QR_CODE"))
                                .setPrompt("Scan a Shannon invitation")
                                .setBeepEnabled(false)
                                .setBarcodeImageEnabled(false)
                                .setOrientationLocked(false)
                                .initiateScan()
                        } catch (_: Exception) {
                            pendingScan = null
                            result.error("camera_unavailable", "Camera unavailable", null)
                        }
                    }
                }
                "decodeQrForValidation" -> {
                    // Debug-only image decoding exercises the same ZXing QR
                    // decoder as the live scanner, with synthetic test images.
                    if (packageName != "dev.shannon.shannon.validation" ||
                        (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
                        result.notImplemented()
                    } else {
                        try {
                            val file = File(call.arguments as String).canonicalFile
                            require(listOf(cacheDir, codeCacheDir).any {
                                file.path.startsWith(it.canonicalPath + File.separator)
                            })
                            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                            BitmapFactory.decodeFile(file.path, bounds)
                            require(bounds.outWidth in 1..4096 && bounds.outHeight in 1..4096)
                            require(bounds.outWidth.toLong() * bounds.outHeight <= 8_000_000)
                            val bitmap = BitmapFactory.decodeFile(file.path) ?: error("Invalid image")
                            try {
                                val pixels = IntArray(bitmap.width * bitmap.height)
                                bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                                val source = RGBLuminanceSource(bitmap.width, bitmap.height, pixels)
                                result.success(QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text)
                            } finally { bitmap.recycle() }
                        } catch (_: Exception) { result.error("decode_failed", "QR could not be decoded", null) }
                    }
                }
                "openAppSettings" -> {
                    startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "shareInvite" -> {
                    val link = call.arguments as? String
                    if (link == null || !link.matches(Regex("shannon://invite/v1#[A-Za-z0-9_-]{43}"))) {
                        result.error("invalid", "Invalid invitation", null)
                    } else {
                        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"; putExtra(Intent.EXTRA_TEXT, link)
                        }, "Share Shannon invitation"))
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun inviteFrom(value: Intent?): String? {
        val uri = value?.data ?: return null
        if (uri.scheme != "shannon" || uri.host != "invite" || uri.path != "/v1" || uri.query != null || uri.port != -1 || uri.userInfo != null) return null
        return uri.fragment?.takeIf { it.matches(Regex("[A-Za-z0-9_-]{43}")) }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val token = inviteFrom(intent) ?: return
        channel?.invokeMethod("invite", token)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (::appLock.isInitialized && appLock.result(requestCode, resultCode)) return
        val scan = IntentIntegrator.parseActivityResult(requestCode, resultCode, data)
        if (scan == null) { super.onActivityResult(requestCode, resultCode, data); return }
        val response = pendingScan
        pendingScan = null
        if (response != null) {
            if (data?.getBooleanExtra(Intents.Scan.MISSING_CAMERA_PERMISSION, false) == true) {
                response.error("permission_denied", "Camera permission is required", null)
            } else { response.success(scan.contents?.takeIf { it.length <= 4096 }) }
        } else if (scan.contents != null) {
            // Activity recreation must not discard a successfully scanned invite.
            val token = inviteFrom(Intent().setData(android.net.Uri.parse(scan.contents)))
            if (token != null) { pendingInvite = token; channel?.invokeMethod("invite", token) }
        }
    }
    override fun onPause() {
        backgrounded = true
        if (::appLock.isInitialized) appLock.pause()
        applyPrivacy()
        super.onPause()
    }
    override fun onResume() {
        super.onResume()
        backgrounded = false
        if (::appLock.isInitialized) appLock.resume()
        applyPrivacy()
    }
    override fun onDestroy() {
        if (::appLock.isInitialized) appLock.destroy()
        super.onDestroy()
    }
}
