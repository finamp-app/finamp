package com.unicornsonlsd.finamp.androidstartup

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FinampAndroidStartupPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.unicornsonlsd.finamp/android_startup"
        private const val LOG_TAG = "FinampStartupState"
    }

    private lateinit var applicationContext: Context
    private lateinit var channel: MethodChannel
    private val userPresentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_USER_PRESENT) {
                AndroidStartupState.recordUserPresent(context)
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            applicationContext.registerReceiver(userPresentReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            applicationContext.registerReceiver(userPresentReceiver, filter)
        }
        Log.i(LOG_TAG, "Registered dynamic ACTION_USER_PRESENT receiver")
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStartupState" -> {
                val keyguardManager = applicationContext.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                val now = System.currentTimeMillis()
                val uptime = SystemClock.elapsedRealtime()
                @Suppress("DEPRECATION")
                val packageInfo = applicationContext.packageManager.getPackageInfo(applicationContext.packageName, 0)
                val lastUpdateTime = packageInfo.lastUpdateTime
                val lastUserPresentTime = AndroidStartupState.lastUserPresentMillis(applicationContext)
                val bootStartedAt = now - uptime
                val isKeyguardLocked = keyguardManager.isKeyguardLocked
                val state = mapOf(
                    "isKeyguardLocked" to isKeyguardLocked,
                    "uptimeMillis" to uptime,
                    "packageUpdateAgeMillis" to (now - lastUpdateTime).coerceAtLeast(0L),
                    "userPresentSinceBoot" to (lastUserPresentTime >= bootStartedAt),
                    "userPresentSinceUpdate" to (lastUserPresentTime >= lastUpdateTime),
                )
                Log.i(
                    LOG_TAG,
                    "Startup state: keyguardLocked=$isKeyguardLocked, uptimeMillis=$uptime, " +
                        "packageUpdateAgeMillis=${state["packageUpdateAgeMillis"]}, " +
                        "userPresentSinceBoot=${state["userPresentSinceBoot"]}, " +
                        "userPresentSinceUpdate=${state["userPresentSinceUpdate"]}",
                )
                result.success(state)
            }
            else -> {
                Log.e(LOG_TAG, "Method not found: '${call.method}'")
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext.unregisterReceiver(userPresentReceiver)
        channel.setMethodCallHandler(null)
    }
}

/** Stores only the timestamp needed to tell whether a user unlocked after boot or an update. */
internal object AndroidStartupState {
    private const val LOG_TAG = "FinampStartupState"
    private const val PREFERENCES = "finamp_android_startup"
    private const val LAST_USER_PRESENT_MILLIS = "last_user_present_millis"

    fun recordUserPresent(context: Context) {
        val now = System.currentTimeMillis()
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putLong(LAST_USER_PRESENT_MILLIS, now)
            .apply()
        Log.i(LOG_TAG, "ACTION_USER_PRESENT received at wallClockMillis=$now")
    }

    fun lastUserPresentMillis(context: Context): Long =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getLong(LAST_USER_PRESENT_MILLIS, 0L)
}
