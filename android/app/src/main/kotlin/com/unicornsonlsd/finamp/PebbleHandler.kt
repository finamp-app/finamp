package com.unicornsonlsd.finamp

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall          // ← This was missing
import io.flutter.plugin.common.MethodChannel
import io.rebble.pebblekit2.client.DefaultPebbleAndroidAppPicker
import io.rebble.pebblekit2.client.DefaultPebbleSender
import io.rebble.pebblekit2.common.model.PebbleDictionaryItem
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class PebbleHandler(private val context: Context) : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val APP_UUID = UUID.fromString("a6b65413-a612-4b61-8fb0-a2cf2a34525d")

    companion object {
        const val KEY_COMMAND = 0
        const val KEY_DATA = 1
        const val KEY_INDEX = 2

        // Nullable so we can safely access from the service
        var methodChannel: MethodChannel? = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "finamp/pebble")
        methodChannel = channel
        channel.setMethodCallHandler(this)

        // === Grant permission for Core Pebble app to talk to us ===
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val picker = DefaultPebbleAndroidAppPicker.getInstance(context)
                picker.enableAutoSelect = true

                // Try release package first
                try {
                    picker.selectApp("com.unicornsonlsd.finamp")
                    Log.d("🪨", "Pebble permission granted for RELEASE package")
                } catch (e: Exception) {
                    Log.w("🪨", "Release package not recognized", e)
                }

                // Try debug package
                try {
                    picker.selectApp(context.packageName)
                    Log.d("🪨", "Pebble permission granted for DEBUG package: ${context.packageName}")
                } catch (e: Exception) {
                    Log.w("🪨", "Debug package not recognized", e)
                }

            } catch (e: Exception) {
                Log.e("🪨", "Failed to configure Pebble permission", e)
            }
        }

        // Start the listener service
        val serviceIntent = Intent(context, PebbleListenerService::class.java)
        context.startService(serviceIntent)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sendDataToPebble" -> {
                val text = call.argument<String>("data") ?: "Hello from Finamp!"
                CoroutineScope(Dispatchers.Main).launch {
                    val sender = DefaultPebbleSender(context)
                    try {
                        val dataToSend = mapOf(
                            KEY_DATA.toUInt() to PebbleDictionaryItem.Text(text)
                        )
                        withContext(Dispatchers.IO) {
                            sender.sendDataToPebble(APP_UUID, dataToSend)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("PEBBLE_SEND_ERROR", e.message, null)
                    } finally {
                        sender.close()
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        methodChannel = null
    }
}