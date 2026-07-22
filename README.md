# 망고샵 (MANGOSHOP) 모바일 앱

수입 과일 **도매·소매 오픈마켓** 망고샵의 Flutter 모바일 앱.
Laravel 백엔드(`mangoshop`)의 `/api/v1` Sanctum 토큰 API 를 사용한다.

## 실행

```bash
flutter pub get
flutter run
```

## 서버 연결

접속 대상은 `lib/core/config.dart` 에서 전환한다.

| 설정 | 접속 대상 |
|---|---|
| `useLocal = false` (기본) | `https://mangoshop.co.kr` |
| `useLocal = true` | 로컬 XAMPP — Android 에뮬레이터는 `10.0.2.2/mangoshop`, 그 외 `localhost/mangoshop` |

실기기에서 로컬 서버로 붙을 때는 PC 의 LAN IP 를 지정한다.

```dart
AppConfig.overrideHost = 'http://192.168.0.10/mangoshop';
```

## 도메인 규칙

멀티벤더(입점 수입사) + 회원등급별 가격이 이 앱의 핵심이다.

- **판매 주체는 수입사(seller)** — 상품 카드/상세에 수입사명·콜드체인 여부·배송정책을 노출한다.
- **회원 구분** — 도매(`wholesale`) / 소매(`retail`).
  - 도매는 사업자 승인(`biz_status=approved`) 후 **도매가**가 적용된다.
  - 승인 전에는 소매가로 노출되므로 `AppUser.canSeeWholesalePrice` 로 구분한다.
- **가격 숨김** — 도매 전용 상품(`wholesale_only`)은 비대상 회원에게 가격을 내려주지 않는다.
  서버가 `price_visible=false` 로 응답하며, 앱은 "로그인 후 가격 확인"을 표시한다.
- **MOQ** — `moq` 미만 수량은 선택할 수 없다(수량 시트가 MOQ 에서 시작).
- **수량구간 할인** — `price_tiers` 의 `min_qty` 이상 구매 시 더 낮은 단가가 적용된다.
  앱의 단가 계산은 서버 `Product::unitPriceFor()` 와 동일한 규칙을 따른다.
- **판매상태** — `purchasable` 이 false 면 구매 불가(품절/판매마감/입고예정).
  입고예정 상품은 구매 대신 문의로 유도한다.

> 구버전 서버가 신규 필드를 내려주지 않는 경우를 대비해 `Product.fromJson` 이 안전한 기본값으로
> 폴백한다(예: `purchasable` 부재 시 재고 기준 판단). 필드를 추가할 때 이 규칙을 유지할 것.

## 구조

```
lib/
├── core/          config(서버주소) · api(Dio+토큰) · theme(브랜드 팔레트) · push_service · format
├── models/        API 응답 모델 (Product · Seller · PriceTier · OrderModel · AppUser …)
├── providers/     Riverpod — auth · cart · wishlist · recent · data_providers
├── features/      화면 단위 (home · catalog · cart · order · mypage · community · chat · auth)
├── widgets/       app_shell(탭) · product_card · common
└── router.dart    go_router — 5탭 StatefulShellRoute + 전체화면 라우트
```

## 브랜드 자산

`assets/brand/` 가 빌드에 쓰이는 자산이고, `mangoshop_mobile_assets/` 는 원본이다.

- 런타임 번들: `logo_horizontal.png`(앱바), `logo_stacked.png`(로그인·마이페이지)
- 빌드타임 생성용: `app_icon.png`, `icon_adaptive_foreground.png`, `splash_screen.png`

자산을 교체한 뒤에는 아래를 다시 실행한다.

```bash
dart run flutter_launcher_icons        # 런처 아이콘
dart run flutter_native_splash:create  # 네이티브 스플래시
```

브랜드 색상은 로고에서 추출해 `lib/core/theme.dart` 에 정의되어 있다.
`AppColors.navy` / `red` 는 초기 골격에서 이어받은 **레거시 별칭**이므로,
신규 코드는 `brand` / `accent` / `leaf` / `cool` / `wholesale` 을 사용한다.

## 푸시 알림 (FCM)

`google-services.json`(Android) / `GoogleService-Info.plist`(iOS) 가 없으면
`PushService` 가 조용히 비활성화되고 앱은 정상 동작한다. 푸시를 쓰려면
Firebase 프로젝트를 연결한 뒤 아래를 추가한다.

- `android/app/google-services.json`
- `android/settings.gradle.kts` 에 `com.google.gms.google-services` 플러그인
- `android/app/build.gradle.kts` 에 해당 플러그인 적용

## 릴리즈 전 확인

- [ ] `android/app/build.gradle.kts` 의 릴리즈 서명(현재 디버그 키로 서명 중)
- [ ] `usesCleartextTraffic="true"` — 로컬 HTTP 개발용. 운영 HTTPS 전용이면 제거
- [ ] `lib/core/config.dart` 의 `useLocal = false` 확인
