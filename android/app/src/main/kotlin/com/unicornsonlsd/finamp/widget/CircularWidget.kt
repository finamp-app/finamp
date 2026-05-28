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
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
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
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
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
            buttonGridSize = imageSize - (imageSize / 8)
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
                        FavoriteButton(currentState)
                    }
                }

                // This spacer takes all the space not used by the top/bottom row
                Spacer(modifier = GlanceModifier.defaultWeight())

                // Bottom Row forces play/pause buttons to the left
                Row(
                    modifier = GlanceModifier.width(buttonGridSize),
                    horizontalAlignment = Alignment.Start
                ) {
                    PlayPauseButton(currentState)
                }
            }
        }
    }
}
