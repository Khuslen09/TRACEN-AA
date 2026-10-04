final _hangulPattern = RegExp(r'[가-힣]');

/// 문자열에 한글 음절이 하나라도 포함돼 있는지 — 공유 카드 위치명의
/// 스크립트별 폰트 선택(한글 포함 → IBM Plex Sans KR, 아니면 Unbounded —
/// Unbounded엔 한글 글립이 없음)에 쓰인다.
bool containsHangul(String text) => _hangulPattern.hasMatch(text);
