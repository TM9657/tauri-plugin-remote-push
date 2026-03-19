# Tauri Plugin: Remote Push Notifications

A plugin for Tauri v2 that enables applications to receive remote push notifications via Firebase Cloud Messaging (FCM) on Android and, when configured with Firebase on iOS, Firebase Cloud Messaging backed by Apple Push Notification Service (APNs).

This plugin is self-contained and handles its own native dependencies. However, you must still perform some **manual modification of your native host application code** to integrate the necessary notification services.

## Prerequisites

- A working Tauri v2 project.
- A Firebase project with Android and, if you want FCM tokens on iOS, an iOS app configured as well.
- An Apple Developer account with push notification capabilities for iOS.
- You must have generated the native mobile projects by running `tauri android init` and `tauri ios init`.

## Setup

### 1. Install Plugin Package

```sh
# Add the rust part
cargo add tauri-plugin-remote-push
```

```sh
# Add the javascript part
npm install tauri-plugin-remote-push-api
# or
yarn add tauri-plugin-remote-push-api
# or
pnpm add tauri-plugin-remote-push-api
# or
bun add tauri-plugin-remote-push-api
```

### 2. Register the Plugin

You must register the plugin with Tauri in your `src-tauri/src/lib.rs` file:

```rust
// src-tauri/src/lib.rs
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_remote_push::init())
        // ... other setup
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

---

## Platform-Specific Configuration

This is the **critical manual step** required to make the plugin functional.

### iOS Configuration

1.  **Add Capabilities in Xcode**: Open your `src-tauri/gen/apple/app.xcodeproj` project in Xcode.
    *   Select the root project, then your app target.
    *   Go to the "Signing & Capabilities" tab.
    *   Click `+ Capability` and add **Push Notifications**.
    *   Click `+ Capability` again and add **Background Modes**. In the expanded section, check **Remote notifications**.

2.  **If you want FCM on iOS, add Firebase to the app target**:
    *   In the Firebase console, add an iOS app that matches your bundle identifier.
    *   Download `GoogleService-Info.plist`.
    *   Add it to your Xcode app target so it is bundled into the application.
    *   In Firebase Console > Project settings > Cloud Messaging, upload your APNs authentication key or certificates so Firebase can deliver through APNs.
    *   You do **not** need to add Firebase pods or a separate Swift package in the host app just for this plugin. The plugin already brings in `FirebaseCore` and `FirebaseMessaging` through its own iOS Swift package.

3.  **Modify your AppDelegate**: Open `src-tauri/src/ios/app/AppDelegate.swift` and make the following changes to register for notifications and forward them to the plugin.

    ```swift
    import UIKit
    import Tauri
    import UserNotifications // 1. Import UserNotifications
    import tauri_plugin_remote_push // 2. Import your plugin

    class AppDelegate: TauriAppDelegate {
      override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 3. Configure Firebase early when GoogleService-Info.plist is bundled
        PushNotificationPlugin.configureFirebaseAppIfAvailable()

        // 4. Set the notification center delegate
        UNUserNotificationCenter.current().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
      }

      // 5. Add the token registration handlers
      override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationPlugin.applicationDidRegisterForRemoteNotifications(deviceToken: deviceToken)
      }

      override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationPlugin.applicationDidFailToRegisterForRemoteNotifications(error: error)
        print("Failed to register for remote notifications: \(error.localizedDescription)")
      }

      override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        PushNotificationPlugin.applicationDidReceiveRemoteNotification(userInfo: userInfo)
        completionHandler(.newData)
      }

      // 6. Add the notification-handling delegate methods
      override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        PushNotificationPlugin.applicationDidReceiveRemoteNotification(userInfo: notification.request.content.userInfo)
        // You can customize the presentation options here
        completionHandler([.banner, .sound, .badge])
      }

      override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        PushNotificationPlugin.applicationDidReceiveNotificationResponse(userInfo: response.notification.request.content.userInfo)
        completionHandler()
      }
    }
    ```

4.  **Understand the returned token**:
    *   If `GoogleService-Info.plist` is present and Firebase is configured, `getToken()` returns an iOS FCM registration token.
    *   If Firebase is not configured on iOS, `getToken()` falls back to the raw APNs token.
    *   The AppDelegate hooks above are still required. They are the bridge from the iOS application lifecycle into the plugin. The new static forwarding methods are safe to call even before the plugin instance is loaded.

### Android Configuration

This section is **critical** for Android to function. If you misconfigure this, your app will fail to initialize Firebase and will likely show a **blank white screen** on startup.

**1. Configure Gradle**

You need to add the Google Services plugin to your Android project's Gradle configuration. Your project may use the modern Kotlin `build.gradle.kts` syntax or the older Groovy `build.gradle` syntax. Make sure you edit the correct files.

**A) Project-Level Gradle File**

This file is located at `src-tauri/gen/android/[YOUR_APP_NAME]/build.gradle.kts` (or `.gradle`).

*If you have a `build.gradle.kts` (Kotlin) file:*
```kotlin
// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    id("com.android.application") version "8.2.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
    // 1. Add this line
    id("com.google.gms.google-services") version "4.4.1" apply false
}
```

*If you have a `build.gradle` (Groovy) file:*
```groovy
buildscript {
    repositories {
        // Make sure you have google() here
        google()
        mavenCentral()
    }
    dependencies {
        // ... other classpaths
        // 1. Add this line
        classpath 'com.google.gms:google-services:4.4.1'
    }
}
```

**B) App-Level Gradle File**

This file is located at `src-tauri/gen/android/[YOUR_APP_NAME]/app/build.gradle.kts` (or `.gradle`).

*If you have a `build.gradle.kts` (Kotlin) file:*
```kotlin
// 1. Add this block at the top of the file
plugins {
    id("com.google.gms.google-services")
}

