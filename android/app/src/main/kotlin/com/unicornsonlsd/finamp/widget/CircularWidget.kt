package com.unicornsonlsd.finamp.widget

import android.content.Context
import android.util.Log
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.DpSize
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.SizeMode
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.appwidget.cornerRadius
import androidx.glance.layout.size
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.LocalSize
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition

import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

import com.unicornsonlsd.finamp.MainActivity
import com.unicornsonlsd.finamp.R


class CircularWidget : GlanceAppWidget() {

    companion object {
        private val LOG_TAG = "CIRCULAR_WIDGET"
        private val MEDIUM_HEIGHT = 180.dp
        private val FAVORITE_SIZE = 50.dp
        private val PLAY_PAUSE_SIZE = 55.dp
    }

    override val sizeMode = SizeMode.Exact

    override val stateDefinition: GlanceStateDefinition<*>?
      get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("finamp://widget_created"))
        backgroundIntent.send()

        provideContent {
            GlanceTheme {
                GlanceContent(context, currentState())
            }
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val size = LocalSize.current
        // Scale the image to the shortest dimension
        val imageSize = if (size.width > size.height) size.height else size.width
        var buttonGridSize = imageSize

        // Scale down the button grid so it doesn't sit outside the circle
        if (imageSize > MEDIUM_HEIGHT) {
            buttonGridSize = imageSize - (imageSize / 6)
        }

        val artist = currentState.preferences.getString("arist", "") ?: ""
        val title = currentState.preferences.getString("title", "") ?: ""
        var artDescription = context.getString(R.string.album_art_description, title, artist)

        Box(
            modifier = GlanceModifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            AlbumArt(
                context,
                currentState,
                contentDescription = artDescription,
                modifier = GlanceModifier.size(imageSize).cornerRadius(imageSize/2)
            )

            // Holds the grid of buttons
            Column(
                modifier = GlanceModifier.size(buttonGridSize),
                verticalAlignment = Alignment.Top
            ) {
                // Top row forces favorite button to the right
                Row(
                    modifier = GlanceModifier.width(buttonGridSize),
                    horizontalAlignment = Alignment.End
                ) {
                    // Hide the favorite button when too small
                    if (size.height >= MEDIUM_HEIGHT) {
                        FavoriteButton(
                            context,
                            currentState,
                            backgroundColor = GlanceTheme.colors.secondary,
                            contentColor = GlanceTheme.colors.onSecondary,
                            modifier = GlanceModifier.size(FAVORITE_SIZE)
                        )
                    }
                }

                // This spacer takes all the space not used by the top/bottom row
                Spacer(modifier = GlanceModifier.defaultWeight())

                // Bottom Row forces play/pause button to the left
                Row(
                    modifier = GlanceModifier.width(buttonGridSize),
                    horizontalAlignment = Alignment.Start
                ) {
                    PlayPauseButton(
                        context,
                        currentState,
                        backgroundColor = GlanceTheme.colors.primary,
                        contentColor = GlanceTheme.colors.onPrimary,
                        modifier = GlanceModifier.size(PLAY_PAUSE_SIZE)
                    )
                }
            }
        }
    }

    override suspend fun onDelete(context: Context, glanceId: GlanceId): Unit {
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("finamp://widget_deleted"))
        backgroundIntent.send()
    }
}
