package com.unicornsonlsd.finamp.widget

import java.io.File
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.glance.appwidget.components.SquareIconButton
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.unit.ColorProvider
import androidx.glance.layout.ContentScale
import es.antonborri.home_widget.actionStartActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import com.unicornsonlsd.finamp.MainActivity
import com.unicornsonlsd.finamp.widget.PlayerAction

import com.unicornsonlsd.finamp.R

@Composable
fun PlayPauseButton(
    state: HomeWidgetGlanceState,
    backgroundColor: ColorProvider = GlanceTheme.colors.primary,
    contentColor: ColorProvider = GlanceTheme.colors.onPrimary
) {
    var imageProvider = ImageProvider(R.drawable.play_arrow_24px)
    var contentDescription = "play"
    var onClick = actionRunCallback<PlayerAction>(
        actionParametersOf(PlayerAction.KEY to PlayerAction.PLAY)
    )

    val playing = state.preferences.getBoolean("playing", false)
    if (playing) {
        imageProvider = ImageProvider(R.drawable.pause_24px)
        contentDescription = "pause"
        onClick = actionRunCallback<PlayerAction>(
            actionParametersOf(PlayerAction.KEY to PlayerAction.PAUSE)
        )
    }
    SquareIconButton(
        imageProvider = imageProvider,
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = contentDescription,
        onClick = onClick
    )
}

@Composable
fun NextButton(
    backgroundColor: ColorProvider = GlanceTheme.colors.widgetBackground,
    contentColor: ColorProvider = GlanceTheme.colors.primary
) {
    SquareIconButton(
        imageProvider = ImageProvider(R.drawable.skip_next_24px),
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = "skip next",
        onClick = actionRunCallback<PlayerAction>(
            actionParametersOf(PlayerAction.KEY to PlayerAction.NEXT)
        ),
    )
}

@Composable
fun PreviousButton(
    backgroundColor: ColorProvider = GlanceTheme.colors.widgetBackground,
    contentColor: ColorProvider = GlanceTheme.colors.primary
) {
    SquareIconButton(
        imageProvider = ImageProvider(R.drawable.skip_previous_24px),
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = "skip back",
        onClick = actionRunCallback<PlayerAction>(
            actionParametersOf(PlayerAction.KEY to PlayerAction.PREVIOUS)
        ),
    )
}

@Composable
fun ShuffleButton(
    state: HomeWidgetGlanceState,
    backgroundColor: ColorProvider = GlanceTheme.colors.widgetBackground,
    contentColor: ColorProvider = GlanceTheme.colors.primary
) {
    SquareIconButton(
        imageProvider = ImageProvider(R.drawable.shuffle_24px),
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = "shuffle",
        onClick = actionRunCallback<PlayerAction>(
            actionParametersOf(PlayerAction.KEY to PlayerAction.SHUFFLE)
        ),
    )
}

@Composable
fun RepeatButton(
    state: HomeWidgetGlanceState,
    backgroundColor: ColorProvider = GlanceTheme.colors.widgetBackground,
    contentColor: ColorProvider = GlanceTheme.colors.primary
) {
    SquareIconButton(
        imageProvider = ImageProvider(R.drawable.repeat_24px),
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = "repeat",
        onClick = actionRunCallback<PlayerAction>(
            actionParametersOf(PlayerAction.KEY to PlayerAction.REPEAT)
        ),
    )
}

@Composable
fun FavoriteButton(
    state: HomeWidgetGlanceState,
    backgroundColor: ColorProvider = GlanceTheme.colors.primary,
    contentColor: ColorProvider = GlanceTheme.colors.onPrimary
) {
    val favorited = state.preferences.getBoolean("favorited", false)
    val favIcon = if (favorited) R.drawable.favorite_filled_20px else R.drawable.favorite_20px

    SquareIconButton(
        imageProvider = ImageProvider(favIcon),
        contentDescription = "toggle favorite",
        onClick = actionRunCallback<PlayerAction>(
            actionParametersOf(PlayerAction.KEY to PlayerAction.FAVORITE)
        ),
    )
}

@Composable
fun AlbumArt(
    context: Context,
    state: HomeWidgetGlanceState,
    modifier: GlanceModifier,
) {
    val imagePath = state.preferences.getString("albumArt", null)
    val bitmap = imagePath?.takeIf { File(it).isFile }?.let { path -> BitmapFactory.decodeFile(path) }

    if (bitmap != null) {
        Image(
            provider = ImageProvider(bitmap),
            contentDescription = "album art", // maybe put album name
            contentScale = ContentScale.Fit, // Fit uses all space while maintaining aspect ratio
            modifier = modifier
            // opens the app when clicked
            .clickable(onClick = actionStartActivity<MainActivity>(
                context, Uri.parse("finamp://"))
            ),
        )
    }
}
