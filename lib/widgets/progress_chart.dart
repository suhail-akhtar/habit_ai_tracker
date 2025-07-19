import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/theme.dart';

class ProgressChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final ChartType chartType;
  final Color? primaryColor;

  const ProgressChart({
    super.key,
    required this.data,
    required this.title,
    this.chartType = ChartType.line,
    this.primaryColor,
  });

  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              height: 200,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  switch (widget.chartType) {
                    case ChartType.line:
                      return _buildLineChart();
                    case ChartType.bar:
                      return _buildBarChart();
                    case ChartType.pie:
                      return _buildPieChart();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    if (widget.data.isEmpty) {
      return _buildEmptyChart();
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < widget.data.length) {
                  final date = widget.data[index]['date'] as DateTime;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '${date.day}',
                      style: AppTheme.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        minX: 0,
        maxX: widget.data.length.toDouble() - 1,
        minY: 0,
        maxY: _getMaxValue().toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: widget.data.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return FlSpot(
                index.toDouble(),
                (data['completedHabits'] as num).toDouble() * _animation.value,
              );
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                (widget.primaryColor ?? Theme.of(context).colorScheme.primary)
                    .withOpacity(0.3),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: widget.primaryColor ??
                      Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  (widget.primaryColor ?? Theme.of(context).colorScheme.primary)
                      .withOpacity(0.3),
                  (widget.primaryColor ?? Theme.of(context).colorScheme.primary)
                      .withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (widget.data.isEmpty) {
      return _buildEmptyChart();
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxValue().toDouble(),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < widget.data.length) {
                  final date = widget.data[index]['date'] as DateTime;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '${date.day}',
                      style: AppTheme.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        barGroups: widget.data.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (data['completedHabits'] as num).toDouble() *
                    _animation.value,
                color: widget.primaryColor ??
                    Theme.of(context).colorScheme.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieChart() {
    if (widget.data.isEmpty) {
      return _buildEmptyChart();
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            // Handle touch events
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: widget.data.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final value = (data['completedHabits'] as num).toDouble();
          final percentage = (value / _getTotalValue() * 100);

          return PieChartSectionData(
            color: _getColorForIndex(index),
            value: value * _animation.value,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'No data available',
            style: AppTheme.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  int _getMaxValue() {
    if (widget.data.isEmpty) return 10;
    return widget.data
            .map((data) => data['completedHabits'] as num)
            .reduce((a, b) => a > b ? a : b)
            .toInt() +
        1;
  }

  double _getTotalValue() {
    if (widget.data.isEmpty) return 1;
    return widget.data
        .map((data) => data['completedHabits'] as num)
        .reduce((a, b) => a + b)
        .toDouble();
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.infoColor,
    ];
    return colors[index % colors.length];
  }
}

enum ChartType {
  line,
  bar,
  pie,
}
