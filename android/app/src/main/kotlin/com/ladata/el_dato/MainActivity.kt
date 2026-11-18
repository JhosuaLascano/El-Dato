package com.ladata.el_dato

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_ACTION = "widget_action"
    }

    private var channel: MethodChannel? = null
    private var pendingAction: String? = null

    private fun readAction(i: Intent?): String? {
        val a = i?.getStringExtra(EXTRA_ACTION) ?: return null
        i.removeExtra(EXTRA_ACTION) // que no se repita al rotar o recrear la pantalla
        return a
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        readAction(intent)?.let { pendingAction = it }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "el_dato/widget").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        (call.arguments as? String)?.let {
                            WidgetStore.save(this@MainActivity, it)
                            ElDatoWidgets.refreshAll(this@MainActivity)
                        }
                        result.success(null)
                    }
                    "takeAction" -> {
                        val a = pendingAction
                        pendingAction = null
                        result.success(a)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        readAction(intent)?.let {
            pendingAction = it
            channel?.invokeMethod("action", null)
        }
    }
}
