package com.unicornsonlsd.finamp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class PebbleBroadcastReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("🪨", "=== BROADCAST RECEIVED === Action: ${intent.action}")
        Log.d("🪨", "Pebble is trying to send data to us!")

        // Optional: you could start the service manually here if needed
        // val serviceIntent = Intent(context, PebbleListenerService::class.java)
        // context.startService(serviceIntent)
    }
}