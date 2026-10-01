import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 지표 패널 ↔ 지도 패널의 3단 스냅 지점.
enum TrackingSnapState { metricsExpanded, balanced, mapExpanded }

/// 러닝/워킹/사이클링 실시간 기록 화면의 위아래 2분할 레이아웃.
///
/// 지표 패널(위) ↔ 지도 패널(아래)을 핸들로 드래그해 비율을 바꾸고, 손을
/// 떼면 가장 가까운(또는 빠르게 튕겼으면 그 방향의 다음) 스냅 지점으로
/// 애니메이션 이동한다. 컨트롤 바는 두 패널과 무관하게 항상 하단에 떠 있다.
///
/// [metricsPanelBuilder]는 "스냅 상태"가 아니라 **지표 패널의 실제 현재
/// 높이(px)**를 받는다 — 드래그 도중 손가락이 만들어낸 임의의 높이에서도
/// 내부 레이아웃이 그 높이에 맞는 걸 즉시 고르게 하기 위함(스냅 지점 사이의
/// 중간값으로 전환 타이밍을 잡으면 그 타이밍과 실제 공간이 어긋나 overflow가
/// 날 수 있음 — 호출하는 쪽(TrackingMetricsPanel)이 이 높이 기준으로 직접
/// 레이아웃을 고르고, 이 위젯은 추가로 ClipRect로 안전망을 깐다).
class SplitTrackingLayout extends StatefulWidget {
  final Widget Function(BuildContext context, double metricsPanelHeight)
  metricsPanelBuilder;

  /// 스냅 상태와 무관하게 한 번만 빌드되는 지도 패널.
  final Widget mapPanel;

  final Widget controlsBar;
  final TrackingSnapState initialSnapState;

  const SplitTrackingLayout({
    super.key,
    required this.metricsPanelBuilder,
    required this.mapPanel,
    required this.controlsBar,
    this.initialSnapState = TrackingSnapState.balanced,
  });

  @override
  State<SplitTrackingLayout> createState() => _SplitTrackingLayoutState();
}

class _SplitTrackingLayoutState extends State<SplitTrackingLayout>
    with SingleTickerProviderStateMixin {
  static const _handleAreaHeight = 28.0;
  static const _mapExpandedHeight = 100.0; // 스펙: 약 90~110px
  static const _metricsExpandedFraction = 0.75;
  static const _balancedFraction = 0.40;
  static const _flickVelocityThreshold = 700.0; // px/s
  static const _snapDuration = Duration(milliseconds: 250);

  late final AnimationController _anim;
  Tween<double> _heightTween = Tween(begin: 0, end: 0);

  /// 지표 패널의 "현재 실제 높이" — 드래그 중에는 손가락을 그대로 따라가고,
  /// 드래그가 끝나면 애니메이션이 이 값을 목표 스냅 높이까지 옮긴다.
  double? _height;
  double _dragStartHeight = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: _snapDuration)
      ..addListener(() {
        setState(
          () => _height = _heightTween.transform(
            Curves.easeOutCubic.transform(_anim.value),
          ),
        );
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double _heightFor(TrackingSnapState state, double contentHeight) =>
      switch (state) {
        TrackingSnapState.metricsExpanded =>
          contentHeight * _metricsExpandedFraction,
        TrackingSnapState.balanced => contentHeight * _balancedFraction,
        TrackingSnapState.mapExpanded => _mapExpandedHeight,
      };

  void _onDragStart(DragStartDetails _) {
    _anim.stop();
    _dragStartHeight = _height ?? 0;
  }

  void _onDragUpdate(DragUpdateDetails details, double contentHeight) {
    final minH = _heightFor(TrackingSnapState.mapExpanded, contentHeight);
    final maxH = _heightFor(
      TrackingSnapState.metricsExpanded,
      contentHeight,
    );
    setState(() {
      _dragStartHeight += details.delta.dy;
      _height = _dragStartHeight.clamp(minH, maxH);
    });
  }

  void _onDragEnd(DragEndDetails details, double contentHeight) {
    const order = [
      TrackingSnapState.mapExpanded,
      TrackingSnapState.balanced,
      TrackingSnapState.metricsExpanded,
    ]; // 높이 오름차순
    final heights = [for (final s in order) _heightFor(s, contentHeight)];
    final current = _height ?? heights[1];

    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < heights.length; i++) {
      final d = (heights[i] - current).abs();
      if (d < best) {
        best = d;
        nearest = i;
      }
    }

    final vy = details.velocity.pixelsPerSecond.dy;
    if (vy.abs() >= _flickVelocityThreshold) {
      // 아래로 빠르게 튕기면(+dy) 지표 패널이 커지는 방향(인덱스 증가),
      // 위로 튕기면(-dy) 지도 패널이 커지는 방향(인덱스 감소).
      nearest = (vy > 0)
          ? (nearest + 1).clamp(0, heights.length - 1)
          : (nearest - 1).clamp(0, heights.length - 1);
    }

    _heightTween = Tween(begin: current, end: heights[nearest]);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = constraints.maxHeight - _handleAreaHeight;
        _height ??= _heightFor(widget.initialSnapState, contentHeight);
        final metricsHeight = _height!.clamp(0.0, contentHeight);
        final mapHeight = (contentHeight - metricsHeight).clamp(
          0.0,
          contentHeight,
        );

        return Stack(
          children: [
            Column(
              children: [
                // 핸들 + 지표 패널 — 드래그 제스처가 이 영역에만 반응하므로
                // 지도 팬/줌과 절대 충돌하지 않는다.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _onDragStart,
                  onVerticalDragUpdate: (d) =>
                      _onDragUpdate(d, contentHeight),
                  onVerticalDragEnd: (d) => _onDragEnd(d, contentHeight),
                  child: Column(
                    children: [
                      ClipRect(
                        child: SizedBox(
                          height: metricsHeight,
                          width: double.infinity,
                          child: widget.metricsPanelBuilder(
                            context,
                            metricsHeight,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: _handleAreaHeight,
                        child: const Center(child: _HandlePill()),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: mapHeight, child: widget.mapPanel),
              ],
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: widget.controlsBar),
          ],
        );
      },
    );
  }
}

class _HandlePill extends StatelessWidget {
  const _HandlePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.gray300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
