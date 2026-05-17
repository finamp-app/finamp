package com.unicornsonlsd.finamp

import android.util.Log
import io.rebble.pebblekit2.client.BasePebbleListenerService
import io.rebble.pebblekit2.common.model.PebbleDictionary
import io.rebble.pebblekit2.common.model.PebbleDictionaryItem
import io.rebble.pebblekit2.common.model.ReceiveResult
import io.rebble.pebblekit2.common.model.WatchIdentifier
import java.util.UUID

class PebbleListenerService : BasePebbleListenerService() {

    override fun onCreate() {
        super.onCreate()
        Log.d("🪨", "=== PebbleListenerService CREATED ===")
    }

    override fun onAppOpened(watchappUUID: UUID, watch: WatchIdentifier) {
        Log.d("🪨", "Pebble app opened on watch! UUID: $watchappUUID")
    }

    override suspend fun onMessageReceived(
        watchappUUID: UUID,
        data: PebbleDictionary,
        watch: WatchIdentifier
    ): ReceiveResult {

        val cmdItem = data[PebbleHandler.KEY_COMMAND.toUInt()]
        val cmd = (cmdItem as? PebbleDictionaryItem.UInt32)?.value?.toInt() ?: 0

        val indexItem = data[PebbleHandler.KEY_INDEX.toUInt()]
        val index = (indexItem as? PebbleDictionaryItem.Int32)?.value?.toInt() ?: -1

        val textItem = data[PebbleHandler.KEY_DATA.toUInt()]
        val receivedText = (textItem as? PebbleDictionaryItem.Text)?.value ?: ""

        Log.d("🪨", "Pebble command received → cmd: $cmd, index: $index, text: $receivedText")

        // Fixed: safe null check (no more backing-field error)
        PebbleHandler.methodChannel?.invokeMethod("onPebbleCommand", mapOf(
            "command" to cmd,
            "index" to index,
            "data" to receivedText
        )) ?: run {
            Log.w("🪨", "MethodChannel not initialized yet")
        }

        return ReceiveResult.Ack
    }
}