// ... rest of the file
android {
    // ...
}
```

*If you have a `build.gradle` (Groovy) file:*
```groovy
// 1. Add this line at the very top of the file
apply plugin: 'com.google.gms.google-services'

android {
    // ...
}
```

**2. Add `google-services.json`**

This step is the same for all projects.

*   Go to your Firebase project settings. In the "General" tab, under "Your apps", select your Android application.
*   Download the `google-services.json` file.
*   Place this file in your app's module directory: `src-tauri/gen/android/[YOUR_APP_NAME]/app/`.

**3. Register the Notification Service**

The plugin now contributes the `FCMService` declaration and `POST_NOTIFICATIONS` permission from its library manifest. If your host app overrides manifests aggressively, verify that these entries still appear in the merged manifest. This allows your app to receive notifications when it's in the background.

```xml
<application ...>
    ...
    <service
        android:name="app.tauri.remotepush.FCMService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
    ...
</application>
```

---

## API

```typescript
import {
  getToken,
  requestPermission,
  onNotificationReceived,
  onNotificationTapped,
  onTokenRefresh
} from 'tauri-plugin-remote-push-api';

// Request user permission for notifications
const permission = await requestPermission();
if (permission.granted) {
  // Get the device token
  const token = await getToken();
  console.log('Device token:', token);
}

// Listen for incoming notifications
const unsubscribe = await onNotificationReceived((notification) => {
  console.log('Received notification:', notification);
});

// Listen for notification taps (user opened the app via a notification)
const unsubscribeTap = await onNotificationTapped((notification) => {
  console.log('Notification tapped:', notification);
});

// Listen for token refreshes
const unsubscribeToken = await onTokenRefresh((token) => {
  console.log('Token refreshed:', token);
});
```

If Firebase is configured on iOS, the returned token is an FCM token on both mobile platforms. If not, iOS returns an APNs token instead.

## License

This project is licensed under the MIT License.
