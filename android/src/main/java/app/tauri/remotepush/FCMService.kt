package app.tauri.remotepush

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class FCMService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        PushNotificationPlugin.dispatchMessage(remoteMessage)
    }

    override fun onNewToken(token: String) {
        PushNotificationPlugin.dispatchNewToken(token)
    }
} 