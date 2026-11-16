package com.unicornsonlsd.finamp

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
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
    }

    private var browser: MediaBrowserCompat? = null

    override fun onClick() {
        super.onClick()
        val audioService = ComponentName(this, AudioService::class.java)

        // A bound-only AudioService is destroyed on unbind, before Dart has time to start playback.
        try {
            startService(Intent().setComponent(audioService))
        } catch (e: IllegalStateException) {
            Log.w(LOG_TAG, "Could not start AudioService", e)
        }

        browser?.disconnect()
        browser = MediaBrowserCompat(this, audioService, object : MediaBrowserCompat.ConnectionCallback() {
            override fun onConnected() {
                val connected = browser ?: return
                MediaControllerCompat(this@PlaybackTileService, connected.sessionToken)
                    .transportControls.sendCustomAction(TOGGLE_ACTION, null)
                connected.disconnect()
                browser = null
            }

            override fun onConnectionFailed() {
                Log.w(LOG_TAG, "Could not connect to AudioService")
                browser = null
            }
        }, null).also { it.connect() }
    }

    override fun onStartListening() {
        super.onStartListening()
        // Don't bind when the app isn't running: binding starts AudioService, which boots Flutter.
        if (FlutterEngineCache.getInstance().get(AudioServicePlugin.getFlutterEngineId()) == null) {
            updateTile(null)
            return
        }
        stateBrowser?.disconnect()
        stateBrowser = MediaBrowserCompat(
            this,
            ComponentName(this, AudioService::class.java),
            object : MediaBrowserCompat.ConnectionCallback() {
                override fun onConnected() {
                    val connected = stateBrowser ?: return
                    stateController = MediaControllerCompat(this@PlaybackTileService, connected.sessionToken).also {
                        it.registerCallback(stateCallback)
                        updateTile(it)
                    }
                }
            },
            null,
        ).also { it.connect() }
    }

    override fun onStopListening() {
        stopObservingState()
        super.onStopListening()
    }

    override fun onDestroy() {
        browser?.disconnect()
        browser = null
        stopObservingState()
        super.onDestroy()
    }

    private var stateBrowser: MediaBrowserCompat? = null
    private var stateController: MediaControllerCompat? = null

    private val stateCallback = object : MediaControllerCompat.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) = updateTile(stateController)
        override fun onMetadataChanged(metadata: MediaMetadataCompat?) = updateTile(stateController)
    }

    private fun stopObservingState() {
        stateController?.unregisterCallback(stateCallback)
        stateController = null
        stateBrowser?.disconnect()
        stateBrowser = null
    }

    private fun updateTile(controller: MediaControllerCompat?) {
        val tile = qsTile ?: return
        val playing = controller?.playbackState?.state == PlaybackStateCompat.STATE_PLAYING
        tile.state = if (playing) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = controller?.metadata?.getString(MediaMetadataCompat.METADATA_KEY_TITLE)
        }
        tile.updateTile()
    }
}
