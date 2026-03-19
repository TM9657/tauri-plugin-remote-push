package app.tauri.remotepush

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.webkit.WebView
import app.tauri.annotation.Command
import app.tauri.annotation.Permission
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Plugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Collections

val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

internal data class NotificationContent(
    val title: String? = null,
    val body: String? = null,
)

internal data class NotificationPayload(
    val notification: NotificationContent? = null,
    val data: Map<String, String> = emptyMap(),
) {
    fun toJSObject(): JSObject {
        val payload = JSObject()
        notification?.let {
            val notificationObject = JSObject()
            notificationObject.put("title", it.title)
            notificationObject.put("body", it.body)
            payload.put("notification", notificationObject)
        }
        val dataObject = JSObject()
        for ((key, value) in data) {
            dataObject.put(key, value)
        }
        payload.put("data", dataObject)
        return payload
    }

    companion object {
        fun from(message: RemoteMessage): NotificationPayload {
            return NotificationPayload(
                notification = message.notification?.let {
                    NotificationContent(title = it.title, body = it.body)
                },
                data = message.data,
            )
        }
    }
}

@TauriPlugin(
    permissions = [
        Permission(strings = [Manifest.permission.POST_NOTIFICATIONS], alias = "notifications")
    ]
)
class PushNotificationPlugin(private val activity: Activity) : Plugin(activity) {

    companion object {
        @Volatile
        var instance: PushNotificationPlugin? = null

        @Volatile
        private var pendingToken: String? = null

        private val pendingMessages = Collections.synchronizedList(mutableListOf<NotificationPayload>())

        fun dispatchNewToken(token: String) {
            instance?.handleNewToken(token) ?: run {
                pendingToken = token
            }
        }

        fun dispatchMessage(message: RemoteMessage) {
            val payload = NotificationPayload.from(message)
            instance?.handleMessage(payload) ?: run {
                pendingMessages.add(payload)
            }
        }
    }

    private var lastTappedNotificationSignature: String? = null

    override fun load(webView: WebView) {
        super.load(webView)
        instance = this
        pendingToken?.let {
            pendingToken = null
            handleNewToken(it)
        }
        val queuedMessages = synchronized(pendingMessages) {
            pendingMessages.toList().also { pendingMessages.clear() }
        }
        queuedMessages.forEach(::handleMessage)
        emitNotificationTapped(activity.intent)
    }

    @Command
    fun getToken(invoke: Invoke) {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                invoke.reject("Failed to get FCM token", task.exception)
                return@addOnCompleteListener
            }
            val token = task.result
            invoke.resolveObject(token)
        }
    }

    @Command
    override fun requestPermissions(invoke: Invoke) {
        mainScope.launch {
            requestPermissionForAlias("notifications", invoke, "requestPermissionsCallback")
        }
    }

    @app.tauri.annotation.PermissionCallback
    fun requestPermissionsCallback(invoke: Invoke) {
        val state = getPermissionState("notifications")
        val granted = state?.toString()?.lowercase() == "granted"
        val result = JSObject()
        result.put("granted", granted)
        trigger("permissionStateChange", result)
        invoke.resolve(result)
    }

    fun handleNewToken(token: String) {
        val data = JSObject()
        data.put("token", token)
        trigger("token-received", data)
    }

    fun handleMessage(message: RemoteMessage) {
        handleMessage(NotificationPayload.from(message))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        emitNotificationTapped(intent)
    }

    override fun onResume() {
        super.onResume()
        emitNotificationTapped(activity.intent)
    }

    private fun handleMessage(payload: NotificationPayload) {
        trigger("notification-received", payload.toJSObject())
    }

    private fun emitNotificationTapped(intent: Intent?) {
        val extras = intent?.extras ?: return
        if (!looksLikePushIntent(extras)) {
            return
        }

        val signature = extras.keySet().sorted().joinToString("|") { key -> "$key=${extras.get(key)}" }
        if (signature == lastTappedNotificationSignature) {
            return
        }
        lastTappedNotificationSignature = signature

        val data = mutableMapOf<String, String>()
        for (key in extras.keySet()) {
            val value = extras.get(key)?.toString() ?: continue
            if (!key.startsWith("google.") && !key.startsWith("gcm.")) {
                data[key] = value
            }
        }

        val title = extras.getString("gcm.notification.title") ?: extras.getString("google.notification.title")
        val body = extras.getString("gcm.notification.body") ?: extras.getString("google.notification.body")

        val payload = NotificationPayload(
            notification = if (title != null || body != null) NotificationContent(title, body) else null,
            data = data,
        )
        trigger("notification-tapped", payload.toJSObject())
    }

    internal fun looksLikePushIntent(extras: Bundle): Boolean {
        return extras.containsKey("google.message_id")
            || extras.containsKey("message_id")
            || extras.keySet().any { it.startsWith("google.") || it.startsWith("gcm.") }
    }
} 