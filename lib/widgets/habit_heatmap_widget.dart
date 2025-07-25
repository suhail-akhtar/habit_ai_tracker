import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analytics_models.dart';
import '../providers/advanced_analytics_provider.dart';
import '../providers/user_provider.dart';

class HabitHeatmapWidget extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool showWeekdayLabels;
  final bool showMonthLabels;

  const HabitHeatmapWidget({
    super.key,
    this.startDate,
    this.endDate,
    this.showWeekdayLabels = true,
    this.showMonthLabels = true,
  });

  @override
  State<HabitHeatmapWidget> createState() => _HabitHeatmapWidgetState();
}

class _HabitHeatmapWidgetState extends State<HabitHeatmapWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHeatmapData();
    });
  }

  void _loadHeatmapData() {
    final provider = Provider.of<AdvancedAnalyticsProvider>(
      context,
      listen: false,
    );
    provider.loadHeatmapData(
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AdvancedAnalyticsProvider, UserProvider>(
      builder: (context, analyticsProvider, userProvider, child) {
        if (analyticsProvider.isLoadingHeatmap) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (analyticsProvider.error != null) {
          return Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load heatmap',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analyticsProvider.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadHeatmapData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final heatmapData = analyticsProvider.heatmapData;

        if (heatmapData.isEmpty) {
          return Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_view_week_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No activity data yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start completing habits to see your progress heatmap!',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.grid_view,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Activity Heatmap',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (!userProvider.isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHeatmapGrid(context, heatmapData),
                const SizedBox(height: 16),
                _buildLegend(context),
                const SizedBox(height: 8),
                _buildStats(context, heatmapData),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeatmapGrid(BuildContext context, List<HeatmapData> data) {
    // Group data by weeks
    final weeks = <List<HeatmapData>>[];
    final sortedData = data.toList()..sort((a, b) => a.date.compareTo(b.date));

    if (sortedData.isEmpty) return const SizedBox.shrink();

    // Start from Monday of the first week
    final firstDate = sortedData.first.date;
    final startOfWeek = firstDate.subtract(
      Duration(days: firstDate.weekday - 1),
    );

    // Create a map for quick lookup
    final dataMap = <String, HeatmapData>{};
    for (final data in sortedData) {
      dataMap[_dateKey(data.date)] = data;
    }

    // Generate grid data
    var currentDate = startOfWeek;
    final endDate = sortedData.last.date;

    while (currentDate.isBefore(endDate.add(const Duration(days: 7)))) {
      final week = <HeatmapData>[];

      for (int i = 0; i < 7; i++) {
        final dayData = dataMap[_dateKey(currentDate)];
        week.add(
          dayData ??
              HeatmapData(
                date: currentDate,
                completedHabits: 0,
                totalHabits: 0,
                completionRate: 0.0,
              ),
        );
        currentDate = currentDate.add(const Duration(days: 1));
      }

      weeks.add(week);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekday labels
          if (widget.showWeekdayLabels) _buildWeekdayLabels(context),

          // Heatmap grid
          Row(
            children: weeks
                .map((week) => _buildWeekColumn(context, week))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Column(
        children: weekdays
            .map(
              (day) => SizedBox(
                height: 16,
                child: Text(
                  day,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildWeekColumn(BuildContext context, List<HeatmapData> week) {
    return Column(
      children: week.map((data) => _buildHeatmapCell(context, data)).toList(),
    );
  }

  Widget _buildHeatmapCell(BuildContext context, HeatmapData data) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: data.getColor(Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Tooltip(
        message: _buildTooltipMessage(data),
        child: const SizedBox.expand(),
      ),
    );
  }

  String _buildTooltipMessage(HeatmapData data) {
    final dateStr = '${data.date.day}/${data.date.month}/${data.date.year}';
    final completionPercent = (data.completionRate * 100).toInt();

    if (data.totalHabits == 0) {
      return '$dateStr\nNo habits tracked';
    }

    return '$dateStr\n${data.completedHabits}/${data.totalHabits} habits ($completionPercent%)';
  }

  Widget _buildLegend(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Text(
          'Less',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          final intensity = index / 4.0;
          return Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Color.lerp(
                primaryColor.withOpacity(0.1),
                primaryColor,
                intensity,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          'More',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context, List<HeatmapData> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final totalDays = data.length;
    final activeDays = data.where((d) => d.completedHabits > 0).length;
    final averageCompletion =
        data.map((d) => d.completionRate).reduce((a, b) => a + b) / totalDays;
    final longestStreak = _calculateLongestStreak(data);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            'Active Days',
            '$activeDays/$totalDays',
            Icons.calendar_today,
          ),
          _buildStatItem(
            context,
            'Avg Completion',
            '${(averageCompletion * 100).toInt()}%',
            Icons.trending_up,
          ),
          _buildStatItem(
            context,
            'Best Streak',
            '$longestStreak days',
            Icons.local_fire_department,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  int _calculateLongestStreak(List<HeatmapData> data) {
    if (data.isEmpty) return 0;

    final sortedData = data.toList()..sort((a, b) => a.date.compareTo(b.date));
    int currentStreak = 0;
    int longestStreak = 0;

    for (final dayData in sortedData) {
      if (dayData.completionRate > 0.5) {
        // Consider 50%+ completion as active day
        currentStreak++;
        longestStreak = longestStreak > currentStreak
            ? longestStreak
            : currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    return longestStreak;
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
