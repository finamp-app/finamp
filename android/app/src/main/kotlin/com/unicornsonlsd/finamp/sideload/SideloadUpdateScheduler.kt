package com.unicornsonlsd.finamp.sideload

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar
import java.util.concurrent.TimeUnit

object SideloadUpdateScheduler {
    private const val TAG = "SideloadScheduler"
    private const val UNIQUE_PERIODIC = "sideload_ota_periodic"
    private const val UNIQUE_ONE_SHOT = "sideload_ota_oneshot"

    fun schedule(context: Context, minutesFromMidnight: Int) {
        val delayMs = millisUntilNext(minutesFromMidnight)
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        // One-shot for the next window, plus a daily periodic as a safety net.
        val oneShot = OneTimeWorkRequestBuilder<SideloadUpdateWorker>()
            .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
            .setConstraints(constraints)
            .addTag(UNIQUE_ONE_SHOT)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_ONE_SHOT,
            ExistingWorkPolicy.REPLACE,
            oneShot,
        )

        val periodic = PeriodicWorkRequestBuilder<SideloadUpdateWorker>(24, TimeUnit.HOURS)
            .setConstraints(constraints)
            .addTag(UNIQUE_PERIODIC)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            UNIQUE_PERIODIC,
            ExistingPeriodicWorkPolicy.UPDATE,
            periodic,
        )
        Log.i(TAG, "Scheduled next Auto OTA in ${delayMs / 1000}s (minutes=$minutesFromMidnight)")
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_ONE_SHOT)
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_PERIODIC)
        Log.i(TAG, "Cancelled Auto OTA schedule")
    }

    fun enqueueOneShot(context: Context) {
        val req = OneTimeWorkRequestBuilder<SideloadUpdateWorker>().build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_ONE_SHOT,
            ExistingWorkPolicy.REPLACE,
            req,
        )
    }

    private fun millisUntilNext(minutesFromMidnight: Int): Long {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutesFromMidnight / 60)
            set(Calendar.MINUTE, minutesFromMidnight % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }
        return target.timeInMillis - now.timeInMillis
    }
}
