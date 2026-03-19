package app.tauri.remotepush

import app.tauri.plugin.JSObject
import org.junit.Assert.*
import org.junit.Test

class NotificationPayloadTest {

    @Test
    fun toJSObject_fullPayload() {
        val payload = NotificationPayload(
            notification = NotificationContent(title = "Hello", body = "World"),
            data = mapOf("key1" to "value1", "key2" to "value2"),
        )

        val result = payload.toJSObject()

        val notification = result.getJSONObject("notification")
        assertEquals("Hello", notification.getString("title"))
        assertEquals("World", notification.getString("body"))

        val data = result.getJSONObject("data")
        assertEquals("value1", data.getString("key1"))
        assertEquals("value2", data.getString("key2"))
    }

    @Test
    fun toJSObject_noNotification() {
        val payload = NotificationPayload(
            notification = null,
            data = mapOf("action" to "sync"),
        )

        val result = payload.toJSObject()

        assertFalse(result.has("notification"))
        val data = result.getJSONObject("data")
        assertEquals("sync", data.getString("action"))
    }

    @Test
    fun toJSObject_emptyData() {
        val payload = NotificationPayload(
            notification = NotificationContent(title = "Alert", body = null),
            data = emptyMap(),
        )

        val result = payload.toJSObject()

        val notification = result.getJSONObject("notification")
        assertEquals("Alert", notification.getString("title"))
        assertTrue(notification.isNull("body"))

        val data = result.getJSONObject("data")
        assertEquals(0, data.length())
    }

    @Test
    fun toJSObject_notificationWithOnlyTitle() {
        val payload = NotificationPayload(
            notification = NotificationContent(title = "Title only"),
            data = emptyMap(),
        )

        val result = payload.toJSObject()
        val notification = result.getJSONObject("notification")
        assertEquals("Title only", notification.getString("title"))
        assertTrue(notification.isNull("body"))
    }

    @Test
    fun toJSObject_notificationWithOnlyBody() {
        val payload = NotificationPayload(
            notification = NotificationContent(body = "Body only"),
            data = emptyMap(),
        )

        val result = payload.toJSObject()
        val notification = result.getJSONObject("notification")
        assertTrue(notification.isNull("title"))
        assertEquals("Body only", notification.getString("body"))
    }

    @Test
    fun toJSObject_dataIteratedCorrectly() {
        val largeData = (1..10).associate { "key$it" to "value$it" }
        val payload = NotificationPayload(data = largeData)

        val result = payload.toJSObject()
        val data = result.getJSONObject("data")

        assertEquals(10, data.length())
        for (i in 1..10) {
            assertEquals("value$i", data.getString("key$i"))
        }
    }

    @Test
    fun notificationContent_defaults() {
        val content = NotificationContent()
        assertNull(content.title)
        assertNull(content.body)
    }

    @Test
    fun notificationPayload_defaults() {
        val payload = NotificationPayload()
        assertNull(payload.notification)
        assertTrue(payload.data.isEmpty())
    }
}
