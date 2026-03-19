import XCTest
@testable import tauri_plugin_remote_push

final class NormalizePayloadTests: XCTestCase {

    func testFullAPNsPayload() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Hello",
                    "body": "World"
                ],
                "badge": 3,
                "sound": "default",
                "category": "MESSAGE"
            ],
            "customKey": "customValue",
            "anotherKey": "anotherValue"
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        let notification = result["notification"] as? [String: Any]
        XCTAssertEqual(notification?["title"] as? String, "Hello")
        XCTAssertEqual(notification?["body"] as? String, "World")
        XCTAssertEqual(result["badge"] as? Int, 3)
        XCTAssertEqual(result["sound"] as? String, "default")
        XCTAssertEqual(result["category"] as? String, "MESSAGE")

        let data = result["data"] as? [String: Any]
        XCTAssertEqual(data?["customKey"] as? String, "customValue")
        XCTAssertEqual(data?["anotherKey"] as? String, "anotherValue")
    }

    func testStringAlert() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Simple alert message"
            ]
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        let notification = result["notification"] as? [String: Any]
        XCTAssertNil(notification?["title"])
        XCTAssertEqual(notification?["body"] as? String, "Simple alert message")
    }

    func testMissingAPS() {
        let userInfo: [AnyHashable: Any] = [
            "customKey": "value"
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        XCTAssertNil(result["notification"])
        XCTAssertNil(result["badge"])
        XCTAssertNil(result["sound"])
        XCTAssertNil(result["category"])

        let data = result["data"] as? [String: Any]
        XCTAssertEqual(data?["customKey"] as? String, "value")
    }

    func testFCMInternalKeysExcluded() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Test"]],
            "gcm.message_id": "abc123",
            "gcm.notification.title": "Test",
            "google.c.sender.id": "12345",
            "google.c.fid": "fid123",
            "from": "12345",
            "collapse_key": "com.app",
            "message_type": "gcm",
            "actualData": "keepThis"
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        let data = result["data"] as? [String: Any]
        XCTAssertEqual(data?.count, 1)
        XCTAssertEqual(data?["actualData"] as? String, "keepThis")
    }

    func testEmptyPayload() {
        let userInfo: [AnyHashable: Any] = [:]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        XCTAssertNil(result["notification"])
        let data = result["data"] as? [String: Any]
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 0)
    }

    func testDataWithVariousTypes() {
        let userInfo: [AnyHashable: Any] = [
            "stringVal": "hello",
            "intVal": 42,
            "doubleVal": 3.14,
            "boolVal": true
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        let data = result["data"] as? [String: Any]
        XCTAssertEqual(data?["stringVal"] as? String, "hello")
        XCTAssertEqual(data?["intVal"] as? Int, 42)
        XCTAssertEqual(data?["doubleVal"] as? Double, 3.14)
        XCTAssertEqual(data?["boolVal"] as? Bool, true)
    }

    func testBadgeZero() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["badge": 0]
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        XCTAssertEqual(result["badge"] as? Int, 0)
    }

    func testAPSWithNoAlert() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "badge": 5,
                "sound": "chime.caf"
            ]
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        XCTAssertNil(result["notification"])
        XCTAssertEqual(result["badge"] as? Int, 5)
        XCTAssertEqual(result["sound"] as? String, "chime.caf")
    }

    func testNonStringKeysIgnored() {
        let userInfo: [AnyHashable: Any] = [
            42: "numericKey",
            "validKey": "validValue"
        ]

        let result = PushNotificationPlugin.normalizePayload(userInfo)

        let data = result["data"] as? [String: Any]
        XCTAssertEqual(data?.count, 1)
        XCTAssertEqual(data?["validKey"] as? String, "validValue")
    }
}
