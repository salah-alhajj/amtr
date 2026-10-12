import 'package:flutter/material.dart';

/// مكدس تنقل يدعم الانتقال الانزلاقي (انسحاب وانسحاب عكسي)
/// يحافظ على حالة الصفحات في الذاكرة (State Preservation)
/// ويراعي تلقائياً اتجاه اللغة (RTL/LTR) وموقع الصفحة الهدف.
class DirectionalSlideIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  const DirectionalSlideIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<DirectionalSlideIndexedStack> createState() =>
      _DirectionalSlideIndexedStackState();
}

class _DirectionalSlideIndexedStackState
    extends State<DirectionalSlideIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _previousIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didUpdateWidget(DirectionalSlideIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _previousIndex = _currentIndex;
      _currentIndex = widget.index;
      _isForward = _currentIndex > _previousIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final multiplier = isRtl ? -1.0 : 1.0;

    // تحديد اتجاه الإزاحة:
    // في الـ LTR: التقدم للأمام يأتي من اليمين (+1) ويخرج لليسار (-1)
    // في الـ RTL (العربية): التقدم للأمام يتدفق لليسار فيأتي من اليسار (-1) ويخرج لليمين (+1)
    final double enterSign = _isForward ? multiplier : -multiplier;
    final double exitSign = _isForward ? -multiplier : multiplier;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final isAnimating = _controller.isAnimating;
        final animVal = _animation.value;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (i) {
            final isCurrent = i == _currentIndex;
            final isPrevious = i == _previousIndex;
            final isVisible = isCurrent || (isAnimating && isPrevious);

            Offset offset = Offset.zero;
            double opacity = 1.0;

            if (isAnimating) {
              if (isCurrent) {
                offset = Offset(enterSign * (1.0 - animVal), 0);
                opacity = (0.7 + (0.3 * animVal)).clamp(0.0, 1.0);
              } else if (isPrevious) {
                offset = Offset(exitSign * animVal, 0);
                opacity = (1.0 - (0.3 * animVal)).clamp(0.0, 1.0);
              }
            }

            return Offstage(
              offstage: !isVisible,
              child: TickerMode(
                enabled: isVisible,
                child: FractionalTranslation(
                  translation: offset,
                  child: Opacity(
                    opacity: opacity,
                    child: widget.children[i],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
