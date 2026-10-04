import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 사진 파일을 앱의 영구 저장소로 복사하는 유틸.
///
/// image_picker가 반환하는 경로는 OS의 캐시 디렉토리라서
/// 시스템이 언제든 정리할 수 있음 → 앱 재시작 후 핀 사진이 사라지는
/// 버그 방지를 위해 항상 앱 전용 디렉토리로 복사해서 저장한다.
///
/// 저장 위치: `<ApplicationDocumentsDirectory>/photos/<uuid>.jpg`
class PhotoStorage {
  PhotoStorage._();

  static const _subdir = 'photos';

  /// [sourcePath]의 파일을 영구 저장소로 복사하고, 새 경로 반환.
  ///
  /// 원본 확장자 유지. 파일명은 timestamp + 짧은 랜덤 — uuid 패키지 없이
  /// 충분히 충돌 안 나게.
  static Future<String> persist(String sourcePath) async {
    final dir = await _ensureDir();
    final ext = p.extension(sourcePath).isNotEmpty
        ? p.extension(sourcePath)
        : '.jpg';
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, fileName));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  /// 바이트를 영구 저장소(또는 [subdir] 하위 폴더)에 직접 써서 저장하고,
  /// 새 경로 반환 — [persist]와 같은 `<micros><ext>` 네이밍이지만, 이미
  /// 메모리에 있는 바이트(예: 필터 적용 후 인코딩한 JPEG)를 쓸 때 쓴다.
  static Future<String> persistBytes(
    Uint8List bytes, {
    String ext = '.jpg',
    String subdir = _subdir,
  }) async {
    final dir = await _ensureDir(subdir: subdir);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, fileName));
    await dest.writeAsBytes(bytes);
    return dest.path;
  }

  /// 핀 삭제 시 함께 지우기. 파일이 없어도 throw 안 함.
  static Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 파일 삭제 실패해도 앱은 계속 동작해야 함
    }
  }

  static Future<Directory> _ensureDir({String subdir = _subdir}) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
