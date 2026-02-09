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

class RedirectPlugin : FlutterPlugin, ActivityAware, PluginRegistry.NewIntentListener,
    RedirectHostApi {
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingCallback: ((Result<String?>) -> Unit)? = null
    private var expectedScheme: String? = null
    private var timeoutRunnable: Runnable? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        RedirectHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    // -- RedirectHostApi (Pigeon) --

    override fun run(request: RunRequest, callback: (Result<String?>) -> Unit) {
        val url = Uri.parse(request.url)
        val currentActivity = activity

        if (currentActivity == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "Android activity is not available", null)))
            return
        }

        // Cancel any pending operation
        cancelInternal()
        pendingCallback = callback
        expectedScheme = request.callbackUrlScheme

        val opts = request.androidOptions
        val useCustomTabs = opts.useCustomTabs
        val showTitle = opts.showTitle
        val enableUrlBarHiding = opts.enableUrlBarHiding
        val toolbarColor = opts.toolbarColor?.toInt()
        val secondaryToolbarColor = opts.secondaryToolbarColor?.toInt()

        if (useCustomTabs) {
            val builder = CustomTabsIntent.Builder()
                .setShowTitle(showTitle)
                .setUrlBarHidingEnabled(enableUrlBarHiding)

            // Use the modern setDefaultColorSchemeParams API instead of the
            // deprecated setToolbarColor / setSecondaryToolbarColor methods.
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

        // Schedule timeout if specified
        val timeoutMillis = request.timeoutMillis
        if (timeoutMillis != null) {
            val runnable = Runnable {
                if (pendingCallback != null) {
                    pendingCallback?.invoke(Result.success(null)) // Treated as cancellation
                    pendingCallback = null
                    expectedScheme = null
                }
            }
            timeoutRunnable = runnable
            mainHandler.postDelayed(runnable, timeoutMillis)
        }
    }

    override fun cancel() {
        cancelInternal()
    }

    private fun cancelInternal() {
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null
        pendingCallback?.invoke(Result.success(null))
        pendingCallback = null
        expectedScheme = null
    }

    // -- Intent handling --

    override fun onNewIntent(intent: Intent): Boolean {
        val data = intent.data ?: return false
        val scheme = data.scheme ?: return false

        if (pendingCallback != null && scheme == expectedScheme) {
            timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
            timeoutRunnable = null
            pendingCallback?.invoke(Result.success(data.toString()))
            pendingCallback = null
            expectedScheme = null
            return true
        }

        return false
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
        // Cancel any pending redirect — there's no activity to receive
        // the callback intent anymore.
        cancelInternal()
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RedirectHostApi.setUp(binding.binaryMessenger, null)
    }
}