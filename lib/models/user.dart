import 'package:cloud_firestore/cloud_firestore.dart';

/// AA 사용자 모델.
///
/// Firebase Auth의 User와 Firestore의 users/{uid} 문서를 잇는 어댑터.
/// - [uid]: Firebase Auth UID — DB 외래키
/// - [photoUrl]: 프로필 사진 (Google 로그인 시 자동, 나중에 직접 업로드 기능 추가 가능)
/// - [createdAt]: Firestore에서 처음 INSERT된 시각 (서버 타임스탬프)
class AppUser {
  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.photoUrl,
    this.createdAt,
  });

  /// Firestore 저장용 Map 변환.
  /// createdAt은 서버 타임스탬프로 처리 (클라이언트 시계 신뢰 X).
  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'email': email,
    'name': name,
    'photoUrl': photoUrl,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    DateTime? createdAt,
  }) => AppUser(
    uid: uid ?? this.uid,
    email: email ?? this.email,
    name: name ?? this.name,
    photoUrl: photoUrl ?? this.photoUrl,
    createdAt: createdAt ?? this.createdAt,
  );
}
