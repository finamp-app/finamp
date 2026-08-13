package com.unicornsonlsd.finamp.sideload

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Background Auto OTA: fetch latest.json, download APK if newer, silent
 * PackageInstaller self-update when permitted.
 */
class SideloadUpdateWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    companion object {
        private const val TAG = "SideloadWorker"
        private const val DEFAULT_MANIFEST =
            "https://github.com/itdir/finamp/releases/download/sideload-latest/latest.json"
        private const val ACTION_INSTALL_STATUS =
            "com.unicornsonlsd.finamp.SIDELOAD_INSTALL_STATUS"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            if (SideloadPrefs.mode(applicationContext) != "auto") {
                return@withContext Result.success()
            }
            if (SideloadPrefs.deferWhilePlaying(applicationContext)) {
                SideloadPrefs.writeResult(applicationContext, "deferred_playing")
                // Reschedule soon; catch-up on next launch also handles this.
                SideloadUpdateScheduler.enqueueOneShot(applicationContext)
                return@withContext Result.success()
            }
            if (!networkAllowed()) {
                SideloadPrefs.writeResult(applicationContext, "skipped_metered")
                return@withContext Result.retry()
            }

            val manifestUrl = SideloadPrefs.manifestUrl(applicationContext)?.takeIf { it.isNotBlank() }
                ?: DEFAULT_MANIFEST
            val json = fetchJson(manifestUrl)
            val remoteBuild = json.getLong("build")
            val version = json.optString("version", "")
            val android = json.getJSONObject("android")
            val apkUrl = android.getString("apkUrl")
            val sha256 = android.getString("sha256")
            val sizeBytes = android.optLong("sizeBytes", 0L)

            val localBuild = currentVersionCode()
            if (remoteBuild <= localBuild) {
                SideloadPrefs.writeResult(applicationContext, "up_to_date")
                reschedule()
                return@withContext Result.success()
            }

            if (!canRequestPackageInstalls()) {
                SideloadPrefs.writeResult(
                    applicationContext,
                    "need_install_permission",
                    "Allow installs from Finamp",
                )
                reschedule()
                return@withContext Result.success()
            }

            val apk = File(applicationContext.cacheDir, "sideload-update.apk")
            if (apk.exists()) apk.delete()
            downloadFile(apkUrl, apk, sizeBytes)
            val actual = sha256File(apk)
            if (!actual.equals(sha256, ignoreCase = true)) {
                apk.delete()
                SideloadPrefs.writeResult(
                    applicationContext,
                    "sha_mismatch",
                    "Expected $sha256 got $actual",
                )
                return@withContext Result.failure()
            }

            installApkSilent(apk)
            SideloadPrefs.writeResult(
                applicationContext,
                "installed",
                installedBuild = remoteBuild,
                notifyVersion = version.ifBlank { remoteBuild.toString() },
            )
            // Process may be killed for update; schedule is restored on next launch.
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Worker failed", e)
            SideloadPrefs.writeResult(applicationContext, "error", e.message)
            Result.retry()
        }
    }

    private fun reschedule() {
        val minutes = SideloadPrefs.minutes(applicationContext)
        SideloadUpdateScheduler.schedule(applicationContext, minutes)
    }

    private fun networkAllowed(): Boolean {
        val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return false
        if (SideloadPrefs.allowCellular(applicationContext)) return true
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            applicationContext.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun currentVersionCode(): Long {
        val info = applicationContext.packageManager.getPackageInfo(applicationContext.packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun fetchJson(url: String): JSONObject {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 30_000
            readTimeout = 60_000
            instanceFollowRedirects = true
            requestMethod = "GET"
        }
        conn.inputStream.bufferedReader().use { reader ->
            return JSONObject(reader.readText())
        }
    }

    private fun downloadFile(url: String, dest: File, expectedSize: Long) {
        val free = dest.parentFile?.usableSpace ?: Long.MAX_VALUE
        if (expectedSize > 0 && free < expectedSize + 50_000_000L) {
            throw IllegalStateException("Not enough free space for APK download")
        }
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 30_000
            readTimeout = 120_000
            instanceFollowRedirects = true
            requestMethod = "GET"
        }
        conn.inputStream.use { input ->
            dest.outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }

    private fun sha256File(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(8192)
            while (true) {
                val n = input.read(buf)
                if (n <= 0) break
                digest.update(buf, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun installApkSilent(apk: File) {
        val installer = applicationContext.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
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
                setPackage(applicationContext.packageName)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val pending = PendingIntent.getBroadcast(applicationContext, sessionId, callback, flags)
            session.commit(pending.intentSender)
        }
    }
}
