package com.bdayadev

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.kotlin.any
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [RedirectLauncher].
 *
 * Uses Robolectric for Android framework classes (Context, Intent, Uri)
 * and Mockito for Activity mocking.
 */
@RunWith(RobolectricTestRunner::class)
class RedirectLauncherTest {
    private lateinit var launcher: RedirectLauncher
    private lateinit var mockActivity: Activity

    @Before
    fun setUp() {
        launcher = RedirectLauncher(ApplicationProvider.getApplicationContext())
        mockActivity = mock(Activity::class.java)
        launcher.activity = mockActivity
    }

    // ── run() — basic request handling ──────────────────────

    @Test
    fun `run fails when no activity is set`() {
        launcher.activity = null

        var error: Throwable? = null
        launcher.run(createRunRequest()) { result ->
            error = result.exceptionOrNull()
        }

        assertNotNull(error)
        assertTrue(error is FlutterError)
        assertEquals("NO_ACTIVITY", (error as FlutterError).code)
    }

    @Test
    fun `run opens Custom Tabs by default`() {
        var callbackResult: Result<String?>? = null
        launcher.run(createRunRequest()) { result ->
            callbackResult = result
        }

        // The redirect should be pending (waiting for callback intent).
        assertTrue(launcher.pendingRedirects.containsKey("test-nonce"))

        // Callback should NOT have been invoked yet (waiting for redirect).
        assertNull(callbackResult)
    }

    @Test
    fun `run opens plain intent when useCustomTabs is false`() {
        val request = createRunRequest(
            androidOptions = AndroidOptions(
                useCustomTabs = false,
                showTitle = false,
                enableUrlBarHiding = false,
            ),
        )

        launcher.run(request) { /* unused */ }

        // For plain intent (non-Custom Tabs), startActivity(Intent) is called.
        val intentCaptor = ArgumentCaptor.forClass(Intent::class.java)
        verify(mockActivity).startActivity(intentCaptor.capture())

        val intent = intentCaptor.value
        assertEquals(Intent.ACTION_VIEW, intent.action)
        assertEquals(Uri.parse("https://example.com/authorize"), intent.data)
    }

    @Test
    fun `run registers pending redirect with correct nonce`() {
        val nonce = "unique-nonce-123"
        launcher.run(createRunRequest(nonce = nonce)) { /* unused */ }

        assertTrue(launcher.pendingRedirects.containsKey(nonce))
        assertEquals(1, launcher.pendingRedirects.size)
    }

    @Test
    fun `run fails immediately when ActivityNotFoundException is thrown`() {
        // Use plain intent path (non-Custom Tabs) to test ActivityNotFoundException
        // since CustomTabsIntent.launchUrl has a complex internal call chain.
        doThrow(ActivityNotFoundException("No browser"))
            .`when`(mockActivity).startActivity(any())

        var error: Throwable? = null
        launcher.run(createRunRequest(
            androidOptions = AndroidOptions(
                useCustomTabs = false,
                showTitle = false,
                enableUrlBarHiding = false,
            ),
        )) { result ->
            error = result.exceptionOrNull()
        }

        assertNotNull(error)
        assertTrue(error is FlutterError)
        assertEquals("ACTIVITY_NOT_FOUND", (error as FlutterError).code)
    }

    @Test
    fun `run cancels existing redirect with same nonce`() {
        var firstResult: Result<String?>? = null
        launcher.run(createRunRequest(nonce = "abc")) { result ->
            firstResult = result
        }

        // Second run with the same nonce should cancel the first.
        launcher.run(createRunRequest(nonce = "abc")) { /* unused */ }

        assertNotNull(firstResult)
        assertTrue(firstResult!!.isSuccess)
        assertNull(firstResult!!.getOrNull()) // Cancelled → null
    }

    // ── onNewIntent() — callback matching ──────────────────

    @Test
    fun `onNewIntent returns false for null data`() {
        val intent = Intent()
        assertFalse(launcher.onNewIntent(intent))
    }

    @Test
    fun `onNewIntent returns false for unmatched scheme`() {
        launcher.run(createRunRequest(callbackUrlScheme = "myapp")) { /* unused */ }

        val intent = Intent().apply {
            data = Uri.parse("otherapp://callback?code=abc")
        }
        assertFalse(launcher.onNewIntent(intent))
    }

