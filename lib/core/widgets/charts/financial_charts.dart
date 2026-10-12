import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../localization/localization.dart';
import '../../theme/app_colors.dart';
import '../currency_price_display.dart';

/// مخطط بياني منحني انسيابي (Apple Stocks / Health style) لحجم المبيعات والأرباح
class BezierSalesChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String currencyCode;
  final Color primaryColor;
  final double height;

  const BezierSalesChart({
    super.key,
    required this.values,
    required this.labels,
    this.currencyCode = 'SAR',
    this.primaryColor = AppColors.primaryBlue,
    this.height = 160,
  });

  @override
  State<BezierSalesChart> createState() => _BezierSalesChartState();
}

class _BezierSalesChartState extends State<BezierSalesChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(BezierSalesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'chart_no_data'.i18n(),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final double maxValue = widget.values.reduce(math.max);
    final double safeMax = maxValue <= 0 ? 100.0 : maxValue * 1.15;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedIndex != null && _selectedIndex! < widget.values.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.labels[_selectedIndex!],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    CurrencyPriceDisplay(
                      amount: widget.values[_selectedIndex!],
                      currency: widget.currencyCode,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onTapDown: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localPos = box.globalToLocal(details.globalPosition);
                final segmentWidth = box.size.width / (widget.values.length - 1).clamp(1, 999);
                final index = (localPos.dx / segmentWidth).round().clamp(0, widget.values.length - 1);
                setState(() => _selectedIndex = index);
              },
              child: SizedBox(
                height: widget.height,
                child: CustomPaint(
                  painter: _BezierChartPainter(
                    values: widget.values,
                    progress: _animation.value,
                    color: widget.primaryColor,
                    safeMax: safeMax,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.labels.length, (i) {
                final isSelected = _selectedIndex == i;
                return Text(
                  widget.labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? widget.primaryColor : AppColors.textTertiary,
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _BezierChartPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final Color color;
  final double safeMax;
  final int? selectedIndex;

  _BezierChartPainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.safeMax,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final double width = size.width;
    final double height = size.height;
    final double dx = width / (values.length - 1);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final double normalized = (values[i] / safeMax).clamp(0.0, 1.0);
      final double x = i * dx;
      final double y = height - (normalized * height * progress);
      points.add(Offset(x, y));
    }

    // رسم الخطوط الشبكية الأفقية الناعمة (iOS Gridlines)
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      final double y = height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // مسار المنحنى المترابط بالبيزييه
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY2 = p1.dy;

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    // تظليل التدرج اللوني أسفل المنحنى (Gradient Fill)
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, height)
      ..lineTo(points.first.dx, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.32 * progress),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // رسم الخط الخارجي للمنحنى
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // رسم نقاط البيانات التفاعلية
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isSelected = selectedIndex == i;
      final double radius = isSelected ? 5.5 : 3.5;

      if (isSelected) {
        // خط التحديد العمودي
        final markerPaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, height), markerPaint);
      }

      canvas.drawCircle(p, radius, dotPaint);
      canvas.drawCircle(p, radius, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BezierChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.values != values;
  }
}

/// مخطط الدونات المالي الدائري (Cash Flow & Financial Distribution Donut)
class CashFlowDonutChart extends StatefulWidget {
  final double collectedAmount;
  final double remainingAmount;
  final double debtAmount;
  final String currencyCode;
  final double size;

  const CashFlowDonutChart({
    super.key,
    required this.collectedAmount,
    required this.remainingAmount,
    required this.debtAmount,
    this.currencyCode = 'SAR',
    this.size = 140,
  });

  @override
  State<CashFlowDonutChart> createState() => _CashFlowDonutChartState();
}

class _CashFlowDonutChartState extends State<CashFlowDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(CashFlowDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectedAmount != widget.collectedAmount ||
        oldWidget.remainingAmount != widget.remainingAmount ||
        oldWidget.debtAmount != widget.debtAmount) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double total = widget.collectedAmount + widget.remainingAmount + widget.debtAmount;
    final double safeTotal = total <= 0 ? 1.0 : total;

    final collectedRatio = (widget.collectedAmount / safeTotal).clamp(0.0, 1.0);
    final remainingRatio = (widget.remainingAmount / safeTotal).clamp(0.0, 1.0);
    final debtRatio = (widget.debtAmount / safeTotal).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _DonutChartPainter(
                      collectedRatio: collectedRatio,
                      remainingRatio: remainingRatio,
                      debtRatio: debtRatio,
                      animationProgress: _animation.value,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'common_total'.i18n(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: CurrencyPriceDisplay(
                          amount: total,
                          currency: widget.currencyCode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DonutLegendItem(
                    color: AppColors.primaryGreen,
                    title: 'dashboard_cash_collected'.i18n(),
                    amount: widget.collectedAmount,
                    ratio: collectedRatio,
                    currencyCode: widget.currencyCode,
                  ),
                  const SizedBox(height: 8),
                  _DonutLegendItem(
                    color: AppColors.primaryBlue,
                    title: 'dashboard_goods_in_market'.i18n(),
                    amount: widget.remainingAmount,
                    ratio: remainingRatio,
                    currencyCode: widget.currencyCode,
                  ),
                  const SizedBox(height: 8),
                  _DonutLegendItem(
                    color: AppColors.statusDanger,
                    title: 'dashboard_total_debt'.i18n(),
                    amount: widget.debtAmount,
                    ratio: debtRatio,
                    currencyCode: widget.currencyCode,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DonutLegendItem extends StatelessWidget {
  final Color color;
  final String title;
  final double amount;
  final double ratio;
  final String currencyCode;

  const _DonutLegendItem({
    required this.color,
    required this.title,
    required this.amount,
    required this.ratio,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title (${(ratio * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              CurrencyPriceDisplay(
                amount: amount,
                currency: currencyCode,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double collectedRatio;
  final double remainingRatio;
  final double debtRatio;
  final double animationProgress;

  _DonutChartPainter({
    required this.collectedRatio,
    required this.remainingRatio,
    required this.debtRatio,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.5)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2;

    void drawSegment(double ratio, Color color) {
      if (ratio <= 0) return;
      final sweepAngle = (2 * math.pi * ratio) * animationProgress;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + 0.05,
        math.max(sweepAngle - 0.1, 0.01),
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawSegment(collectedRatio, AppColors.primaryGreen);
    drawSegment(remainingRatio, AppColors.primaryBlue);
    drawSegment(debtRatio, AppColors.statusDanger);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.collectedRatio != collectedRatio ||
        oldDelegate.remainingRatio != remainingRatio ||
        oldDelegate.debtRatio != debtRatio;
  }
}
