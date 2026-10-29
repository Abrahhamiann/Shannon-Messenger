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
    private val messagingWorker = java.util.concurrent.Executors.newSingleThreadExecutor()
    private var messagingStore: MessagingStore? = null
    private var messagingChannel: MethodChannel? = null
    @Volatile private var messagingAllowed = false
    private var lastMessagingVisibility: Boolean? = null
    private val validationMessaging = mutableMapOf<String,MessagingStore>()
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
        messagingAllowed = !backgrounded && ::appLock.isInitialized && !appLock.locked
        if(lastMessagingVisibility != messagingAllowed) {
            lastMessagingVisibility = messagingAllowed
            messagingChannel?.invokeMethod(if(messagingAllowed) "foreground" else "background", null)
        }
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
        messagingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shannon/messaging")
        messagingChannel!!.setMethodCallHandler { call, result ->
            if(call.method=="validationRenderUnlock" && packageName=="dev.shannon.shannon.validation" && (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)!=0) {
                try {
                    // Draw a separate, static instance of the real component.
                    // This never captures the activity or any protected content.
                    val dark=call.argument<Boolean>("dark")==true
                    val preview=PremiumUnlockView(this,dark,false){}
                    val width=(390*resources.displayMetrics.density).toInt();val height=(844*resources.displayMetrics.density).toInt()
                    preview.measure(android.view.View.MeasureSpec.makeMeasureSpec(width,android.view.View.MeasureSpec.EXACTLY),android.view.View.MeasureSpec.makeMeasureSpec(height,android.view.View.MeasureSpec.EXACTLY))
                    preview.layout(0,0,width,height)
                    val bitmap=android.graphics.Bitmap.createBitmap(width,height,android.graphics.Bitmap.Config.ARGB_8888)
                    preview.draw(android.graphics.Canvas(bitmap))
                    val file=File(getExternalFilesDir(null),"ux-unlock-${if(dark)"dark" else "light"}.png")
                    file.outputStream().use {bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,it)};bitmap.recycle()
                    result.success(file.absolutePath)
                }catch(_:Exception){result.error("preview_failed","Static component preview unavailable",null)}
            }
            else if(call.method=="visibility") result.success(messagingAllowed)
            else if(call.method.startsWith("validation") && packageName=="dev.shannon.shannon.validation" && (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)!=0) messagingWorker.execute {
                try {
                    val value=when(call.method) {
                        "validationCreate" -> {
                            val handle=java.util.UUID.randomUUID().toString().replace("-","")
                            validationMessaging[handle]=MessagingStore(applicationContext,"shannon_m4_test_$handle.db","shannon_m4_test_$handle",true)
                            handle
                        }
                        "validationInvoke" -> {
                            val input=org.json.JSONObject(call.arguments as String)
                            validationMessaging[input.getString("handle")]!!.invoke(input.getJSONObject("request").toString())
                        }
                        "validationReopen" -> {
                            val handle=call.arguments as String
                            require(handle.matches(Regex("[0-9a-f]{32}")))
                            require(validationMessaging.containsKey(handle))
                            validationMessaging.remove(handle)!!.close()
                            validationMessaging[handle]=MessagingStore(applicationContext,"shannon_m4_test_$handle.db","shannon_m4_test_$handle",true)
                            "ok"
                        }
                        else -> error("validation_unavailable")
                    }
                    runOnUiThread { result.success(value) }
                }catch(failure:Throwable){
                    val code=if(failure is MessagingFailure)failure.code else "validation_failed"
                    runOnUiThread { result.error(code,"Isolated messaging validation failed",null) }
                }
            }
            else if(call.method != "invoke" || call.arguments !is String) result.notImplemented()
            else if(!messagingAllowed) result.error("app_locked", "Unlock Shannon before accessing messaging", null)
            else messagingWorker.execute {
                try {
                    if(!messagingAllowed) throw MessagingFailure("app_locked")
                    val store = messagingStore ?: MessagingStore(applicationContext).also { messagingStore = it }
                    val response = store.invoke(call.arguments as String)
                    runOnUiThread { result.success(response) }
                } catch(failure: Throwable) {
                    val code = if(failure is MessagingFailure) failure.code else "storage_or_protocol_failure"
                    runOnUiThread { result.error(code, "Messaging operation failed. Existing keys and data were preserved.", null) }
                }
            }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shannon/privacy")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "appLockState" -> result.success(appLock.state())
                "copyPrivate" -> {
                    val text=call.arguments as? String
                    if(!messagingAllowed || text==null || text.length>8000) result.error("unavailable","Unlock before copying a message",null)
                    else {
                        val clip=android.content.ClipData.newPlainText("Shannon message",text)
                        clip.description.extras=android.os.PersistableBundle().apply{putBoolean("android.content.extra.IS_SENSITIVE",true)}
                        (getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager).setPrimaryClip(clip)
                        result.success(null)
                    }
                }
                "appearance" -> {appLock.appearance(call.arguments=="dark");result.success(null)}
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
        messagingWorker.execute { messagingStore?.close(); validationMessaging.values.forEach { it.close() }; validationMessaging.clear() }
        messagingWorker.shutdown()
        if (::appLock.isInitialized) appLock.destroy()
        super.onDestroy()
    }
}
