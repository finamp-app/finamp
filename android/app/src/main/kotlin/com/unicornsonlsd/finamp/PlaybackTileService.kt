package com.unicornsonlsd.finamp

import android.content.ComponentName
import android.content.Intent
import android.service.quicksettings.TileService
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat
import android.util.Log
import com.ryanheise.audioservice.AudioService

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

    override fun onDestroy() {
        browser?.disconnect()
        browser = null
        super.onDestroy()
    }
}
