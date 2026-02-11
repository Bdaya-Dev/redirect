package com.bdayadev

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.VisibleForTesting
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsClient
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

/**
 * The core redirect launcher, separated from [RedirectPlugin] for testability.
 *
 * Implements the Pigeon-defined [RedirectHostApi] interface and handles all
 * browser-launching logic (Custom Tabs / plain intents) and callback matching.
 */
internal class RedirectLauncher(
    private val applicationContext: android.content.Context,
) : RedirectHostApi {
    private companion object {
        const val TAG = "RedirectLauncher"
    }

    @VisibleForTesting
    internal var activity: Activity? = null

    /** All in-flight redirects, keyed by nonce. */
    @VisibleForTesting
    internal val pendingRedirects = mutableMapOf<String, PendingRedirect>()

    private val mainHandler = Handler(Looper.getMainLooper())

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

        try {
            if (useCustomTabs) {
                val builder = CustomTabsIntent.Builder()
                    .setShowTitle(showTitle)
                    .setUrlBarHidingEnabled(enableUrlBarHiding)

                if (request.preferEphemeral) {
                    builder.setEphemeralBrowsingEnabled(true)
                }

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
        } catch (e: ActivityNotFoundException) {
            // No browser/handler found — fail immediately instead of leaving
            // the redirect dangling.
            pendingRedirects.remove(nonce)
            pending.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
            callback(Result.failure(FlutterError(
                "ACTIVITY_NOT_FOUND",
                "No activity found to handle URL: ${request.url}",
                null
            )))
        }
    }

    override fun cancel(nonce: String) {
        if (nonce.isEmpty()) {
            cancelAll()
        } else {
            cancelByNonce(nonce)
        }
    }

    override fun supportsCustomTabs(): Boolean {
        return CustomTabsClient.getPackageName(applicationContext, emptyList()) != null
    }

    /** Cancels a single redirect operation by nonce. */
    @VisibleForTesting
    internal fun cancelByNonce(nonce: String) {
        val pending = pendingRedirects.remove(nonce) ?: return
        pending.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        pending.callback.invoke(Result.success(null))
    }

    /** Cancels all pending redirect operations. */
    internal fun cancelAll() {
        val allNonces = pendingRedirects.keys.toList()
        for (n in allNonces) {
            cancelByNonce(n)
        }
    }

    /**
     * Called when a new intent arrives.
     * Matches the intent's URI scheme against pending redirects.
     * Returns `true` if a matching redirect was found and completed.
     */
    fun onNewIntent(intent: Intent): Boolean {
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
}

/**
 * Flutter plugin entry point for Android redirects.
 *
 * Manages the [FlutterPlugin] and [ActivityAware] lifecycle, delegating
 * all redirect logic to [RedirectLauncher].
 */
class RedirectPlugin : FlutterPlugin, ActivityAware, PluginRegistry.NewIntentListener {
    private var launcher: RedirectLauncher? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val l = RedirectLauncher(flutterPluginBinding.applicationContext)
        launcher = l
        RedirectHostApi.setUp(flutterPluginBinding.binaryMessenger, l)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RedirectHostApi.setUp(binding.binaryMessenger, null)
        launcher = null
    }

    // -- Intent handling --

    override fun onNewIntent(intent: Intent): Boolean {
        return launcher?.onNewIntent(intent) ?: false
    }

    // -- Activity lifecycle --

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        launcher?.activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        launcher?.activity = null
        // Don't cancel pending operations during config changes —
        // the activity will be re-attached shortly and the intent
        // listener will be re-registered.
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        launcher?.activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        // Cancel all pending redirects — there's no activity to receive
        // the callback intent anymore.
        launcher?.cancelAll()
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        launcher?.activity = null
    }
}