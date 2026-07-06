# 🔒 Firebase Security Rules 적용 가이드

Tracen이 발표 준비될 즈음 (또는 정말 다른 사용자가 써볼 가능성이 생기면)
**테스트 모드를 끄고 정식 보안 규칙으로 전환**해야 합니다.

테스트 모드는 누구나 모든 데이터를 읽고 쓸 수 있어요. 시연 영상에 Firebase
콘솔이 잠깐만 비춰져도 다른 사람이 우리 데이터를 다 가져갈 수 있습니다.

## ⚠️ 적용 시점

- **개발 중**: 테스트 모드 유지 (편의)
- **첫 외부 시연 직전**: 아래 규칙 적용
- **앱스토어 배포**: 무조건 정식 규칙

## 1. Firestore Rules 적용

1. https://console.firebase.google.com → Tracen 프로젝트
2. 좌측 메뉴 **Firestore Database** → 상단 탭 **규칙**
3. 기존 내용 모두 삭제
4. `firestore.rules` 파일 내용 전체 복사 → 붙여넣기
5. 우상단 **게시** 클릭

## 2. Storage Rules 적용

1. 같은 콘솔에서 좌측 **Storage** → 상단 탭 **규칙**
2. 기존 내용 모두 삭제
3. `storage.rules` 파일 내용 전체 복사 → 붙여넣기
4. **게시**

## 3. 적용 후 검증

규칙이 너무 빡빡하면 정상 동작하던 기능까지 막힐 수 있어요. 적용 후 반드시 확인:

- [ ] 새 가입 → users/{uid} 문서 생성됨
- [ ] 산책 후 종료 → routes/{uuid} 문서 + pins 서브컬렉션 생성됨
- [ ] 핀에 사진 → Storage의 users/{uid}/photos/... 업로드됨
- [ ] 다른 기기 로그인 → pullAll로 데이터 다운로드됨
- [ ] 프로필 사진 변경 → users/{uid}/profile/avatar.jpg 업로드됨

만약 어떤 동작이 권한 에러로 막히면, Firebase Console의 **Firestore → 사용량**
탭에서 거부된 요청을 확인할 수 있습니다. 거기서 "어떤 경로가 거부됐는지"
보고 규칙 조정하세요.

## 4. 회원 탈퇴 시 데이터 정리 (TODO)

현재 클라이언트에서 회원 탈퇴 시 `users/{uid}` 문서만 지우고
`users/{uid}/routes/...` 서브컬렉션은 못 지웁니다 (Firestore 정책상
서브컬렉션 cascade delete 불가).

발표 후 추가 작업으로 **Cloud Function**을 만들어 사용자 삭제 트리거 시
모든 서브컬렉션을 정리하는 게 좋습니다:

```javascript
// 예시 (functions/index.js)
exports.cleanupUserData = functions.auth.user().onDelete(async (user) => {
  const firestore = admin.firestore();
  const storage = admin.storage().bucket();

  // Firestore: users/{uid} 하위 모두 삭제
  await firestore.recursiveDelete(firestore.collection('users').doc(user.uid));

  // Storage: users/{uid}/ 폴더 삭제
  await storage.deleteFiles({ prefix: `users/${user.uid}/` });
});
```

이건 발표 범위 밖이라 일단 TODO로 남기고, 발표 후 Phase 2 작업으로.

## 5. 디버그 — 거부 메시지 보기

앱에서 "permission-denied" 에러가 뜨면, 그 요청이 어떤 규칙에 걸렸는지
Firebase Console의 **Firestore → 규칙 → 규칙 플레이그라운드**에서 시뮬레이션
가능합니다. 작성자/경로/문서 데이터 입력하고 "실행" 누르면 결과가 나와요.
