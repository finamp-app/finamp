package com.unicornsonlsd.finamp.sideload

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Flutter MethodChannel for sideload OTA: install permission status,
 * PackageInstaller silent self-update, and Auto schedule sync.
 */
class SideloadUpdateChannel(
    private val context: Context,
    private val activityStarter: (Intent) -> Unit,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.unicornsonlsd.finamp/sideload_update"
        private const val TAG = "SideloadUpdate"
        const val ACTION_INSTALL_STATUS = "com.unicornsonlsd.finamp.SIDELOAD_INSTALL_STATUS"
        const val PREFS = "sideload_ota"
    }

    private var pendingResult: MethodChannel.Result? = null
    private var receiverRegistered = false

    private val installReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
            val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
            Log.i(TAG, "Install status=$status message=$message")
            val result = pendingResult
            pendingResult = null
            when (status) {
                PackageInstaller.STATUS_SUCCESS -> {
                    result?.success(mapOf("ok" to true, "status" to "success"))
                }
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_INTENT)
                    }
                    if (confirm != null) {
                        confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        activityStarter(confirm)
                        result?.success(
                            mapOf(
                                "ok" to false,
                                "status" to "pendingUserAction",
                                "message" to "System install confirmation shown",
                            ),
                        )
                    } else {
                        result?.error("PENDING_USER_ACTION", message ?: "User action required", null)
                    }
                }
                else -> {
                    result?.error("INSTALL_FAILED", message ?: "status=$status", mapOf("status" to status))
                }
            }
        }
    }

    fun ensureReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(ACTION_INSTALL_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.registerReceiver(
                context,
                installReceiver,
                filter,
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(installReceiver, filter)
        }
        receiverRegistered = true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canRequestPackageInstalls" -> {
                result.success(canRequestPackageInstalls())
            }
            "openInstallUnknownAppsSettings" -> {
                openInstallUnknownAppsSettings()
                result.success(null)
            }
            "getInstallerPackageName" -> {
                result.success(installerPackageName())
            }
            "isSelfInstallerOfRecord" -> {
                val installer = installerPackageName()
                result.success(installer != null && installer == context.packageName)
            }
            "getVersionCode" -> {
                result.success(currentVersionCode())
            }
            "syncSchedule" -> {
                val mode = call.argument<String>("mode") ?: "auto"
                val minutes = call.argument<Int>("minutes") ?: (3 * 60 + 33)
                val allowCellular = call.argument<Boolean>("allowCellular") ?: false
                val manifestUrl = call.argument<String>("manifestUrl")
                val playing = call.argument<Boolean>("playing") ?: false
                SideloadPrefs.write(
                    context,
                    mode = mode,
                    minutes = minutes,
                    allowCellular = allowCellular,
                    manifestUrl = manifestUrl,
                    deferWhilePlaying = playing,
                )
                if (mode == "auto") {
                    SideloadUpdateScheduler.schedule(context, minutes)
                } else {
                    SideloadUpdateScheduler.cancel(context)
                }
                result.success(null)
            }
            "runWorkerNow" -> {
                SideloadUpdateScheduler.enqueueOneShot(context)
                result.success(null)
            }
            "installApk" -> {
                val path = call.argument<String>("path")
                val requireUserAction = call.argument<Boolean>("requireUserAction") ?: false
                if (path.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "path required", null)
                    return
                }
                ensureReceiver()
                if (pendingResult != null) {
                    result.error("BUSY", "Install already in progress", null)
                    return
                }
                pendingResult = result
                try {
                    installApk(File(path), requireUserAction)
                } catch (e: Exception) {
                    pendingResult = null
                    Log.e(TAG, "installApk failed", e)
                    result.error("INSTALL_ERROR", e.message, null)
                }
            }
            "getLastWorkerStatus" -> {
                result.success(SideloadPrefs.readStatus(context))
            }
            else -> result.notImplemented()
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallUnknownAppsSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activityStarter(intent)
        }
    }

    private fun installerPackageName(): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getInstallerPackageName(context.packageName)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun currentVersionCode(): Long {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun installApk(apk: File, requireUserAction: Boolean) {
        if (!apk.isFile) {
            throw IllegalArgumentException("APK not found: ${apk.absolutePath}")
        }
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val action = if (requireUserAction) {
                PackageInstaller.SessionParams.USER_ACTION_REQUIRED
            } else {
                PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED
            }
            params.setRequireUserAction(action)
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("package", 0, apk.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val callback = Intent(ACTION_INSTALL_STATUS).apply {
                setPackage(context.packageName)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val pending = PendingIntent.getBroadcast(context, sessionId, callback, flags)
            session.commit(pending.intentSender)
        }
    }
}

object SideloadPrefs {
    private const val PREFS = SideloadUpdateChannel.PREFS

    fun write(
        context: Context,
        mode: String,
        minutes: Int,
        allowCellular: Boolean,
        manifestUrl: String?,
        deferWhilePlaying: Boolean,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("mode", mode)
            .putInt("minutes", minutes)
            .putBoolean("allowCellular", allowCellular)
            .putString("manifestUrl", manifestUrl)
            .putBoolean("deferWhilePlaying", deferWhilePlaying)
            .apply()
    }

    fun readStatus(context: Context): Map<String, Any?> {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "lastRunAt" to p.getLong("lastRunAt", 0L),
            "lastResult" to p.getString("lastResult", null),
            "lastError" to p.getString("lastError", null),
            "lastInstalledBuild" to p.getLong("lastInstalledBuild", 0L),
            "pendingNotifyVersion" to p.getString("pendingNotifyVersion", null),
        )
    }

    fun writeResult(
        context: Context,
        result: String,
        error: String? = null,
        installedBuild: Long? = null,
        notifyVersion: String? = null,
    ) {
        val ed = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("lastRunAt", System.currentTimeMillis())
            .putString("lastResult", result)
            .putString("lastError", error)
        if (installedBuild != null) ed.putLong("lastInstalledBuild", installedBuild)
        if (notifyVersion != null) ed.putString("pendingNotifyVersion", notifyVersion)
        ed.apply()
    }

    fun clearPendingNotify(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove("pendingNotifyVersion")
            .apply()
    }

    fun mode(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("mode", "auto") ?: "auto"

    fun minutes(context: Context): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("minutes", 3 * 60 + 33)

    fun allowCellular(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("allowCellular", false)

    fun manifestUrl(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("manifestUrl", null)

    fun deferWhilePlaying(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("deferWhilePlaying", false)
}
