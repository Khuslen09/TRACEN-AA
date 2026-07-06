# Firestore 데이터 구조 설계

> 이 문서는 Tracen의 클라우드 백업 모델을 정의합니다.
> Week 2의 동기화 작업, Week 4의 Security Rules, 모든 후속 백엔드 작업의 기준입니다.
> **변경 시 PR로 합의 후 수정하세요.**

---

## 1. 동기화 전략 요약

**모델: 클라우드 백업 (Cloud Backup)**

- **읽기/쓰기의 진실 원천(source of truth)은 로컬 SQLite입니다.**
- 클라우드는 백업과 다기기 동기화를 위한 보조 저장소입니다.
- GPS 추적 중에는 클라우드를 호출하지 않습니다 (배터리/비용/오프라인 안정성).
- 여정 종료 시점에 한 번 통째로 업로드됩니다.
- 다른 기기에서 로그인하면 로그인 직후 1회 다운로드 → SQLite에 채워넣기.

이 결정의 근거:
- GPS 추적은 5m 간격으로 점이 쌓여서 한 시간 산책에 600~1200점이 발생합니다.
  Firestore에 이걸 매번 쓰면 무료 할당량을 시연 한 번에 다 씁니다.
- 모바일 GPS 앱의 데이터 무결성은 오프라인 우선이어야 합니다. 지하철, 산속,
  배터리 절약 모드 등에서도 기록이 끊기면 안 됩니다.

---

## 2. 컬렉션 구조

```
users/{uid}                        ← 사용자 프로필
├─ uid          string
├─ email        string
├─ name         string?
├─ photoUrl     string?            ← Google 로그인 시 자동 / 추후 직접 업로드
└─ createdAt    timestamp

users/{uid}/routes/{routeId}       ← 여정 (1 사용자 - N 여정)
├─ id           string             ← 클라이언트가 생성한 UUID (SQLite의 int id와 별개)
├─ title        string
├─ startedAt    timestamp
├─ endedAt      timestamp?
├─ distance     number             ← meters
├─ pointCount   number             ← Polyline 다운로드 전 미리보기용
├─ pinCount     number             ← 카드 표시용
├─ encodedPath  string             ← Google polyline encoded (아래 3.1 참조)
└─ updatedAt    timestamp          ← 충돌 감지용 (last-write-wins)

users/{uid}/routes/{routeId}/pins/{pinId}    ← 핀 (1 여정 - N 핀)
├─ id           string             ← 클라이언트 UUID
├─ lat          number
├─ lng          number
├─ photoUrl     string?            ← Firebase Storage URL (있으면)
├─ photoStoragePath  string?       ← 삭제 시 Storage에서도 지우기 위한 경로
├─ memo         string?
└─ createdAt    timestamp
```

### 왜 이 구조인가

**1. 사용자별 서브컬렉션** (`users/{uid}/routes`) — 평면 구조 (`routes/{id}`)에 `userId` 필드로
   필터링하는 방식과 비교했을 때:
   - Security Rules가 단순해짐: `request.auth.uid == userId` 한 줄로 끝
   - 쿼리에 `where('userId', '==', uid)` 안 적어도 자동 필터링
   - 단점: 다른 사용자 데이터를 한 번에 보는 어드민 쿼리가 어려움 (졸업 프로젝트 무관)

**2. pins를 routes의 서브컬렉션으로** — 핀은 항상 한 여정에 속하고, 여정 삭제 시 함께 삭제되므로
   부모-자식 관계가 자연스럽습니다. 여정 화면 진입 시 `users/uid/routes/rid/pins`만
   쿼리하면 끝.

**3. routePoints는 Firestore에 저장 안 함**. 대신 `encodedPath` 단일 문자열로 압축
   저장합니다. 자세한 내용은 다음 섹션.

---

## 3. 데이터 압축 / 외부 저장

### 3.1 routePoints → encoded polyline

GPS 점들을 `[{lat, lng, time}, ...]` 배열로 그대로 저장하면:
- 1시간 산책 = 약 800개 점 = 800개 Firestore 문서 또는 800개 배열 항목
- 문서당 1KB만 잡아도 800KB. 무료 할당량의 큰 비중.

