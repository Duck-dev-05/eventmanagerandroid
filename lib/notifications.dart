import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges EventPulse sync notifications to Android system notifications.
///
/// The native side owns the notification channel, permission prompt and
/// deduplication so foreground polling and the background sync worker cannot
/// show the same notification twice.
class EventPulseNotifications {
  const EventPulseNotifications._();

  static const _channel = MethodChannel('eventpulse/notifications');

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static Future<void> requestPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // Tests and unsupported platforms have no native notification bridge.
    } on PlatformException {
      // A denied or unavailable notification channel is not a sync failure.
    }
  }

  static Future<void> notifyNew(
    List<Map<String, dynamic>> notifications,
  ) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('notifyNew', {
        'notifications': notifications,
      });
    } on MissingPluginException {
      // Tests and unsupported platforms have no native notification bridge.
    } on PlatformException {
      // Notification delivery must never interrupt the sync loop.
    }
  }
}
