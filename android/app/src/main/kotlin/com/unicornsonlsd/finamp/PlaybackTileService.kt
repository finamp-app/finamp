package com.unicornsonlsd.finamp

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngineCache

class PlaybackTileService : TileService() {
    companion object {
        private const val LOG_TAG = "PlaybackTileService"

        // Must match CustomPlaybackActions.quickTileToggle in Dart.
        private const val TOGGLE_ACTION = "quickTileToggle"

        private const val RESYNC_DELAY_MS = 10_000L
    }

    private var browser: MediaBrowserCompat? = null
    private var controller: MediaControllerCompat? = null
    private val pendingActions = mutableListOf<(MediaControllerCompat) -> Unit>()
    private var listening = false
    private var hasQueue = false

    // Show the tap's result immediately; the session can take seconds to catch up (e.g. loading shuffle all).
    private var expectedPlaying: Boolean? = null
    private val handler = Handler(Looper.getMainLooper())
    private val resync = Runnable {
        expectedPlaying = null
        updateTile()
    }

    private val sessionCallback = object : MediaControllerCompat.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) = updateTile()
        override fun onMetadataChanged(metadata: MediaMetadataCompat?) = updateTile()
        override fun onQueueChanged(queue: MutableList<MediaSessionCompat.QueueItem>?) {
            hasQueue = !queue.isNullOrEmpty()
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        // Finamp is still starting from an earlier tap, and would treat this one as "play" too.
        if (controller == null && expectedPlaying != null) return

        // Taps can arrive before the session reconnects; the tile's last shown state is the best guess then.
        val playing = when {
            controller != null -> isPlaying()
            !isAppRunning() -> false
            else -> qsTile?.state == Tile.STATE_ACTIVE
        }
        expectedPlaying = !playing
        handler.removeCallbacks(resync)
        updateTile()

        // A bound-only AudioService is destroyed on unbind, before Dart has time to start playback.
        try {
            startService(Intent().setComponent(ComponentName(this, AudioService::class.java)))
        } catch (e: IllegalStateException) {
            Log.w(LOG_TAG, "Could not start AudioService", e)
        }

        withController {
            it.transportControls.sendCustomAction(TOGGLE_ACTION, null)
            handler.postDelayed(resync, RESYNC_DELAY_MS)
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        listening = true
        // Don't bind when the app isn't running: binding starts AudioService, which boots Flutter.
        if (browser == null && !isAppRunning()) {
            updateTile()
            return
        }
        withController {}
    }

    override fun onStopListening() {
        listening = false
        // A cold start can outlast the open shade; deliver the pending tap before disconnecting.
        if (pendingActions.isEmpty()) disconnect()
        super.onStopListening()
    }

    override fun onDestroy() {
        handler.removeCallbacks(resync)
        disconnect()
        super.onDestroy()
    }

    private fun withController(action: (MediaControllerCompat) -> Unit) {
        controller?.let { return action(it) }
        pendingActions += action
        if (browser != null) return

        browser = MediaBrowserCompat(this, ComponentName(this, AudioService::class.java), object : MediaBrowserCompat.ConnectionCallback() {
            override fun onConnected() {
                val connected = MediaControllerCompat(this@PlaybackTileService, browser?.sessionToken ?: return)
                controller = connected
                // The session keeps the last track's metadata after the queue is cleared, so an empty queue means nothing is loaded.
                hasQueue = !connected.queue.isNullOrEmpty()
                connected.registerCallback(sessionCallback)
                updateTile()
                pendingActions.toList().also { pendingActions.clear() }.forEach { it(connected) }
                if (!listening) disconnect()
            }

            override fun onConnectionFailed() {
                Log.w(LOG_TAG, "Could not connect to AudioService")
                browser = null
                pendingActions.clear()
                expectedPlaying = null
                updateTile()
            }
        }, null).also { it.connect() }
    }

    private fun disconnect() {
        controller?.unregisterCallback(sessionCallback)
        controller = null
        browser?.disconnect()
        browser = null
        pendingActions.clear()
    }

    private fun isAppRunning() = FlutterEngineCache.getInstance().get(AudioServicePlugin.getFlutterEngineId()) != null

    private fun isPlaying(): Boolean {
        val state = controller?.playbackState?.state
        return state == PlaybackStateCompat.STATE_PLAYING || state == PlaybackStateCompat.STATE_BUFFERING
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val playing = isPlaying()
        if (expectedPlaying == playing) {
            expectedPlaying = null
            handler.removeCallbacks(resync)
        }
        tile.state = if (expectedPlaying ?: playing) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (hasQueue) controller?.metadata?.getString(MediaMetadataCompat.METADATA_KEY_TITLE) else null
        }
        tile.updateTile()
    }
}
