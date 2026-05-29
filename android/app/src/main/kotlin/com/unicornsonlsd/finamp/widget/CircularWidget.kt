package com.unicornsonlsd.finamp.widget

import android.content.Context
import android.util.Log
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
import com.unicornsonlsd.finamp.MainActivity


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
            buttonGridSize = imageSize - (imageSize / 6)
        }

        Box(
            modifier = GlanceModifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            AlbumArt(context, currentState, GlanceModifier
                .size(imageSize) // Scales the image to the space available
                .cornerRadius(imageSize/2) // Shapes the image into a circle
            )

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
                        FavoriteButton(
                            currentState,
                            backgroundColor = GlanceTheme.colors.secondary,
                            contentColor = GlanceTheme.colors.onSecondary,
                            modifier = GlanceModifier.size(50.dp)
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
                    PlayPauseButton(
                        currentState,
                        backgroundColor = GlanceTheme.colors.primary,
                        contentColor = GlanceTheme.colors.onPrimary,
                        modifier = GlanceModifier.size(55.dp)
                    )
                }
            }
        }
    }
}
