# 망고샵 — Google Play 출시 가이드

## 0. 산출물 / 사전 정보

| 항목 | 값 |
|---|---|
| 패키지명(applicationId) | `com.mangoshop.mangoshop_app` (영구 고정) |
| 버전 | 1.0.0 (versionCode 1) |
| 업로드 AAB | `build/app/outputs/bundle/release/app-release.aab` |
| 서명 키스토어 | `android/upload-keystore.jks` (**git 미추적**) |
| 키 비밀번호 | `android/key.properties` 안에 저장 (**git 미추적**) |
| 업로드 키 지문(SHA-256) | `3E:01:CD:58:3D:01:78:3C:0E:6A:28:5B:09:F6:42:40:91:48:9C:71:63:59:51:CF:96:D8:0A:9C:DD:09:5C:BA` |
| 개인정보처리방침 | https://mangoshop.co.kr/privacy |
| 이용약관 | https://mangoshop.co.kr/terms |
| 계정·데이터 삭제 | https://mangoshop.co.kr/account-deletion |

> ⚠️ **키스토어 백업 필수** — `android/upload-keystore.jks` 와 `android/key.properties` 를
> 안전한 곳(비밀번호 관리자, 클라우드 금고 등)에 반드시 백업하세요. 분실 시 앱 업데이트가
> 불가능해집니다(단, Google Play 앱 서명을 쓰면 업로드 키는 Google 지원으로 재설정 가능).

## 1. AAB 다시 빌드하려면

```bash
flutter build appbundle --release
```
`android/key.properties` 가 있는 환경에서 빌드해야 업로드 키로 서명됩니다.
버전을 올릴 때는 `pubspec.yaml` 의 `version: 1.0.0+1` 에서 `+1`(versionCode)을 반드시 증가시키세요.
(Play 는 동일 versionCode 재업로드를 거부합니다.)

## 2. Play Console 업로드 절차

1. **앱 만들기** — Play Console → 앱 만들기 → 이름 "망고샵", 앱/무료, 카테고리 쇼핑.
2. **Play 앱 서명** — 기본 활성화. 업로드 키(위 AAB)로 올리면 Google 이 최종 서명키로 재서명.
3. **프로덕션 → 새 버전 만들기** → `app-release.aab` 업로드.
   (먼저 **내부 테스트** 트랙으로 올려 실기기 설치 확인 후 프로덕션 승격을 권장)
4. 출시명 1.0.0, 출시 노트 작성.

## 3. 스토어 등록정보 (필수 입력)

- **앱 이름**: 망고샵
- **간단한 설명**(80자): 수입 과일 도매·소매 오픈마켓. 태국·베트남 애플망고, 아보카도, 열대과일을 검증된 수입사에서.
- **자세한 설명**: 멀티벤더(입점 수입사) / 도매·소매 등급별 가격 / 수량구간 할인 / 콜드체인 배송 등 특징 서술.
- **그래픽 자산**:
  - 앱 아이콘 512×512 (PNG) — `assets/brand/app_icon.png` 를 512로 리사이즈
  - 피처 그래픽 1024×500 — `assets/brand/splash_screen.png` 활용 가능
  - 스크린샷 폰 2장 이상 (홈·상품상세·장바구니 등 실기기 캡처)
- **개인정보처리방침 URL**: https://mangoshop.co.kr/privacy

## 4. 앱 콘텐츠 (정책 설문)

- **개인정보처리방침**: https://mangoshop.co.kr/privacy
- **앱 액세스 권한**: 로그인 필요 → **심사용 테스트 계정 제공**
  - 소매: `user@test.com` / `test1234`
  - 도매(승인): `buyer@test.com` / `test1234`
  - (관리자 기능 심사까지 원하면) `admin@mangoshop.co.kr` / 비밀번호는 별도 전달
- **광고 포함**: 없음
- **콘텐츠 등급 설문**: 쇼핑 앱 → 전체이용가 예상
- **타겟층**: 만 18세 이상(사업자 거래 포함) 권장
- **데이터 보안(Data safety)** — 아래 5절 참고
- **계정 삭제 URL**: https://mangoshop.co.kr/account-deletion

## 5. 데이터 보안(Data safety) 답변 근거

앱이 실제 수집·전송하는 데이터:

| 데이터 유형 | 수집 | 목적 | 비고 |
|---|---|---|---|
| 이름·이메일·전화번호 | O | 계정관리·주문 | 전송 시 HTTPS |
| 주소(배송지) | O | 주문·배송 | |
| 사업자 정보(도매) | O | 도매 인증·승인 | |
| 구매 내역 | O | 주문관리 | |
| 결제 정보 | △ | 결제 | 카드정보는 PG가 처리, 앱/서버 미저장 |
| 기기 ID/푸시 토큰(FCM) | O | 알림 | |
| 앱 활동·로그 | O | 서비스 운영 | |

- 전송 중 암호화: **예** (HTTPS)
- 사용자가 삭제 요청 가능: **예** (계정 삭제 URL 제공)
- 데이터 판매: **아니오**

## 6. 배포 전 최종 체크

- [ ] `pubspec.yaml` versionCode 증가 확인
- [ ] `lib/core/config.dart` `useLocal = false` (운영 HTTPS) — 현재 설정됨
- [ ] 키스토어·key.properties 백업 완료
- [ ] 내부 테스트 트랙 실기기 설치·로그인·주문 흐름 확인
- [ ] 개인정보처리방침/계정삭제 URL 운영 반영 확인 (배포 후 200)

## 7. 푸시 알림(FCM) — 선택

현재 `google-services.json` 미포함으로 푸시는 비활성(앱 동작엔 지장 없음).
활성화하려면 Firebase 프로젝트에 패키지명 `com.mangoshop.mangoshop_app` 등록 후
`android/app/google-services.json` 추가 및 Gradle 플러그인 적용 필요.
