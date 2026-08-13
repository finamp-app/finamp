package com.unicornsonlsd.finamp.sideload

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log

/**
 * Receives PackageInstaller session status when the app process may not have
 * a Flutter MethodChannel listener (e.g. WorkManager silent install).
 */
class SideloadInstallReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SideloadInstallRx"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        Log.i(TAG, "status=$status message=$message")
        when (status) {
            PackageInstaller.STATUS_SUCCESS -> {
                SideloadPrefs.writeResult(context, "install_success")
            }
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                SideloadPrefs.writeResult(
                    context,
                    "pending_user_action",
                    "Complete one-time system Install to become installer of record",
                )
                val confirm = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        context.startActivity(confirm)
                    } catch (e: Exception) {
                        Log.e(TAG, "Could not start confirm intent", e)
                    }
                }
            }
            else -> {
                SideloadPrefs.writeResult(context, "install_failed", message ?: "status=$status")
            }
        }
    }
}
