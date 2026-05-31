package com.unicornsonlsd.finamp.widget

import android.content.Context
import android.net.Uri
import androidx.glance.action.ActionParameters
import androidx.glance.GlanceId
import androidx.glance.appwidget.action.ActionCallback
import es.antonborri.home_widget.HomeWidgetBackgroundIntent



class MediaControls : ActionCallback {
    companion object {
        val PLAY: String = "play"
        val PAUSE: String = "pause"
        val NEXT: String = "skip_next"
        val PREVIOUS: String = "skip_previous"
        val FAVORITE: String = "favorite_toggle"
        val REPEAT: String = "toggle_loop"
        val SHUFFLE: String = "shuffle_toggle"

        val KEY = ActionParameters.Key<String>(
          "action",
        );
    }

    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("finamp://" + parameters[KEY]))
        backgroundIntent.send()
    }
}
