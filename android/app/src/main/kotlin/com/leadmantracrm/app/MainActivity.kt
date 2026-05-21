package com.leadmantracrm.app

import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val EVENT_CHANNEL = "com.leadmantracrm.app/call_log_events"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var callLogObserver: ContentObserver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    registerObserver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterObserver()
                    eventSink = null
                }
            })
    }

    private fun registerObserver() {
        callLogObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                eventSink?.success("changed")
            }
        }
        contentResolver.registerContentObserver(
            CallLog.Calls.CONTENT_URI,
            true,
            callLogObserver!!
        )
    }

    private fun unregisterObserver() {
        callLogObserver?.let {
            contentResolver.unregisterContentObserver(it)
            callLogObserver = null
        }
    }

    override fun onDestroy() {
        unregisterObserver()
        super.onDestroy()
    }
}
