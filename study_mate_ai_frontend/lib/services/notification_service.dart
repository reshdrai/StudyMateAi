import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'token_storage.dart';
import 'api_config.dart';

/// Background handler MUST be a top-level function.
/// Called when a push arrives while app is terminated or in background.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // The system tray notification is shown automatically by FCM for
  // messages that include a `notification` payload (which our backend sends).
  // Nothing else needed here.
}

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Navigation key so we can navigate from notification taps.
  /// Set this in your MaterialApp: `navigatorKey: NotificationService().navigatorKey`
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;

  /// Call once at app startup (after Firebase.initializeApp()).
  /// Sets up permission, handlers, and registers the token with the backend.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Set up background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // 2. Request permission (iOS + Android 13+)
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // 3. Initialize local notifications (for foreground display)
      await _initializeLocalNotifications();

      // 4. Get token + register with backend
      await _registerToken();

      // 5. Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });

      // 6. Foreground message handler — show local notification
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 7. Notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 8. Notification tap when app was terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Delay navigation slightly until app is fully initialized
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(initialMessage);
        });
      }

      if (kDebugMode) {
        debugPrint('[NotificationService] Initialized successfully');
      }
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        // Handle tap on local notification (when app was in foreground)
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _navigateFromData(Map<String, dynamic>.from(data));
          } catch (_) {}
        }
      },
    );

    // Create Android notification channel (must match FCM service channel id)
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'studymate_reminders',
        'Study Reminders',
        description: 'Reminders for upcoming and overdue study tasks',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('[NotificationService] getToken error: $e');
    }
  }

  Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final authToken = await TokenStorage.getToken();
      if (authToken == null) {
        debugPrint(
          '[NotificationService] No auth token yet, skipping registration',
        );
        return;
      }

      String platform = 'android';
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isIOS) {
        platform = 'ios';
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/fcm/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': fcmToken, 'platform': platform}),
      );

      if (kDebugMode) {
        debugPrint(
          '[NotificationService] FCM token registered: ${res.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Register error: $e');
    }
  }

  /// Call this after successful login to register the token
  /// (since initialize() may run before the user is authenticated)
  Future<void> registerAfterLogin() async {
    await _registerToken();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
        '[NotificationService] Foreground message: ${message.messageId}',
      );
    }

    final notification = message.notification;
    if (notification == null) return;

    final payload = jsonEncode(message.data);

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'studymate_reminders',
          'Study Reminders',
          channelDescription: 'Reminders for upcoming and overdue study tasks',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;
    _navigateFromData(data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final materialIdStr = data['materialId']?.toString();

    if (materialIdStr == null || materialIdStr == '0') return;

    final materialId = int.tryParse(materialIdStr);
    if (materialId == null) return;

    // Navigate to study plan page
    // (users can find the relevant task there)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      try {
        // Push a named route if you have one configured
        // Otherwise: use a callback set from outside
        if (_onNotificationTap != null) {
          _onNotificationTap!(type ?? 'UNKNOWN', materialId, data);
        }
      } catch (e) {
        debugPrint('[NotificationService] Navigation error: $e');
      }
    });
  }

  /// Register a callback that handles notification taps.
  /// Typically set from main.dart after the router is ready.
  void Function(String type, int materialId, Map<String, dynamic> data)?
  _onNotificationTap;

  void setTapHandler(
    void Function(String type, int materialId, Map<String, dynamic> data)
    handler,
  ) {
    _onNotificationTap = handler;
  }

  /// Call backend's /test endpoint to verify the FCM pipeline works.
  Future<bool> sendTestNotification() async {
    try {
      final authToken = await TokenStorage.getToken();
      if (authToken == null) return false;

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/fcm/test'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
