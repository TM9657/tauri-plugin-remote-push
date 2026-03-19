import { describe, it, expect } from 'vitest'
import { normalizeNotification, type NativePushNotificationPayload } from '../index'

describe('normalizeNotification', () => {
  it('maps full payload with all fields', () => {
    const payload: NativePushNotificationPayload = {
      notification: { title: 'Hello', body: 'World' },
      data: { key1: 'value1', key2: 'value2' },
      badge: 3,
      sound: 'default',
      channelId: 'my-channel',
      category: 'MESSAGE',
    }

    const result = normalizeNotification(payload)

    expect(result).toEqual({
      title: 'Hello',
      body: 'World',
      data: { key1: 'value1', key2: 'value2' },
      badge: 3,
      sound: 'default',
      channelId: 'my-channel',
      category: 'MESSAGE',
    })
  })

  it('handles missing notification object', () => {
    const payload: NativePushNotificationPayload = {
      data: { action: 'sync' },
    }

    const result = normalizeNotification(payload)

    expect(result.title).toBeUndefined()
    expect(result.body).toBeUndefined()
    expect(result.data).toEqual({ action: 'sync' })
  })

  it('handles empty data-only payload (silent push)', () => {
    const payload: NativePushNotificationPayload = {
      data: {},
    }

    const result = normalizeNotification(payload)

    expect(result.title).toBeUndefined()
    expect(result.body).toBeUndefined()
    expect(result.data).toEqual({})
    expect(result.badge).toBeUndefined()
    expect(result.sound).toBeUndefined()
    expect(result.channelId).toBeUndefined()
    expect(result.category).toBeUndefined()
  })

  it('handles notification with only title', () => {
    const payload: NativePushNotificationPayload = {
      notification: { title: 'Alert' },
      data: {},
    }

    const result = normalizeNotification(payload)

    expect(result.title).toBe('Alert')
    expect(result.body).toBeUndefined()
  })

  it('handles notification with only body', () => {
    const payload: NativePushNotificationPayload = {
      notification: { body: 'Something happened' },
      data: {},
    }

    const result = normalizeNotification(payload)

    expect(result.title).toBeUndefined()
    expect(result.body).toBe('Something happened')
  })

  it('preserves complex data values', () => {
    const payload: NativePushNotificationPayload = {
      data: {
        nested: { foo: 'bar' },
        array: [1, 2, 3],
        number: 42,
        bool: true,
      },
    }

    const result = normalizeNotification(payload)

    expect(result.data.nested).toEqual({ foo: 'bar' })
    expect(result.data.array).toEqual([1, 2, 3])
    expect(result.data.number).toBe(42)
    expect(result.data.bool).toBe(true)
  })

  it('handles badge of zero', () => {
    const payload: NativePushNotificationPayload = {
      data: {},
      badge: 0,
    }

    const result = normalizeNotification(payload)

    expect(result.badge).toBe(0)
  })

  it('produces correct shape for Android-style payload (channelId, no category)', () => {
    const payload: NativePushNotificationPayload = {
      notification: { title: 'New message', body: 'You have a new message' },
      data: { senderId: '123' },
      channelId: 'messages',
    }

    const result = normalizeNotification(payload)

    expect(result.channelId).toBe('messages')
    expect(result.category).toBeUndefined()
  })

  it('produces correct shape for iOS-style payload (category, no channelId)', () => {
    const payload: NativePushNotificationPayload = {
      notification: { title: 'New message', body: 'You have a new message' },
      data: { senderId: '123' },
      category: 'MESSAGE',
      sound: 'chime.caf',
      badge: 1,
    }

    const result = normalizeNotification(payload)

    expect(result.category).toBe('MESSAGE')
    expect(result.channelId).toBeUndefined()
    expect(result.sound).toBe('chime.caf')
    expect(result.badge).toBe(1)
  })
})
