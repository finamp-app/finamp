package com.unicornsonlsd.finamp

import android.content.Intent
import android.media.MediaExtractor
import android.media.MediaFormat
import java.nio.ByteBuffer
import android.os.Bundle
import android.provider.Settings
import android.system.ErrnoException
import android.system.Os
import android.util.Log
import androidx.annotation.WorkerThread
import androidx.lifecycle.lifecycleScope
import androidx.mediarouter.app.SystemOutputSwitcherDialogController
import androidx.mediarouter.media.MediaRouter
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val DOWNLOADS_SERVICE_CHANNEL = "com.unicornsonlsd.finamp/downloads_service"
        private const val DOWNLOADS_SERVICE_CHANNEL_LOG_TAG = "DownloadsServiceChannel"

        private const val OUTPUT_SWITCHER_CHANNEL = "com.unicornsonlsd.finamp/output_switcher"
        private const val OUTPUT_SWITCHER_CHANNEL_LOG_TAG = "OutputSwitcherChannel"

        private const val CHAPTERS_CHANNEL = "com.unicornsonlsd.finamp/chapters"
        private const val CHAPTERS_CHANNEL_LOG_TAG = "ChaptersChannel"
    }

    private lateinit var mediaRouter: MediaRouter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        mediaRouter = MediaRouter.getInstance(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Chapter extraction — mirrors the iOS AVFoundation implementation.
        // Uses MediaMetadataRetriever to read the MP4 chapter track from a
        // streaming URL, returning the same list format as the iOS channel.
        // I couldnt find a better option than ffmpeg (which is super huge)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHAPTERS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "extractChapters" -> {
                    val url = call.arguments as? String
                    if (url == null) {
                        result.error("INVALID_ARGUMENT", "URL must be a non-null string", null)
                        return@setMethodCallHandler
                    }
                    lifecycleScope.launch {
                        val chapters = withContext(Dispatchers.IO) {
                            extractChapters(url)
                        }
                        result.success(chapters)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOADS_SERVICE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "fixDownloadsFileOwner" -> {
                    val downloadLocations = call.argument<List<String>?>("download_locations").orEmpty()
                    lifecycleScope.launch {
                        withContext(Dispatchers.IO) {
                            fixDownloadsFileOwner(downloadLocations)
                        }
                    }
                    result.success(null)
                }
                else -> {
                    Log.e(DOWNLOADS_SERVICE_CHANNEL_LOG_TAG, "Method not found: '${call.method}'")
                    result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OUTPUT_SWITCHER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            Log.d(OUTPUT_SWITCHER_CHANNEL_LOG_TAG, "Calling method: '${call.method}'")
            when (call.method) {
                "showOutputSwitcherDialog" -> {
                    showOutputSwitcherDialog()
                    result.success(null)
                }
                "getRoutes" -> {
                    val routes = mediaRouter.routes
                    routes.log()
                    result.success(routes.map { route ->
                        mapOf(
                            "name" to route.name,
                            "connectionState" to route.connectionState,
                            "isSystemRoute" to route.isSystemRoute,
                            "isDefault" to route.isDefault,
                            "isDeviceSpeaker" to route.isDeviceSpeaker,
                            "isBluetooth" to route.isBluetooth,
                            "volume" to route.volume,
                            "providerPackageName" to route.provider.packageName,
                            "isSelected" to route.isSelected,
                            "deviceType" to route.deviceType,
                            "description" to route.description,
                            "extras" to route.extras,
                            "iconUri" to route.iconUri,
                            // "controlFilters" to route.controlFilters,
                        )
                    })
                }
                "setOutputToDeviceSpeaker" -> {
                    val routes = mediaRouter.routes
                    routes.log()
                    val deviceSpeakerRoute = routes.first { route -> route.isDeviceSpeaker }
                    mediaRouter.selectRoute(deviceSpeakerRoute)
                    result.success(null)
                }
                "setOutputToBluetoothDevice" -> {
                    val routes = mediaRouter.routes
                    routes.log()
                    val bluetoothRoute = routes.first { route -> route.isBluetooth }
                    mediaRouter.selectRoute(bluetoothRoute)
                    result.success(null)
                }
                "setOutputToRouteByName" -> {
                    val routes = mediaRouter.routes
                    routes.log()
                    val targetRoute = routes.first { route ->
                        route.name == call.argument<String>("name")
                    }
                    mediaRouter.selectRoute(targetRoute)
                    result.success(null)
                }
                "openBluetoothSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                else -> {
                    Log.e(OUTPUT_SWITCHER_CHANNEL_LOG_TAG, "Method not found: '${call.method}'")
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Extracts chapter markers from an MP4/M4B stream at [url] using
     * [MediaExtractor]. Returns a list of maps with "ticks" (100-ns units,
     * matching Jellyfin's tick format) and "name" keys — the same structure
     * returned by the iOS AVFoundation channel.
     *
     * Returns an empty list if the file has no chapter track or on any error.
     */
    @WorkerThread
    private fun extractChapters(url: String): List<Map<String, Any?>> {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(url, emptyMap())

            // Find a timed-text track — M4B stores chapter names there.
            val chapterTrackIndex = (0 until extractor.trackCount).firstOrNull { i ->
                val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: ""
                mime.startsWith("text/")
            } ?: return emptyList()

            extractor.selectTrack(chapterTrackIndex)

            val chapters = mutableListOf<Map<String, Any?>>()
            val buffer = ByteBuffer.allocate(64 * 1024)

            while (true) {
                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break

                // Presentation time is in microseconds; convert to 100-ns ticks (× 10).
                val ticks = extractor.sampleTime * 10L

                // Parse chapter name: 2-byte big-endian length + UTF-8 text.
                val name = if (sampleSize >= 2) {
                    val nameLen = ((buffer[0].toInt() and 0xFF) shl 8) or (buffer[1].toInt() and 0xFF)
                    if (nameLen > 0 && sampleSize >= 2 + nameLen) {
                        val nameBytes = ByteArray(nameLen)
                        buffer.position(2)
                        buffer.get(nameBytes)
                        String(nameBytes, Charsets.UTF_8).takeIf { it.isNotBlank() }
                    } else null
                } else null

                chapters.add(mapOf("ticks" to ticks, "name" to name))
                extractor.advance()
            }

            Log.d(CHAPTERS_CHANNEL_LOG_TAG, "Extracted ${chapters.size} chapter(s) from $url")
            chapters
        } catch (e: Exception) {
            Log.w(CHAPTERS_CHANNEL_LOG_TAG, "Chapter extraction failed for $url: $e")
            emptyList()
        } finally {
            extractor.release()
        }
    }

    /**
     * Fixes the owner of downloaded files.
     *
     * Originally, files downloaded by the app were set to a special "cache" user group,
     * which caused the system to count all downloads as cache files.
     * Manually setting the group to the app's UID (which is equal to the gid) fixes this behavior for past downloads.
     */
    @WorkerThread
    private fun fixDownloadsFileOwner(downloadLocations: List<String>) {
        val appUid = applicationInfo.uid
        val cacheGid = try {
            Os.stat(context.cacheDir.absolutePath).st_gid
        } catch (e: ErrnoException) {
            Log.e(DOWNLOADS_SERVICE_CHANNEL_LOG_TAG, "Failed to get cache directory GID", e)
            return
        }
        for (downloadLocation in downloadLocations) {
            val downloadDirectory = File(downloadLocation)
            if (!downloadDirectory.isDirectory) {
                Log.w(DOWNLOADS_SERVICE_CHANNEL_LOG_TAG, "Download location is not a directory: $downloadLocation")
                continue
            }

            for (file in downloadDirectory.walkTopDown()) {
                try {
                    if (!file.isFile) continue

                    // Skip files not owned by the cache group
                    val gid = Os.stat(file.absolutePath).st_gid
                    if (gid != cacheGid) continue

                    Os.chown(file.absolutePath, -1, appUid) // uid -1 keeps current owner
                } catch (e: ErrnoException) {
                    Log.e(DOWNLOADS_SERVICE_CHANNEL_LOG_TAG, "Failed to fix owner for: ${file.absolutePath}", e)
                }
            }
        }
    }

    private fun List<MediaRouter.RouteInfo>.log() {
        forEach { route ->
            Log.d(
                OUTPUT_SWITCHER_CHANNEL_LOG_TAG,
                "Route: ${route.name}, connection state: ${route.connectionState}, system route: ${route.isSystemRoute}, default: ${route.isDefault}, device speaker: ${route.isDeviceSpeaker}, bluetooth: ${route.isBluetooth}, volume: ${route.volume}, provider: ${route.provider.packageName}"
            )
        }
    }

    private fun showOutputSwitcherDialog() {
        SystemOutputSwitcherDialogController.showDialog(this)
    }
}
