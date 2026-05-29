package com.unicornsonlsd.finamp.widget

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.SizeMode
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.appwidget.cornerRadius
import androidx.glance.layout.size
import androidx.glance.layout.height
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.LocalSize
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition

import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import com.unicornsonlsd.finamp.MainActivity
import com.unicornsonlsd.finamp.R

class RectangularWidget : GlanceAppWidget() {

    companion object {
        private val HOME_WIDGET_LOG_TAG = "RECTANGULAR_WIDGET"
        private val SMALL_WIDTH = 300.dp
        private val FAVORITE_BUTTON_SIZE = 40.dp
    }

    override val sizeMode = SizeMode.Exact

    // Needed for Updating
    override val stateDefinition: GlanceStateDefinition<*>?
      get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
              GlanceContent(context, currentState())
            }
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val size = LocalSize.current
        // One third of the verical space for media controls
        var buttonGridHeight = size.height / 3
        // Two thirds for now playing info
        val nowPlayingHeight = buttonGridHeight * 2

        val isBig = size.width > SMALL_WIDTH

        // Leaves room for favorite button
        // Since the image will be square can use nowPlayingHeight
        var nowPlayingTextWidth = size.width - nowPlayingHeight
        if (isBig) {
            nowPlayingTextWidth -= FAVORITE_BUTTON_SIZE
        }

        Column(
            verticalAlignment = Alignment.Top,
            modifier = GlanceModifier.fillMaxSize(),
        ) {
            // Now Playing info
            Row(
                modifier = GlanceModifier
                .background(GlanceTheme.colors.inversePrimary)
                .fillMaxWidth()
                .height(nowPlayingHeight)
                .clickable(onClick = actionStartActivity<MainActivity>(
                    context, Uri.parse("finamp://"))
                ),
            ) {
                AlbumArt(context, currentState, GlanceModifier
                    .size(nowPlayingHeight)
                    .cornerRadius(15.dp)
                    .padding(10.dp)
                )
                NowPlayingText(currentState, nowPlayingTextWidth)

                // hide favorite button when too small
                if (isBig) {
                    // This spacer takes all the space not used by the art and track info
                    Spacer(modifier = GlanceModifier.defaultWeight())
                    Column(
                        modifier = GlanceModifier.height(nowPlayingHeight),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        FavoriteButton(
                            currentState,
                            backgroundColor = GlanceTheme.colors.inversePrimary,
                            modifier = GlanceModifier.size(40.dp)
                        )
                    }
                }
            }

            // Media Controls
            Row(
                modifier = GlanceModifier
                .background(GlanceTheme.colors.widgetBackground)
                .fillMaxWidth()
                .height(buttonGridHeight),
                verticalAlignment = Alignment.CenterVertically,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                if (isBig) {
                    RepeatButton(currentState)
                }
                PreviousButton()
                PlayPauseButton(currentState)
                NextButton()
                if (isBig) {
                    ShuffleButton(currentState)
                }
            }
        }
    }
}
