import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// اتجاه تموج الشيمر
enum ShimmerDirection {
  rtl, // من اليمين إلى اليسار (الافتراضي للواجهات العربية)
  ltr, // من اليسار إلى اليمين
  ttb, // من الأعلى إلى الأسفل
  btt, // من الأسفل إلى الأعلى
}

/// ويدجت الشيمر الأساسي فائق النعومة متوافق تماماً مع فلسفة تصميم آبل و مساعد
/// يوفر تدرجاً ضوئياً سلساً (Smooth Shimmer Wave) مع مراعاة الوضع الليلي والاتجاه RTL
class AppShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final ShimmerDirection direction;
  final Color? baseColor;
  final Color? highlightColor;
  final bool enabled;

  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.direction = ShimmerDirection.rtl,
    this.baseColor,
    this.highlightColor,
    this.enabled = true,
  });

  /// باني مسبق لشيمر أولي للبطاقات
  static Widget card({
    Key? key,
    double? width,
    double height = 90,
    EdgeInsetsGeometry? margin,
  }) =>
      ShimmerCard(key: key, width: width, height: height, margin: margin);

  /// باني مسبق لعنصر قائمة (List Tile)
  static Widget listTile({
    Key? key,
    bool hasLeading = true,
    bool hasTrailing = true,
    EdgeInsetsGeometry? padding,
  }) =>
      ShimmerListTile(
        key: key,
        hasLeading: hasLeading,
        hasTrailing: hasTrailing,
        padding: padding,
      );

  /// باني مسبق لقائمة متكررة من عناصر الشيمر
  static Widget list({
    Key? key,
    int itemCount = 5,
    EdgeInsetsGeometry? padding,
    bool isCards = false,
  }) =>
      ShimmerList(
        key: key,
        itemCount: itemCount,
        padding: padding,
        isCards: isCards,
      );

  /// باني مسبق لهيكل لوحة التحكم الرئيسية (Dashboard)
  static Widget dashboard({Key? key}) => ShimmerDashboard(key: key);

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AppShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (widget.enabled) {
        _controller.repeat();
      }
    }
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBase = isDark
        ? AppColors.darkSurfaceMuted
        : const Color(0xFFE8ECEF);
    final defaultHighlight = isDark
        ? AppColors.darkSurfaceElevated
        : const Color(0xFFF9FAFB);

    final effectiveBase = widget.baseColor ?? defaultBase;
    final effectiveHighlight = widget.highlightColor ?? defaultHighlight;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;

        Alignment begin;
        Alignment end;

        switch (widget.direction) {
          case ShimmerDirection.rtl:
            begin = Alignment(2.0 - 4.0 * progress, -0.3);
            end = Alignment(begin.x - 1.5, 0.3);
            break;
          case ShimmerDirection.ltr:
            begin = Alignment(-2.0 + 4.0 * progress, -0.3);
            end = Alignment(begin.x + 1.5, 0.3);
            break;
          case ShimmerDirection.ttb:
            begin = Alignment(0.0, -2.0 + 4.0 * progress);
            end = Alignment(0.0, begin.y + 1.5);
            break;
          case ShimmerDirection.btt:
            begin = Alignment(0.0, 2.0 - 4.0 * progress);
            end = Alignment(0.0, begin.y - 1.5);
            break;
        }

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: begin,
              end: end,
              colors: [
                effectiveBase,
                effectiveHighlight,
                effectiveBase,
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// هيكل عظمي مفرد (Bone) لبناء عناصر الشيمر
class ShimmerBone extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const ShimmerBone({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.color,
  });

  /// عظم دائري (مثل الصورة الرمزية أو الأيقونة)
  const ShimmerBone.circle({
    super.key,
    required double size,
    this.margin,
    this.color,
  })  : width = size,
        height = size,
        shape = BoxShape.circle,
        borderRadius = null;

  /// عظم كبسولي (Pill) للشارات والأزرار
  const ShimmerBone.pill({
    super.key,
    this.width = 64,
    this.height = 24,
    this.margin,
    this.color,
  })  : shape = BoxShape.rectangle,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? AppColors.darkSurfaceMuted
        : const Color(0xFFE8ECEF);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? defaultBg,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(8))
            : null,
      ),
    );
  }
}

/// بطاقة شيمر على نمط AppCard
class ShimmerCard extends StatelessWidget {
  final double? width;
  final double height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Widget? customContent;

  const ShimmerCard({
    super.key,
    this.width,
    this.height = 100,
    this.margin,
    this.padding,
    this.borderRadius = 16,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;

    return Container(
      width: width,
      height: customContent == null ? height : null,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: defaultBorder, width: 0.8),
      ),
      child: customContent ??
          Row(
            children: [
              const ShimmerBone.circle(size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ShimmerBone(width: 130, height: 14),
                    SizedBox(height: 8),
                    ShimmerBone(width: 80, height: 11),
                  ],
                ),
              ),
              const ShimmerBone.pill(width: 54, height: 24),
            ],
          ),
    );
  }
}

/// عنصر قائمة شيمر مخصص للطلبات والشحنات والعملاء
class ShimmerListTile extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final EdgeInsetsGeometry? padding;

  const ShimmerListTile({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      height: 84,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      customContent: Row(
        children: [
          if (hasLeading) ...[
            const ShimmerBone(
              width: 44,
              height: 44,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                ShimmerBone(width: 140, height: 14),
                SizedBox(height: 8),
                ShimmerBone(width: 90, height: 11),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                ShimmerBone.pill(width: 60, height: 22),
                SizedBox(height: 6),
                ShimmerBone(width: 40, height: 10),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// بطاقة إحصائيات شيمر متوافقة مع لوحة التحكم
class ShimmerMetricCard extends StatelessWidget {
  const ShimmerMetricCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: defaultBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBone(width: 65, height: 12),
              ShimmerBone.circle(size: 26),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBone(width: 100, height: 20),
          const SizedBox(height: 8),
          const ShimmerBone.pill(width: 50, height: 16),
        ],
      ),
    );
  }
}

/// قائمة شيمر مكررة وسلسة
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry? padding;
  final bool isCards;

  const ShimmerList({
    super.key,
    this.itemCount = 6,
    this.padding,
    this.isCards = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return isCards ? const ShimmerCard() : const ShimmerListTile();
        },
      ),
    );
  }
}

/// هيكل شيمر كامل للوحة التحكم الرئيسية (Dashboard Shimmer)
class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;

    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // شريط العملات
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: defaultBorder, width: 0.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (_) => const ShimmerBone.pill(width: 80, height: 26),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // بطاقة البطل لصافي الأرباح (Hero Card)
          Container(
            height: 140,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: defaultBorder, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBone(width: 110, height: 15),
                    ShimmerBone.circle(size: 32),
                  ],
                ),
                const ShimmerBone(width: 180, height: 28),
                Row(
                  children: const [
                    ShimmerBone.pill(width: 90, height: 20),
                    SizedBox(width: 10),
                    ShimmerBone(width: 70, height: 12),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // شبكة الإحصائيات (2x2 Grid)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: List.generate(4, (_) => const ShimmerMetricCard()),
          ),
          const SizedBox(height: 24),

          // عنوان القسم
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBone(width: 120, height: 16),
              ShimmerBone(width: 60, height: 12),
            ],
          ),
          const SizedBox(height: 12),

          // معاملات أو طلبات حديثة
          const ShimmerListTile(),
          const ShimmerListTile(),
          const ShimmerListTile(),
        ],
      ),
    );
  }
}
