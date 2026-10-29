package ir.rallyto.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPushChannel()
    }

    /**
     * The channel every push is posted to: the server sends `ChannelId = "rallyto"` (FirebasePushGateway), and on
     * Android 8+ a push for a channel the app never created lands in FCM's fallback «Miscellaneous» channel instead.
     * Creating an existing channel again is a no-op, so this runs on every start.
     */
    private fun createPushChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(PUSH_CHANNEL_ID, "اعلان‌های رالیتو", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "بازی‌ها، پیام‌ها و یادآورها"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        const val PUSH_CHANNEL_ID = "rallyto"
    }
}
