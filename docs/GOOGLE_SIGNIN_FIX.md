# 🔧 Google 로그인 디버깅 — "계정 선택 후 에러" 해결

증상: Google 로그인 버튼 → 계정 선택 다이얼로그 정상 → 계정 선택 → 에러
원인: 거의 95% **SHA-1 디지털 서명 미등록** (Android)

## 🎯 1단계: SHA-1 알아내기

Android Studio 터미널 또는 cmd/terminal에서:

### macOS / Linux
```bash
cd ~/.gradle/caches/modules-2/files-2.1
# 또는 프로젝트 루트에서
cd android
./gradlew signingReport
```

### Windows
```powershell
cd android
.\gradlew signingReport
```

출력 예시 (이 중 `SHA1` 줄을 복사):
```
Variant: debug
Config: debug
Store: /Users/yourname/.android/debug.keystore
Alias: AndroidDebugKey
SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
SHA-256: ...
```

`AB:CD:EF:...` 같은 문자열이 SHA-1 입니다. **debug 변형만** 우선 등록하면 돼요.

### 만약 `./gradlew`가 안 되면

`keytool` 명령으로 직접 가능 (Java JDK 필요):

```bash
# macOS/Linux
keytool -keystore ~/.android/debug.keystore -list -v -alias androiddebugkey -storepass android -keypass android

# Windows
keytool -keystore %USERPROFILE%\.android\debug.keystore -list -v -alias androiddebugkey -storepass android -keypass android
```

## 🎯 2단계: Firebase에 등록

1. https://console.firebase.google.com → Tracen 프로젝트
2. ⚙️ (좌측 위) → **프로젝트 설정**
3. 아래로 스크롤 → **내 앱** 섹션 → Android 앱 선택
4. **SHA 인증서 지문** → **지문 추가** 클릭
5. 1단계에서 복사한 SHA-1 붙여넣기 → 저장

## 🎯 3단계: google-services.json 갱신

SHA-1 등록 후, Firebase가 만든 새 설정 파일을 받아야 합니다.

1. 같은 화면에서 **google-services.json** 다운로드 버튼
2. 다운받은 파일을 프로젝트의 `android/app/google-services.json` 위치에 덮어쓰기
3. 빌드 클린:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## ✅ 검증

Google 로그인 → 계정 선택 → **이번엔 Home 화면으로 진입**해야 합니다.

만약 여전히 에러면:
1. Firebase Console → **Authentication** → **Sign-in method** → **Google** 토글 ON 확인
2. 에러 메시지 정확히 캡처해서 알려주세요 (어떤 에러인지에 따라 다음 단계 다름)

## 📝 iOS의 경우

iOS는 SHA-1 안 필요해요. iOS에서만 안 되면 다른 문제:

1. `ios/Runner/GoogleService-Info.plist` 존재 확인
2. `Info.plist`의 `CFBundleURLTypes`에 reversed client ID 등록 확인
3. Firebase Console에서 iOS 앱의 **Bundle ID**가 실제 앱 Bundle ID와 일치하는지

## 🚫 코드는 건드리지 마세요

이미 작성된 `AuthService.signInWithGoogle()` 코드는 정상입니다.
이 가이드대로 따라했는데도 안 되면 그때 다시 진단합니다.
