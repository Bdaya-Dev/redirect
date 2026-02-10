package com.bdayadev

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Tracks state for a single in-flight redirect operation.
 */
private data class PendingRedirect(
    val callback: (Result<String?>) -> Unit,
    val expectedScheme: String,
    var timeoutRunnable: Runnable? = null,
)

class RedirectPlugin : FlutterPlugin, ActivityAware, PluginRegistry.NewIntentListener,
    RedirectHostApi {
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    /** All in-flight redirects, keyed by nonce. */
    private val pendingRedirects = mutableMapOf<String, PendingRedirect>()

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        RedirectHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    // -- RedirectHostApi (Pigeon) --

    override fun run(request: RunRequest, callback: (Result<String?>) -> Unit) {
        val url = Uri.parse(request.url)
        val currentActivity = activity
        val nonce = request.nonce

        if (currentActivity == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "Android activity is not available", null)))
            return
        }

        // If there's already a redirect with this nonce, cancel it first.
        cancelByNonce(nonce)

        val opts = request.androidOptions
        val useCustomTabs = opts.useCustomTabs
        val showTitle = opts.showTitle
        val enableUrlBarHiding = opts.enableUrlBarHiding
        val toolbarColor = opts.toolbarColor?.toInt()
        val secondaryToolbarColor = opts.secondaryToolbarColor?.toInt()

        var pending = PendingRedirect(
            callback = callback,
            expectedScheme = request.callbackUrlScheme,
        )

        // Schedule timeout if specified
        val timeoutMillis = request.timeoutMillis
        if (timeoutMillis != null) {
            val runnable = Runnable {
                cancelByNonce(nonce)
            }
            pending = pending.copy(timeoutRunnable = runnable)
            mainHandler.postDelayed(runnable, timeoutMillis)
        }

        pendingRedirects[nonce] = pending

        if (useCustomTabs) {
            val builder = CustomTabsIntent.Builder()
                .setShowTitle(showTitle)
                .setUrlBarHidingEnabled(enableUrlBarHiding)

            if (toolbarColor != null || secondaryToolbarColor != null) {
                val colorParams = CustomTabColorSchemeParams.Builder()
                if (toolbarColor != null) {
                    colorParams.setToolbarColor(toolbarColor)
                }
                if (secondaryToolbarColor != null) {
                    colorParams.setSecondaryToolbarColor(secondaryToolbarColor)
                }
                builder.setDefaultColorSchemeParams(colorParams.build())
            }

            val customTabsIntent = builder.build()
            customTabsIntent.launchUrl(currentActivity, url)
        } else {
            val intent = Intent(Intent.ACTION_VIEW, url)
            currentActivity.startActivity(intent)
        }
    }

    override fun cancel(nonce: String) {
        if (nonce.isEmpty()) {
            cancelAll()
        } else {
            cancelByNonce(nonce)
        }
    }

    /** Cancels a single redirect operation by nonce. */
    private fun cancelByNonce(nonce: String) {
        val pending = pendingRedirects.remove(nonce) ?: return
        pending.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        pending.callback.invoke(Result.success(null))
    }

    /** Cancels all pending redirect operations. */
    private fun cancelAll() {
        val allNonces = pendingRedirects.keys.toList()
        for (n in allNonces) {
            cancelByNonce(n)
        }
    }

    // -- Intent handling --

    override fun onNewIntent(intent: Intent): Boolean {
        val data = intent.data ?: return false
        val scheme = data.scheme ?: return false

        // Find matching pending redirect by scheme.
        // If multiple redirects share the same scheme, the first match wins.
        val matchingEntry = pendingRedirects.entries.firstOrNull { (_, pending) ->
            pending.expectedScheme == scheme
        } ?: return false

        val nonce = matchingEntry.key
        val pending = pendingRedirects.remove(nonce) ?: return false

        pending.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        pending.callback.invoke(Result.success(data.toString()))
        return true
    }

    // -- Activity lifecycle --

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        activity = null
        // Don't cancel pending operations during config changes —
        // the activity will be re-attached shortly and the intent
        // listener will be re-registered.
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        // Cancel all pending redirects — there's no activity to receive
        // the callback intent anymore.
        cancelAll()
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RedirectHostApi.setUp(binding.binaryMessenger, null)
    }
}