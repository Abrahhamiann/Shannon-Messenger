package dev.shannon.shannon

import android.app.Activity
import android.app.KeyguardManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.os.SystemClock
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.MethodChannel

/** Local UI lock only. No biometric templates or server credentials are stored. */
class AppLock(private val activity: Activity, private val privacy: () -> Unit) {
    private val prefs = activity.getSharedPreferences("shannon_app_lock", 0)
    var locked = prefs.getBoolean("enabled", false)
        private set
    private var backgroundAt: Long? = null
    private var foreground = true
    private var cover: LinearLayout? = null
    private var pending: ((Boolean) -> Unit)? = null
    private var cancellation: CancellationSignal? = null
    private var underlying: View? = null
    val enabled get() = prefs.getBoolean("enabled", false)
    val seconds get() = prefs.getInt("seconds", 0)

    fun state() = mapOf("enabled" to enabled, "seconds" to seconds, "locked" to locked,
        "available" to (activity.getSystemService(KeyguardManager::class.java).isDeviceSecure))

    fun configure(enable: Boolean, timeout: Int, result: MethodChannel.Result) {
        if (timeout !in listOf(0, 30, 60, 300)) { result.error("invalid", "Invalid timeout", null); return }
        authenticate { success ->
            if (!success) { result.error("cancelled", "Device authentication was not completed", null) }
            else if (!prefs.edit().putBoolean("enabled", enable).putInt("seconds", timeout).commit()) {
                result.error("storage", "App Lock settings could not be saved", null)
            } else { result.success(state()) }
        }
    }

    fun pause() {
        foreground = false
        if (enabled && backgroundAt == null) backgroundAt = SystemClock.elapsedRealtime()
    }

    fun resume() {
        foreground = true
        if (enabled && pending == null) {
            val since = backgroundAt
            if (LockPolicy.expired(since, SystemClock.elapsedRealtime(), seconds)) locked = true
            backgroundAt = null
        }
        if (locked) showCover()
        privacy()
    }

    fun lockNow() { if (enabled) { locked = true; showCover(); privacy() } }

    private fun showCover() {
        if (cover != null) return
        val root = activity.findViewById<ViewGroup>(android.R.id.content)
        underlying = root.getChildAt(0)
        underlying?.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        val panel = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(Color.rgb(6, 19, 33))
            isClickable = true
            isFocusable = true
            addView(TextView(activity).apply {
                text = "Unlock Shannon"
                textSize = 26f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
            })
            addView(TextView(activity).apply {
                text = "Use your fingerprint or device screen lock to continue."
                textSize = 16f
                setTextColor(Color.rgb(157, 177, 203))
                gravity = Gravity.CENTER
                setPadding(0, 24, 0, 32)
            })
            addView(Button(activity).apply {
                text = "Unlock"
                setOnClickListener {
                    authenticate { success ->
                        if (success) {
                            locked = false
                            backgroundAt = null
                            root.removeView(cover)
                            cover = null
                            underlying?.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
                            privacy()
                        }
                    }
                }
            })
        }
        cover = panel
        root.addView(panel, ViewGroup.LayoutParams(-1, -1))
        panel.requestFocus()
    }

    @Suppress("DEPRECATION")
    private fun authenticate(done: (Boolean) -> Unit) {
        if (pending != null) { done(false); return }
        val keyguard = activity.getSystemService(KeyguardManager::class.java)
        if (!keyguard.isDeviceSecure) { done(false); return }
        pending = done
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                val builder = BiometricPrompt.Builder(activity).setTitle("Unlock Shannon")
                if (Build.VERSION.SDK_INT >= 30) {
                    builder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                } else { builder.setDeviceCredentialAllowed(true) }
                cancellation = CancellationSignal()
                builder.build().authenticate(cancellation!!, activity.mainExecutor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) { finish(true) }
                        override fun onAuthenticationError(code: Int, message: CharSequence) { finish(false) }
                    })
            } else {
                val intent = keyguard.createConfirmDeviceCredentialIntent("Unlock Shannon", "Confirm your device screen lock")
                if (intent == null) finish(false) else activity.startActivityForResult(intent, 8231)
            }
        } catch (_: Exception) { finish(false) }
    }

    fun result(code: Int, value: Int): Boolean {
        if (code != 8231) return false
        finish(value == Activity.RESULT_OK)
        return true
    }

    private fun finish(success: Boolean) {
        val callback = pending
        pending = null
        cancellation = null
        if (success) backgroundAt = null
        callback?.invoke(success)
        // Leaving during a credential prompt must not bypass the background
        // timeout when authentication is cancelled or fails.
        if (!success && foreground) resume()
    }

    fun destroy() { foreground = false; cancellation?.cancel(); finish(false) }
}
