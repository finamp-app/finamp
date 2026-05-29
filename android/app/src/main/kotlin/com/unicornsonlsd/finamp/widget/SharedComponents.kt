package com.unicornsonlsd.finamp.widget

import java.io.File
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.sp
import androidx.glance.appwidget.components.SquareIconButton
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.FontFamily
import androidx.glance.unit.ColorProvider
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Column
import androidx.glance.layout.Alignment
import androidx.glance.layout.fillMaxSize

import es.antonborri.home_widget.actionStartActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import com.unicornsonlsd.finamp.MainActivity
import com.unicornsonlsd.finamp.widget.MediaControls

import com.unicornsonlsd.finamp.R

@Composable
fun PlayPauseButton(
    state: HomeWidgetGlanceState,
    modifier: GlanceModifier = GlanceModifier,
    backgroundColor: ColorProvider = GlanceTheme.colors.widgetBackground,
    contentColor: ColorProvider = GlanceTheme.colors.primary
) {
    var imageProvider = ImageProvider(R.drawable.play_arrow_24px)
    var contentDescription = "play"
    var onClick = actionRunCallback<MediaControls>(
        actionParametersOf(MediaControls.KEY to MediaControls.PLAY)
    )

    val playing = state.preferences.getBoolean("playing", false)
    if (playing) {
        imageProvider = ImageProvider(R.drawable.pause_24px)
        contentDescription = "pause"
        onClick = actionRunCallback<MediaControls>(
            actionParametersOf(MediaControls.KEY to MediaControls.PAUSE)
        )
    }
    SquareIconButton(
        imageProvider = imageProvider,
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = contentDescription,
        modifier = modifier,
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
        onClick = actionRunCallback<MediaControls>(
            actionParametersOf(MediaControls.KEY to MediaControls.NEXT)
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
        onClick = actionRunCallback<MediaControls>(
            actionParametersOf(MediaControls.KEY to MediaControls.PREVIOUS)
        ),
    )
}

@Composable
fun ShuffleButton(
    state: HomeWidgetGlanceState,
    backgroundColor: ColorProvider = GlanceTheme.colors.widgetBackground,
    contentColor: ColorProvider = GlanceTheme.colors.primary
) {
    var imageProvider = ImageProvider(R.drawable.shuffle_24px)
    var contentDescription = "shuffle on"

    val shuffled = state.preferences.getBoolean("shuffled", false)
    if (shuffled) {
        imageProvider = ImageProvider(R.drawable.shuffle_on_24px)
        contentDescription = "shuffle off"
    }

    SquareIconButton(
        imageProvider = imageProvider,
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = contentDescription,
        onClick = actionRunCallback<MediaControls>(
            actionParametersOf(MediaControls.KEY to MediaControls.SHUFFLE)
        )
    )
}

@Composable
fun RepeatButton(
    state: HomeWidgetGlanceState,
    backgroundColor: ColorProvider = GlanceTheme.colors.widgetBackground,
    contentColor: ColorProvider = GlanceTheme.colors.primary
) {
    var imageProvider = ImageProvider(R.drawable.repeat_24px)
    var contentDescription = "repeat off"

    val repeatMode = state.preferences.getString("repeatMode", "")
    if (repeatMode == "all") {
        imageProvider = ImageProvider(R.drawable.repeat_all_24px)
        contentDescription = "repeat all"
    } else if (repeatMode == "one") {
        imageProvider = ImageProvider(R.drawable.repeat_one_24px)
        contentDescription = "repeat single"
    }

    SquareIconButton(
        imageProvider = imageProvider,
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = contentDescription,
        onClick = actionRunCallback<MediaControls>(
            actionParametersOf(MediaControls.KEY to MediaControls.REPEAT)
        ),
    )
}

@Composable
fun FavoriteButton(
    state: HomeWidgetGlanceState,
    modifier: GlanceModifier = GlanceModifier,
    backgroundColor: ColorProvider = GlanceTheme.colors.primary,
    contentColor: ColorProvider = GlanceTheme.colors.onPrimary
) {
    val favorited = state.preferences.getBoolean("favorited", false)
    val favIcon = if (favorited) R.drawable.favorite_filled_20px else R.drawable.favorite_20px

    SquareIconButton(
        imageProvider = ImageProvider(favIcon),
        backgroundColor = backgroundColor,
        contentColor = contentColor,
        contentDescription = "toggle favorite",
        modifier = modifier,
        onClick = actionRunCallback<MediaControls>(
            actionParametersOf(MediaControls.KEY to MediaControls.FAVORITE)
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

@Composable
fun NowPlayingText(state: HomeWidgetGlanceState) {
    val artist = state.preferences.getString("arist", "") ?: ""
    val album = state.preferences.getString("album", "") ?: ""
    val title = state.preferences.getString("title", "") ?: ""

    Column(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            maxLines = 1,
            style = TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 22.sp,
                color = GlanceTheme.colors.onSurface
            ),
        )
        Text(
            text = artist,
            maxLines = 1,
            style = TextStyle(
                fontWeight = FontWeight.Medium,
                fontSize = 18.sp,
                color = GlanceTheme.colors.onSurfaceVariant
            ),
        )
        Text(
            text = album,
            maxLines = 1,
            style = TextStyle(
                fontWeight = FontWeight.Normal,
                fontSize = 16.sp,
                color = GlanceTheme.colors.onSurfaceVariant
            ),
        )
    }
}
