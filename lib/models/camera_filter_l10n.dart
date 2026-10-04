import '../l10n/generated/app_localizations.dart';
import 'camera_filter.dart';

/// [TracenFilter]를 화면에서 쓸 때 — 필터 이름은 브랜드명으로 취급해
/// ko/en/mn 전부 영어로 고정돼 있음(ARB의 filterGoldenRoute 등 참고).
/// 그래도 l10n을 통해서 읽는 이유는, 나중에 특정 언어만 번역하기로 바뀌어도
/// 호출부를 안 건드리고 ARB만 고치면 되게 하기 위함.
extension TracenFilterLabel on TracenFilter {
  String label(AppLocalizations l10n) => switch (this) {
    TracenFilter.goldenRoute => l10n.filterGoldenRoute,
    TracenFilter.nightTrace => l10n.filterNightTrace,
    TracenFilter.fadedMap => l10n.filterFadedMap,
    TracenFilter.monoPath => l10n.filterMonoPath,
  };
}
