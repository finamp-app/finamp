package com.unicornsonlsd.finamp

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
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

        private const val SET_NATIVE_THEME_CHANNEL = "com.unicornsonlsd.finamp/set_native_theme"
        private const val SET_NATIVE_THEME_CHANNEL_LOG_TAG = "setNativeThemeChannel"
    }

    private lateinit var mediaRouter: MediaRouter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        mediaRouter = MediaRouter.getInstance(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
            SET_NATIVE_THEME_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setNativeThemeMode" -> {
                    val uiManager: UiModeManager =
                        getApplicationContext().getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    val targetMode = call.argument<Int?>("targetMode")
                    when (targetMode) {
                        0 -> {
                            uiManager.setApplicationNightMode( UiModeManager.MODE_NIGHT_AUTO)
                            result.success(null)
                        }
                        1 -> {
                            uiManager.setApplicationNightMode( UiModeManager.MODE_NIGHT_NO)
                            result.success(null)
                        }
                        2 -> {
                            uiManager.setApplicationNightMode( UiModeManager.MODE_NIGHT_YES)
                            result.success(null)
                        }
                        else -> {
                            Log.e(SET_NATIVE_THEME_CHANNEL_LOG_TAG, "Method not found: '${call.method}'")
                            result.notImplemented()
                        }
                    }
                }
                else -> {
                    Log.e(SET_NATIVE_THEME_CHANNEL_LOG_TAG, "Method not found: '${call.method}'")
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
