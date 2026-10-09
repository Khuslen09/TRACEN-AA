<div align="center">

<img src="assets/icon/tracen_logo.svg" width="112" alt="TRACEN logo"/>

# TRACEN

**당신의 하루를 지도 위에 새기다**

이동 경로 · 활동 기록 · 추억의 핀 · AI 장소 추천을 하나의 지도에 담는<br/>
**GPS 기반 라이프로그 앱**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.9-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20·%20Firestore%20·%20Storage-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Google Maps](https://img.shields.io/badge/Google_Maps-4285F4?logo=googlemaps&logoColor=white)](https://pub.dev/packages/google_maps_flutter)
[![Gemini](https://img.shields.io/badge/Gemini-2.5_Flash--Lite-8E75B2?logo=googlegemini&logoColor=white)](https://ai.google.dev)
<br/>
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)
![Version](https://img.shields.io/badge/version-1.1.0-6B4EFF)
![i18n](https://img.shields.io/badge/i18n-한국어%20·%20English%20·%20Монгол-6B4EFF)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 목차

- [소개](#-소개)
- [주요 기능](#-주요-기능)
- [기술 스택](#-기술-스택)
- [프로젝트 구조](#-프로젝트-구조)
- [시작하기](#-시작하기)
- [테스트](#-테스트)
- [문서](#-문서)
- [라이선스](#-라이선스)

---

## ✨ 소개

> _"내가 걸어온 길을 보랏빛 지도 위에 새긴다."_

TRACEN은 걷고, 달리고, 머문 모든 순간을 지도 위에 남기는 앱입니다.
지나간 길만 보랏빛 오버레이가 벗겨지는 **스크래치 지도**, 러닝·워킹·사이클링 **실시간 기록**,
사진과 메모를 담은 **추억의 핀**, 그리고 Gemini 기반 **AI 장소 추천**까지 —
흩어져 있던 하루의 흔적을 하나의 지도로 모읍니다.

---

## 📱 주요 기능

### 🗺 스크래치 지도
지나간 경로만 긁혀서 드러나는 지도 효과. 많이 돌아다닐수록 지도가 열립니다.

### 🏃 활동 기록
- **러닝 / 워킹 / 사이클링** 3종 활동 지원
- 실시간 GPS 추적, 거리 · 페이스(사이클링은 속도) · 시간 · 걸음 수 측정
- 활동별 기준 속도에 따른 **자동 일시정지**
- **백그라운드 추적** — Android 포그라운드 서비스, iOS "항상 허용" 시 화면이 꺼져도 기록

### 📍 핀 & 추억 기록
- 사진 · 메모 · 위치명을 지도 핀으로 저장
- 카테고리 6종 (일반 · 음식 · 풍경 · 카페 · 운동 · 메모), 카테고리별 색상 커스터마이즈
- 날짜 · 위치를 나중에 수정 가능

### 📸 TRACEN 카메라
- 시그니처 필터 4종 — **Golden Route · Night Trace · Faded Map · Mono Path**
- 64³ LUT + 커스텀 프래그먼트 셰이더로 실시간 적용, 강도 조절 지원

### 🎴 공유 카드
- 템플릿 3종 — **Minimal · Film · Stamp**
- 경로 스티커, 국가 윤곽선, 주변 POI 선택 후 이미지로 내보내기

### 🤖 AI 장소 추천
카테고리 · 인원 · 자유 텍스트로 요청하면 **Google Places**로 주변 후보를 모으고
**Gemini**가 최적의 장소와 추천 이유를 골라줍니다.
POI 검색은 한국 좌표에서는 **Kakao Local API**, 그 외 지역에서는 Google Places를 사용합니다.

### 🗂 타임라인 & 갤러리
사진 / 메모 모드 전환, 월별 그룹핑, 검색 지원.

### ☁️ 동기화 & 오프라인
- 로컬 SQLite를 기준으로 동작 → 오프라인에서도 기록 가능
- 동기화 큐로 Firestore / Storage에 백업, 다른 기기 로그인 시 자동 복원
- 경로 좌표는 encoded polyline으로 압축 저장

### 🌏 그 밖에
- 다국어: **한국어 · English · Монгол**
- 라이트 / 다크 / 시스템 3-state 테마
- 이메일 & Google 로그인

---

## 🛠 기술 스택

| 영역 | 사용 기술 |
| --- | --- |
| **프레임워크** | Flutter, Dart (`^3.9.2`) |
| **상태 관리** | Provider |
| **지도 / 위치** | google_maps_flutter, geolocator, geocoding, flutter_foreground_task |
| **백엔드** | Firebase Auth, Cloud Firestore, Firebase Storage, Google Sign-In |
| **로컬 저장소** | sqflite, shared_preferences |
| **AI / 외부 API** | Gemini API, Google Places API (New), Kakao Local API |
| **카메라 / 이미지** | camera, image, GLSL fragment shader (`shaders/lut_filter.frag`) |
| **다국어** | flutter_localizations, intl (ARB 기반 코드 생성) |

---

## 📂 프로젝트 구조

```
lib/
├── main.dart
├── models/        # Route, Pin, ActivityType, TracenFilter, ShareCardTemplate …
├── services/      # 위치·추적, 동기화 큐, 클라우드, AI 추천, POI, LUT 셰이더 …
├── screens/
│   ├── home/      # 지도, 타임라인, 경로 목록, AI 추천
│   ├── run/       # 실시간 활동 기록 & 결과
│   ├── camera/    # 촬영 & 필터 편집
│   ├── share/     # 공유 카드 에디터
│   └── profile/   # 프로필, 설정
├── widgets/       # 공유 카드, 로고 등 공용 위젯
├── theme/         # 컬러, 텍스트 스타일, 테마 / 언어 Provider
├── l10n/          # app_ko / app_en / app_mn.arb + 생성 코드
└── utils/         # 폴리라인 코덱, 지도 투영, LUT 수학 …

assets/            # 아이콘, LUT PNG, 국가 윤곽선 GeoJSON
shaders/           # 카메라 필터용 LUT 셰이더
tools/             # LUT 생성, 국가 데이터 빌드 스크립트
docs/              # Firestore 스키마, 릴리스 노트, 약관 페이지
test/              # 유닛 & 위젯 테스트
```

---

## 🚀 시작하기

### 사전 준비

- Flutter SDK (Dart `^3.9.2` 포함)
- Xcode + CocoaPods (iOS) / Android Studio (Android)
- Firebase 프로젝트 (Auth · Firestore · Storage 활성화)
- API 키: Google Maps & Places, Gemini, Kakao REST

### 1. 저장소 클론 & 패키지 설치

```bash
git clone https://github.com/Khuslen09/TRACEN-AA.git
cd TRACEN-AA
flutter pub get
```

### 2. 환경 변수 설정

```bash
cp .env.example .env
```

| 변수 | 용도 | 발급처 |
| --- | --- | --- |
| `GOOGLE_MAPS_API_KEY` | 지도 표시, Places 검색 | [Google Cloud Console](https://console.cloud.google.com/apis/credentials) — Maps SDK for Android/iOS, Places API (New) 활성화 |
| `GEMINI_API_KEY` | AI 장소 추천 | [Google AI Studio](https://aistudio.google.com/apikey) |
| `KAKAO_REST_API_KEY` | 한국 좌표 POI 검색 | [Kakao Developers](https://developers.kakao.com) |

**iOS**는 Google Maps 키를 별도 파일로도 넣어야 합니다.

```bash
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
# GOOGLE_MAPS_API_KEY = <키> 입력
```

> ⚠️ `.env`, `Secrets.xcconfig`, `key.properties`, Firebase 설정 파일은 `.gitignore`에 등록되어 있습니다. 절대 커밋하지 마세요.
> 키가 한 번이라도 노출되었다면 각 콘솔에서 **재발급(rotate)** 하세요.

### 3. Firebase 연결

```bash
flutterfire configure
```

`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`가 생성됩니다.
배포 전에는 [`SECURITY_RULES_GUIDE.md`](SECURITY_RULES_GUIDE.md)를 따라 `firestore.rules` / `storage.rules`를 적용하세요.

### 4. 실행

```bash
cd ios && pod install && cd ..   # iOS만
flutter run
```

### Android 릴리스 빌드

```bash
cp key.properties.example android/key.properties   # 키스토어 정보 입력
flutter build appbundle
```

---

## 🧪 테스트

```bash
flutter test
```

카메라 필터(LUT · 색 보정), 공유 카드, 지도 투영, POI 서비스, 추적 서비스, 다국어 화면 등을 다룹니다.

---

## 📚 문서

| 문서 | 내용 |
| --- | --- |
| [`docs/FIRESTORE_SCHEMA.md`](docs/FIRESTORE_SCHEMA.md) | Firestore 컬렉션 구조, 동기화 전략, ID 정책 |
| [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md) | 버전별 릴리스 노트 |
| [`SECURITY_RULES_GUIDE.md`](SECURITY_RULES_GUIDE.md) | Firebase 보안 규칙 적용 가이드 |
| [`tools/README.md`](tools/README.md) | 카메라 필터 LUT 생성 방법 |
| [`docs/GOOGLE_SIGNIN_FIX.md`](docs/GOOGLE_SIGNIN_FIX.md) | Google 로그인 트러블슈팅 |

---

## 📄 라이선스

[MIT License](LICENSE) © 2026 Khuslen

<div align="center">
<br/>

Made with 💜 and Flutter

</div>
