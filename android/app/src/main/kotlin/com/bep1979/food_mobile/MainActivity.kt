package com.bep1979.food_mobile

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val currentWindow = window ?: return
                val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                } ?: return

                val modes = currentDisplay.supportedModes
                val maxMode = modes.maxByOrNull { it.refreshRate }
                if (maxMode != null) {
                    val params = currentWindow.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    currentWindow.attributes = params
                }
            } catch (_: Exception) {
                // Thiết bị không hỗ trợ thay đổi tần số quét -> bỏ qua
            }
        }
    }
}
