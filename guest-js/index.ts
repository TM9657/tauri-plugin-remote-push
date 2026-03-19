import { addPluginListener, invoke, type PluginListener } from '@tauri-apps/api/core'

interface NativePushNotificationPayload {
  notification?: {
    title?: string
    body?: string
  }
  data: Record<string, any>
  badge?: number
  sound?: string
  channelId?: string
  category?: string
}

export interface PushNotification {
  title?: string;
  body?: string;
  data: Record<string, any>;
  badge?: number;
  sound?: string;
  channelId?: string; // Android
  category?: string;  // iOS
}

// Core Functions
export async function getToken(): Promise<string> {
  return await invoke("plugin:remote-push|get_token");
}

export async function requestPermission(): Promise<{ granted: boolean }> {
  return await invoke("plugin:remote-push|request_permission");
}

// Event Listeners
export async function onNotificationReceived(
  handler: (notification: PushNotification) => void
): Promise<PluginListener> {
  return await addPluginListener<NativePushNotificationPayload>('remote-push', 'notification-received', (payload) => {
    handler(normalizeNotification(payload))
  })
}

export async function onTokenRefresh(
  handler: (token: string) => void
): Promise<PluginListener> {
  return await addPluginListener<{ token: string }>('remote-push', 'token-received', ({ token }) => {
    handler(token)
  })
}

export async function onNotificationTapped(
  handler: (notification: PushNotification) => void
): Promise<PluginListener> {
  return await addPluginListener<NativePushNotificationPayload>('remote-push', 'notification-tapped', (payload) => {
    handler(normalizeNotification(payload))
  })
}

function normalizeNotification(payload: NativePushNotificationPayload): PushNotification {
  return {
    title: payload.notification?.title,
    body: payload.notification?.body,
    data: payload.data,
    badge: payload.badge,
    sound: payload.sound,
    channelId: payload.channelId,
    category: payload.category,
  }
}
