import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router.dart';

/// 백그라운드/종료 상태 데이터 메시지 핸들러 (top-level 필수).
/// notification 필드가 있으면 OS가 자동 표시하므로 여기선 특별한 처리 불필요.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // 필요 시 백그라운드 데이터 처리
}

/// FCM 푸시 알림 서비스.
/// Firebase 설정(google-services.json)이 없으면 조용히 비활성화되어 앱은 정상 동작.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _handlersBound = false;

  /// 서버에 토큰을 등록하는 콜백 (앱에서 주입 — ApiClient 사용)
  Future<void> Function(String token)? onToken;

  static const _channel = AndroidNotificationChannel(
    'mangoshop_default',
    '망고샵 알림',
    description: '주문·상담·공지 알림',
    importance: Importance.high,
  );

  /// 앱 시작 시 1회 호출. 로그인 여부와 무관하게 초기화하되, 토큰 등록은 로그인 상태에서 유효.
  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Firebase 미설정(google-services.json 없음) → 푸시 비활성, 앱은 정상
      debugPrint('[Push] Firebase 미초기화: $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      // 로컬 알림 (포그라운드 표시)
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _local.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (resp) {
          if (resp.payload != null) _routeFromData(_decode(resp.payload!));
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 권한 요청 (iOS/Android 13+)
      await FirebaseMessaging.instance.requestPermission();

      if (!_handlersBound) {
        _handlersBound = true;
        FirebaseMessaging.onMessage.listen(_onForeground);
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _routeFromData(m.data));
        // 종료 상태에서 알림 탭으로 실행된 경우
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) {
          Future.delayed(const Duration(milliseconds: 600), () => _routeFromData(initial.data));
        }
        FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      }

      _ready = true;
      await syncToken();
    } catch (e) {
      debugPrint('[Push] 초기화 오류: $e');
    }
  }

  /// 현재 토큰을 서버에 등록 (로그인 직후/앱 시작 시 호출)
  Future<void> syncToken() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('[Push] 토큰 조회 실패: $e');
    }
  }

  /// 현재 FCM 토큰 (미초기화/미설정 시 null)
  Future<String?> currentToken() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _register(String token) async {
    try {
      await onToken?.call(token);
    } catch (e) {
      debugPrint('[Push] 토큰 등록 실패: $e');
    }
  }

  void _onForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Map<String, dynamic> _decode(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map ? Map<String, dynamic>.from(v) : {};
    } catch (_) {
      return {};
    }
  }

  /// 알림 데이터에 따라 화면 이동
  void _routeFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    switch (type) {
      case 'order':
        final id = data['order_id'];
        if (id != null) router.push('/orders/$id');
        break;
      case 'chat':
        router.push('/chat');
        break;
      case 'notice':
        final link = data['link']?.toString();
        router.push(link != null && link.isNotEmpty ? link : '/community/notices');
        break;
      default:
        final link = data['link']?.toString();
        if (link != null && link.isNotEmpty) router.push(link);
    }
  }
}
