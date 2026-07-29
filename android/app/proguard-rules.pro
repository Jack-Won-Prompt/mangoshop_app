# 망고샵 릴리즈(R8) keep 규칙
# 리플렉션·네이티브 브리지로 접근되는 코드가 최적화 과정에서 제거되지 않도록 보호한다.
# 앱 자체 모델은 수동 JSON 파싱(리플렉션 미사용)이라 별도 keep 이 필요 없다.

# ---- Flutter 엔진/플러그인 브리지 ----
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ---- Firebase / FCM (푸시) ----
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- Pusher Channels (실시간 상담) : 내부적으로 OkHttp/Gson 사용 ----
-keep class com.pusher.** { *; }
-dontwarn com.pusher.**
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
# OkHttp / Okio
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ---- flutter_local_notifications ----
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ---- WebView (결제 위젯) : JS 브리지 콜백 보존 ----
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ---- 코루틴/일반 경고 억제 ----
-dontwarn kotlinx.**
-dontwarn org.jetbrains.**

# ---- slf4j (pusher 의존성의 선택적 로거 바인딩) ----
-dontwarn org.slf4j.impl.StaticLoggerBinder
