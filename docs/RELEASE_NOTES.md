# 📦 Release Notes

GitHub Releases 에 등록할 릴리스 노트 모음입니다.
(GitHub → Releases → "Draft a new release" → 태그 입력 → 아래 내용 복사)

---

## v1.1.0 — AI 장소 추천 & iOS 배포

**태그**: `v1.1.0` · **대상**: `main` 브랜치 최신 커밋

### ✨ 새로운 기능
- **AI 장소 추천**: 카테고리·인원·자유 텍스트로 요청하면 Google Places + Claude API가 주변 최적 장소를 선별하고 추천 이유를 제시
- **iOS 백그라운드 GPS**: "항상 허용" 권한 시 화면이 꺼져도 경로 추적
- **테마 기본값 라이트모드**: 첫 실행 시 라이트모드로 시작 (이후 사용자 설정 유지)

### 🔒 보안
- API 키를 `.env` / `ios/Flutter/Secrets.xcconfig` 로 분리, 저장소 비노출
- Firestore 보안 규칙을 v5 데이터 모델(독립 핀)에 맞게 갱신

### 🐛 버그 수정
- 다크모드에서 보이지 않던 아이콘·글자·하단 네비 색상 수정
- 러닝 시작 시 현재 위치로 카메라 이동 안 되던 문제 해결
- iOS 앱 아이콘 알파 채널 제거 (App Store 규격 준수)
- Firebase 중복 초기화(duplicate-app) 예외 처리

### 📱 배포
- iOS TestFlight 내부 테스트 배포

---

## v1.0.0 — 첫 정식 버전

**태그**: `v1.0.0`

### ✨ 핵심 기능
- **스크래치 지도**: 지나간 경로만 보라 오버레이가 벗겨지는 시각 효과
- **러닝 추적**: 실시간 GPS, 거리·페이스·시간 측정 및 결과 요약
- **핀 기록**: 사진·메모·카테고리(6종)를 지도 핀으로 저장
- **타임라인 & 갤러리**: 사진/메모 모드, 월별 카드 정리
- **클라우드 동기화**: Firebase Auth + Firestore, 오프라인 큐 지원
- **다크모드**: 라이트/다크/시스템 3-state

### 🛠 기술
- Flutter 3 / Dart 3 크로스플랫폼 (Android · iOS)
- Local-first 아키텍처 (SQLite + Firestore)
- `BlendMode.dstOut` Canvas 마스킹 스크래치 효과
