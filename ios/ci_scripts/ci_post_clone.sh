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