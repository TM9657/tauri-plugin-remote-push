import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications
import Tauri
import SwiftRs

@objc(PushNotificationPlugin)
public class PushNotificationPlugin: Plugin, MessagingDelegate {
    public static var instance: PushNotificationPlugin?
    private static var pendingDeviceToken: Data?
    private static var pendingRegistrationError: String?
    private static var pendingNotifications: [[AnyHashable: Any]] = []
    private static var pendingTappedNotifications: [[AnyHashable: Any]] = []

    private var tokenString: String?
    private var pendingTokenInvokes: [Invoke] = []
    private var firebaseMessagingEnabled = false

    @objc public static func configureFirebaseAppIfAvailable() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    @objc public static func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {
        if let instance = instance {
            instance.handleToken(deviceToken)
        } else {
            pendingDeviceToken = deviceToken
        }
    }

    @objc public static func applicationDidFailToRegisterForRemoteNotifications(error: Error) {
        if let instance = instance {
            instance.handleRegistrationFailure(error)
        } else {
            pendingRegistrationError = error.localizedDescription
        }
    }

    @objc public static func applicationDidReceiveRemoteNotification(userInfo: [AnyHashable: Any]) {
        if let instance = instance {
            instance.handleNotification(userInfo)
        } else {
            pendingNotifications.append(userInfo)
        }
    }

    @objc public static func applicationDidReceiveNotificationResponse(userInfo: [AnyHashable: Any]) {
        if let instance = instance {
            instance.handleNotificationTapped(userInfo)
        } else {
            pendingTappedNotifications.append(userInfo)
        }
    }

    override public func load(webview: WKWebView) {
        super.load(webview: webview)
        PushNotificationPlugin.instance = self
        configureFirebaseMessagingIfAvailable()
        flushPendingLifecycleEvents()
    }

    @objc public func getToken(_ invoke: Invoke) {
        if let tokenString {
            invoke.resolve(tokenString)
            return
        }

        pendingTokenInvokes.append(invoke)
        registerForRemoteNotifications()
    }

    @objc public func requestPermissions(_ invoke: Invoke) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                invoke.reject(error.localizedDescription)
                return
            }

            if granted {
                self.registerForRemoteNotifications()
            }

            invoke.resolve(["granted": granted])
        }
    }

    public func handleToken(_ token: Data) {
        if firebaseMessagingEnabled {
            Messaging.messaging().apnsToken = token
            // FCM will deliver the registration token via messaging(_:didReceiveRegistrationToken:)
            return
        }

        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        resolveToken(tokenString)
    }

    public func handleRegistrationFailure(_ error: Error) {
        rejectPendingTokenInvokes(error.localizedDescription)
    }

    public func handleNotification(_ userInfo: [AnyHashable : Any]) {
        self.trigger("notification-received", data: Self.normalizePayload(userInfo))
    }

    public func handleNotificationTapped(_ userInfo: [AnyHashable : Any]) {
        self.trigger("notification-tapped", data: Self.normalizePayload(userInfo))
    }

    private static func normalizePayload(_ userInfo: [AnyHashable: Any]) -> JSObject {
        var result: JSObject = [:]

        // Extract notification title/body from aps.alert
        if let aps = userInfo["aps"] as? [String: Any] {
            var notification: JSObject = [:]
            if let alert = aps["alert"] as? [String: Any] {
                if let title = alert["title"] as? String { notification["title"] = title }
                if let body = alert["body"] as? String { notification["body"] = body }
            } else if let alert = aps["alert"] as? String {
                notification["body"] = alert
            }
            if !notification.isEmpty {
                result["notification"] = notification
            }
            if let badge = aps["badge"] as? Int { result["badge"] = badge }
            if let sound = aps["sound"] as? String { result["sound"] = sound }
            if let category = aps["category"] as? String { result["category"] = category }
        }

        // Collect custom data keys (exclude Apple/FCM internal keys)
        let excludedKeys: Set<String> = ["aps", "from", "collapse_key", "message_type"]
        var data: JSObject = [:]
        for (key, value) in userInfo {
            guard let keyStr = key as? String else { continue }
            if excludedKeys.contains(keyStr) { continue }
            if keyStr.hasPrefix("gcm.") || keyStr.hasPrefix("google.") { continue }
            if let strValue = value as? String {
                data[keyStr] = strValue
            } else if let intValue = value as? Int {
                data[keyStr] = intValue
            } else if let doubleValue = value as? Double {
                data[keyStr] = doubleValue
            } else if let boolValue = value as? Bool {
                data[keyStr] = boolValue
            }
        }
        result["data"] = data

        return result
    }

    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else {
            return
        }

        resolveToken(fcmToken)
    }

    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func configureFirebaseMessagingIfAvailable() {
        PushNotificationPlugin.configureFirebaseAppIfAvailable()

        guard FirebaseApp.app() != nil else {
            return
        }

        firebaseMessagingEnabled = true
        Messaging.messaging().delegate = self
    }


    private func resolveToken(_ tokenString: String) {
        let isNewToken = self.tokenString != tokenString
        self.tokenString = tokenString

        if isNewToken {
            self.trigger("token-received", data: ["token": tokenString])
        }

        let pendingInvokes = pendingTokenInvokes
        pendingTokenInvokes.removeAll()
        pendingInvokes.forEach { $0.resolve(tokenString) }
    }

    private func rejectPendingTokenInvokes(_ message: String) {
        let pendingInvokes = pendingTokenInvokes
        pendingTokenInvokes.removeAll()
        pendingInvokes.forEach { $0.reject(message) }
    }

    private func flushPendingLifecycleEvents() {
        if let token = PushNotificationPlugin.pendingDeviceToken {
            PushNotificationPlugin.pendingDeviceToken = nil
            handleToken(token)
        }

        if let errorMessage = PushNotificationPlugin.pendingRegistrationError {
            PushNotificationPlugin.pendingRegistrationError = nil
            rejectPendingTokenInvokes(errorMessage)
        }

        let queuedNotifications = PushNotificationPlugin.pendingNotifications
        PushNotificationPlugin.pendingNotifications.removeAll()
        queuedNotifications.forEach(handleNotification)

        let queuedTappedNotifications = PushNotificationPlugin.pendingTappedNotifications
        PushNotificationPlugin.pendingTappedNotifications.removeAll()
        queuedTappedNotifications.forEach(handleNotificationTapped)
    }
} 