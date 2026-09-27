#!/bin/sh
set -e

# 각 단계 앞에 마커를 남겨서, 실패 시 로그에서 어디까지 진행됐는지
# (script failed 요약 줄만 봐도) 바로 알 수 있게 함.

echo "[ci_post_clone] 1/7 Flutter SDK 준비"
# Xcode Cloud가 이전 빌드의 $HOME을 재사용하는 경우 git clone이
# "destination path already exists" 로 실패할 수 있어 존재 여부 체크.
if [ -d "$HOME/flutter" ]; then
  echo "[ci_post_clone] 기존 $HOME/flutter 발견 — 재클론 생략, pull만 시도"
  git -C "$HOME/flutter" pull --ff-only || true
else
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"
flutter --version

echo "[ci_post_clone] 2/7 iOS 엔진 아티팩트 precache"
# pod install의 post-install 훅(podhelper.rb)이 Flutter.xcframework를
# 참조하는데, flutter pub get만으로는 이게 안 받아져 있어서
# "Flutter.xcframework must exist" 에러로 pod install이 실패함.
flutter precache --ios

echo "[ci_post_clone] 3/7 Secrets.xcconfig 생성"
cat > "$CI_PRIMARY_REPOSITORY_PATH/ios/Flutter/Secrets.xcconfig" << EOF
GOOGLE_MAPS_API_KEY = $GOOGLE_MAPS_API_KEY
EOF

echo "[ci_post_clone] 4/7 .env 파일 생성"
cat > "$CI_PRIMARY_REPOSITORY_PATH/.env" << EOF
GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
GEMINI_API_KEY=$GEMINI_API_KEY
EOF

echo "[ci_post_clone] 5/7 flutter pub get"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "[ci_post_clone] 6/7 Flutter SPM 비활성화"
flutter config --no-enable-swift-package-manager

echo "[ci_post_clone] 7/7 CocoaPods 설치"
# Xcode Cloud는 flutter build를 거치지 않고 바로 xcodebuild를 실행하므로,
# Podfile.lock 기반 Pods-Runner-*.xcfilelist 등 지원 파일이 이 단계에서
# 직접 생성돼 있어야 함 (없으면 "Unable to load contents of file list"
# 에러로 빌드 실패).
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "[ci_post_clone] 완료"