대신 [Google Polyline Algorithm](https://developers.google.com/maps/documentation/utilities/polylinealgorithmformat)
로 인코딩한 단일 문자열을 저장합니다:
- 800개 점이 약 5KB 문자열로 압축
- Flutter의 `flutter_polyline_points` 패키지 또는 직접 인코딩 함수로 가능
- 시간 정보(`time`)는 손실됨 — 우리 MVP는 점별 시간이 필요한 기능 없으므로 OK

⚠️ 만약 향후 "pace 그래프" 같은 기능을 위해 점별 시간이 필요해지면 이 결정을 재검토해야
합니다 (Running 모드 구현 시점에).

### 3.2 사진 → Firebase Storage

핀의 사진은 Firestore가 아닌 **Firebase Storage**에 저장합니다.
- Firestore 문서당 최대 1MiB. 사진은 보통 1~5MB라 base64로 못 넣음.
- Storage가 이미지 파일에 적합하고, CDN으로 빠르게 서빙됨.

저장 경로 규칙:
```
users/{uid}/photos/{routeId}/{pinId}.jpg
```

이렇게 하면:
- 사용자 삭제 시 `users/{uid}/photos/`만 통째로 지우면 됨
- 여정 삭제 시 `users/{uid}/photos/{routeId}/`만 지우면 됨
- 사용자 격리 보안 규칙 적용 쉬움

각 핀 문서에는 `photoUrl`(다운로드용 HTTPS URL)과 `photoStoragePath`(삭제용 경로)
둘 다 저장합니다. URL만으로는 삭제할 수 없기 때문.

---

## 4. ID 정책 — UUID vs Auto-ID

**결정: 클라이언트 UUID 사용**

- SQLite는 `INTEGER PRIMARY KEY AUTOINCREMENT`로 정수 id 사용 중
- Firestore는 문자열 ID. 그래서 SQLite int id와 별도로 `route.uuid`, `pin.uuid` 필드를 추가해야 함

이유:
- 오프라인에서 생성된 항목도 즉시 ID를 가지므로 sync 충돌 시 매칭 가능
- Firestore의 auto-id는 서버 도착 후에야 결정되어 오프라인 우선 모델에 안 맞음

**작업: SQLite 스키마에 `uuid` 컬럼 추가 필요** (단계 3에서 처리)

---

## 5. 동기화 시점

| 이벤트 | 동작 |
|---|---|
| 회원가입 | `users/{uid}` 문서 생성 (이미 AuthService가 처리) |
| 여정 시작 | 클라우드 호출 없음 (로컬에만 INSERT) |
| GPS 점 수신 | 클라우드 호출 없음 |
| 핀 추가 | 클라우드 호출 없음. 사진 파일도 일단 로컬만 |
| 여정 종료 | **여기서 한 번에 업로드:** route 문서 + 모든 pin 문서 + 모든 사진 Storage 업로드 |
| 핀 삭제 (정지된 여정에서) | 즉시 클라우드 동기화 (route + pin + 사진) |
| 여정 삭제 | 즉시 클라우드 동기화 |
| 다른 기기에서 로그인 | 로그인 직후 1회 풀 다운로드 (route 메타데이터 + pin 메타데이터, 사진은 lazy) |
| 같은 기기에서 두 번째 로그인 | 다운로드 안 함 (로컬에 이미 있음) |

### 동기화 큐

여정 종료 시 네트워크가 끊겨있을 수 있습니다. 그래서 별도의 sync 큐를 둡니다:

```sql
CREATE TABLE sync_queue (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  entity      TEXT NOT NULL,       -- 'route' | 'pin' | 'route_delete' | 'pin_delete'
  entity_id   INTEGER NOT NULL,    -- 로컬 SQLite id
  action      TEXT NOT NULL,       -- 'upload' | 'delete'
  created_at  TEXT NOT NULL,
  attempts    INTEGER DEFAULT 0
);
```

업로드 실패 시 큐에 남아있다가 다음 앱 시작 / 네트워크 복구 시 재시도.

---

## 6. 보안 규칙 (Week 4 작업)

지금은 테스트 모드(누구나 접근)로 두지만, 발표 전에 다음 규칙으로 전환:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;

      match /routes/{routeId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;

        match /pins/{pinId} {
          allow read, write: if request.auth != null && request.auth.uid == uid;
        }
      }
    }
  }
}
```

Storage도 동일 패턴:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{uid}/photos/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

---

## 7. 충돌 처리 전략

다기기 시나리오:
- 사용자가 폰 A에서 여정 a1을 만들고 종료 → 클라우드 업로드
- 폰 B에서 같은 계정 로그인 → a1 다운로드
- 폰 B에서 a1의 핀 하나 삭제 → 클라우드 동기화
- 폰 A에서 같은 a1의 다른 핀 삭제 → 클라우드 동기화

이 시나리오에서 **last-write-wins** 정책을 사용합니다. 두 변경이 다른 핀이라
실제로는 충돌하지 않지만, 만약 같은 핀을 양쪽에서 수정했다면 나중에 들어온 쓰기가
이깁니다. `updatedAt` 필드로 비교.

→ 캡스톤 시연에서 다기기 충돌이 발생할 가능성은 거의 없으므로 OK.
프로덕션 앱이라면 CRDT나 OT 같은 더 정교한 처리를 고려해야 합니다.

---

## 8. 비용 추정

Firebase 무료 할당량 (Spark plan):
- Firestore: 50K reads/day, 20K writes/day, 1GB storage
- Storage: 5GB, 1GB downloads/day

여정 1개당 비용:
- writes: route 1 + pins ~5 = **6 writes**
- storage: 사진 ~5장 × 500KB = **2.5MB**

→ 일 100개 여정 발표 시연 = 600 writes (할당량의 3%), 250MB (할당량의 5%) — 안전.

졸업 프로젝트로는 무료 플랜 충분합니다.
