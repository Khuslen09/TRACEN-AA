#!/bin/sh
set -e

# Flutter 설치
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Secrets.xcconfig 생성
cat > "$CI_PRIMARY_REPOSITORY_PATH/ios/Flutter/Secrets.xcconfig" << EOF
GOOGLE_MAPS_API_KEY = $GOOGLE_MAPS_API_KEY
GEMINI_API_KEY = $GEMINI_API_KEY
EOF

# .env 파일 생성
cat > "$CI_PRIMARY_REPOSITORY_PATH/.env" << EOF
GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
GEMINI_API_KEY=$GEMINI_API_KEY
EOF

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

# Flutter SPM 비활성화
flutter config --no-enable-swift-package-manager

# CocoaPods 설치 — Xcode Cloud는 flutter build를 거치지 않고 바로 xcodebuild를
# 실행하므로, Podfile.lock 기반 Pods-Runner-*.xcfilelist 등 지원 파일이
# 이 단계에서 직접 생성돼 있어야 함 (없으면 "Unable to load contents of
# file list" 에러로 빌드 실패).
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install