package com.unicornsonlsd.finamp.widget

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.DpSize
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.components.SquareIconButton
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.appwidget.cornerRadius
import androidx.glance.layout.size
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.Button
import androidx.glance.LocalSize
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.width
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.state.GlanceStateDefinition
import java.io.File
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import com.unicornsonlsd.finamp.MainActivity
import com.unicornsonlsd.finamp.R

private val playerActionKey = ActionParameters.Key<String>(
  PlayerAction.KEY,
);

class CircularWidget : GlanceAppWidget() {

    companion object {
        private val MEDIUM_SQUARE = DpSize(180.dp, 180.dp)
        private val HOME_WIDGET_LOG_TAG = "CIRCULAR_WIDGET"
    }

    override val sizeMode = SizeMode.Exact

    // Needed for Updating
    override val stateDefinition: GlanceStateDefinition<*>?
      get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
      provideContent {
        GlanceContent(context, currentState())
      }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val size = LocalSize.current
        // Scale the image to the shortest dimension
        val imageSize = if (size.width > size.height) size.height else size.width
        var buttonGridSize = imageSize

        // Scale down the button grid so it doesn't sit outside the circle
        if (imageSize > MEDIUM_SQUARE.height) {
            buttonGridSize = imageSize - (imageSize / 8)
        }

        // prefs holds the data sent from Flutter
        val prefs = currentState.preferences
        val playing = prefs.getBoolean("playing", true)

        val favorited = prefs.getBoolean("favorited", false)
        val favIcon = if (favorited) R.drawable.favorite_filled_20px else R.drawable.favorite_20px

        val imagePath = prefs.getString("albumArt", null)
        val bitmap = imagePath?.takeIf { File(it).isFile }?.let { path -> BitmapFactory.decodeFile(path) }

        Box(
            modifier = GlanceModifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            if (bitmap != null) {
                Image(
                    provider = ImageProvider(bitmap),
                    contentDescription = "album art", // maybe put album name
                    contentScale = ContentScale.Fit, // Fit uses all space while maintaining aspect ratio
                    modifier = GlanceModifier
                    .size(imageSize) // Scales the image to the space available
                    .cornerRadius(imageSize/2) // Shapes the image into a circle
                    // opens the app when clicked
                    .clickable(onClick = actionStartActivity<MainActivity>(
                        context, Uri.parse("finamp://"))
                    ),
                )
            }
            // This Column holds the grid of buttons
            Column(
                modifier = GlanceModifier.size(buttonGridSize),
                verticalAlignment = Alignment.Top
            ) {
                // Top Row forces favorite icon to the right
                Row(
                    modifier = GlanceModifier.width(buttonGridSize),
                    horizontalAlignment = Alignment.End
                ) {
                    // Hide the favorite button when too small
                    if (size.height >= MEDIUM_SQUARE.height) {
                        SquareIconButton(
                            imageProvider = ImageProvider(favIcon),
                            contentDescription = "toggle favorite",
                            onClick = actionRunCallback<PlayerAction>(
                                actionParametersOf(playerActionKey to PlayerAction.FAVORITE)
                            ),
                        )
                    }
                }

                // This spacer takes all the space not used by the top/bottom row
                Spacer(modifier = GlanceModifier.defaultWeight())

                // Bottom Row forces play/pause buttons to the left
                Row(
                    modifier = GlanceModifier.width(buttonGridSize),
                    horizontalAlignment = Alignment.Start
                ) {
                    if (playing) {
                        SquareIconButton(
                            imageProvider = ImageProvider(R.drawable.pause_24px),
                            contentDescription = "pause",
                            onClick = actionRunCallback<PlayerAction>(
                                actionParametersOf(playerActionKey to PlayerAction.PAUSE)
                            ),
                        )
                    } else {
                        SquareIconButton(
                            imageProvider = ImageProvider(R.drawable.play_arrow_24px),
                            contentDescription = "play",
                            onClick = actionRunCallback<PlayerAction>(
                                actionParametersOf(playerActionKey to PlayerAction.PLAY)
                            ),
                        )
                    }
                }
            }
        }
    }
}

class PlayerAction : ActionCallback {
    companion object {
        val KEY: String = "action"
        val PLAY: String = "play"
        val PAUSE: String = "pause"
        val NEXT: String = "skip_next"
        val PREVIOUS: String = "skip_previous"
        val FAVORITE: String = "favorite_toggle"
    }

    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("finamp://" + parameters[playerActionKey]))
        backgroundIntent.send()
    }
}
