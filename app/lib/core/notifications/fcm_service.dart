import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_provider.dart';

/// Top-level handler for background messages (must be a top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  dev.log('FCM background message: ${message.messageId}');
}

/// Manages Firebase Cloud Messaging: token lifecycle, foreground/background
/// message handling, and token registration with the backend.
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _api;

  /// Callback invoked when a foreground notification arrives. The UI layer
  /// should set this to display an in-app banner or local notification.
  void Function(RemoteMessage message)? onForegroundMessage;

  /// Callback invoked when the user taps a notification (from background or
  /// terminated state).
  void Function(RemoteMessage message)? onNotificationTapped;

  FCMService({required ApiClient api}) : _api = api;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Call once at app startup (after Firebase.initializeApp).
  Future<void> initialize() async {
    // Register the background handler.
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    // Request permission (iOS / web).
    await requestPermission();

    // Foreground message listener.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tap -- app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Notification tap -- app was terminated.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // iOS foreground presentation options.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Obtain and register the FCM token.
    await _registerToken();

    // Listen for token refresh.
    _messaging.onTokenRefresh.listen((newToken) {
      _sendTokenToBackend(newToken);
    });
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Request notification permission. Returns the authorization status.
  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
    dev.log('FCM permission: ${settings.authorizationStatus}');
    return settings.authorizationStatus;
  }

  // ---------------------------------------------------------------------------
  // Token
  // ---------------------------------------------------------------------------

  /// Get the current FCM registration token.
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Delete the current token (e.g. on logout).
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
  }

  // ---------------------------------------------------------------------------
  // Topic subscription
  // ---------------------------------------------------------------------------

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _registerToken() async {
    final token = await getToken();
    if (token != null) {
      await _sendTokenToBackend(token);
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _api.post('/users/fcm-token', data: {'token': token});
      dev.log('FCM token registered with backend');
    } catch (e) {
      dev.log('FCM token registration failed: $e');
      // Non-fatal: will retry on next token refresh.
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('FCM foreground: ${message.notification?.title}');
    onForegroundMessage?.call(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    dev.log('FCM tap: ${message.data}');
    onNotificationTapped?.call(message);
  }
}

// -----------------------------------------------------------------------------
// Riverpod provider
// -----------------------------------------------------------------------------

final fcmServiceProvider = Provider<FCMService>((ref) {
  final api = ref.read(apiClientProvider);
  return FCMService(api: api);
});