    @Test
    fun `onNewIntent matches pending redirect by scheme`() {
        var callbackResult: Result<String?>? = null
        launcher.run(createRunRequest(callbackUrlScheme = "myapp")) { result ->
            callbackResult = result
        }

        val callbackUri = "myapp://callback?code=test123"
        val intent = Intent().apply { data = Uri.parse(callbackUri) }
        val handled = launcher.onNewIntent(intent)

        assertTrue(handled)
        assertNotNull(callbackResult)
        assertTrue(callbackResult!!.isSuccess)
        assertEquals(callbackUri, callbackResult!!.getOrNull())
    }

    @Test
    fun `onNewIntent only matches the first pending for a given scheme`() {
        var result1: Result<String?>? = null
        var result2: Result<String?>? = null

        launcher.run(createRunRequest(nonce = "n1", callbackUrlScheme = "myapp")) { result ->
            result1 = result
        }
        launcher.run(createRunRequest(nonce = "n2", callbackUrlScheme = "myapp")) { result ->
            result2 = result
        }

        val intent = Intent().apply { data = Uri.parse("myapp://callback?code=xyz") }
        launcher.onNewIntent(intent)

        // First match wins.
        assertNotNull(result1)
        assertNull(result2)
    }

    // ── cancel() ────────────────────────────────────────────

    @Test
    fun `cancel by nonce completes callback with null`() {
        var callbackResult: Result<String?>? = null
        launcher.run(createRunRequest(nonce = "cancel-me")) { result ->
            callbackResult = result
        }

        launcher.cancel("cancel-me")

        assertNotNull(callbackResult)
        assertTrue(callbackResult!!.isSuccess)
        assertNull(callbackResult!!.getOrNull())
    }

    @Test
    fun `cancel all completes all pending callbacks`() {
        val results = mutableListOf<Result<String?>>()

        launcher.run(createRunRequest(nonce = "a")) { results.add(it) }
        launcher.run(createRunRequest(nonce = "b")) { results.add(it) }
        launcher.run(createRunRequest(nonce = "c")) { results.add(it) }

        launcher.cancel("") // Empty nonce → cancel all

        assertEquals(3, results.size)
        results.forEach { result ->
            assertTrue(result.isSuccess)
            assertNull(result.getOrNull())
        }
    }

    @Test
    fun `cancel nonexistent nonce is a no-op`() {
        // Should not throw.
        launcher.cancel("nonexistent")
    }

    // ── supportsCustomTabs() ────────────────────────────────

    @Test
    fun `supportsCustomTabs returns a boolean`() {
        // Robolectric may or may not resolve Custom Tabs support,
        // but the method should not throw.
        val result = launcher.supportsCustomTabs()
        // We only assert it returns a Boolean (true or false).
        assertTrue(result is Boolean)
    }

    // ── pendingRedirects state ──────────────────────────────

    @Test
    fun `pending redirect is removed after onNewIntent`() {
        launcher.run(createRunRequest(nonce = "rem", callbackUrlScheme = "myapp")) { /* unused */ }

        val intent = Intent().apply { data = Uri.parse("myapp://callback") }
        launcher.onNewIntent(intent)

        // Internal map should be empty now.
        assertTrue(launcher.pendingRedirects.isEmpty())
    }

    @Test
    fun `pending redirect is removed after cancel`() {
        launcher.run(createRunRequest(nonce = "rem2")) { /* unused */ }

        launcher.cancelByNonce("rem2")

        assertTrue(launcher.pendingRedirects.isEmpty())
    }

    // ── Helper ──────────────────────────────────────────────

    private fun createRunRequest(
        nonce: String = "test-nonce",
        url: String = "https://example.com/authorize",
        callbackUrlScheme: String = "testapp",
        preferEphemeral: Boolean = false,
        timeoutMillis: Long? = null,
        androidOptions: AndroidOptions = AndroidOptions(
            useCustomTabs = true,
            showTitle = false,
            enableUrlBarHiding = false,
        ),
    ): RunRequest {
        return RunRequest(
            nonce = nonce,
            url = url,
            callbackUrlScheme = callbackUrlScheme,
            preferEphemeral = preferEphemeral,
            timeoutMillis = timeoutMillis,
            androidOptions = androidOptions,
        )
    }
}
