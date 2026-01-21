import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import '../providers/analytics_provider.dart';
import '../providers/habit_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeletons.dart';
import '../widgets/progress_chart.dart';
import '../models/habit.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: Consumer2<AnalyticsProvider, HabitProvider>(
        builder: (context, analyticsProvider, habitProvider, child) {
          if (analyticsProvider.isLoading) {
            return ListView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              children: const [
                SkeletonSection(titleWidth: 140, contentHeight: 160),
                SizedBox(height: AppTheme.spacingL),
                SkeletonSection(titleWidth: 180, contentHeight: 120),
                SizedBox(height: AppTheme.spacingL),
                SkeletonSection(titleWidth: 160, contentHeight: 140),
              ],
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(analyticsProvider, habitProvider),
              _buildInsightsTab(analyticsProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(
    AnalyticsProvider analyticsProvider,
    HabitProvider habitProvider,
  ) {
    if (habitProvider.habits.isEmpty) {
      return EmptyState(
        icon: Icons.analytics_outlined,
        title: 'No analytics yet',
        message: 'Create a habit and log progress to unlock insights.',
        actionLabel: 'Create Habit',
        onAction: () => Navigator.of(context).pushNamed('/habit-setup'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await analyticsProvider.loadAnalytics();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeatmap(analyticsProvider),
            const SizedBox(height: AppTheme.spacingL),
            _buildStatsOverview(analyticsProvider),
            const SizedBox(height: AppTheme.spacingL),
            _buildRangeSelector(analyticsProvider),
            const SizedBox(height: AppTheme.spacingM),
            _buildRangeSummary(analyticsProvider),
            const SizedBox(height: AppTheme.spacingL),
            _buildProgressChart(analyticsProvider),
            const SizedBox(height: AppTheme.spacingL),
            _buildHabitBreakdown(habitProvider),
            const SizedBox(height: AppTheme.spacingL),
            _buildStreakLeaderboard(habitProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(AnalyticsProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Activity Map", style: AppTheme.titleMedium),
            const SizedBox(height: 16),
            HeatMap(
              datasets: provider.heatmapData,
              colorMode: ColorMode.opacity,
              showText: false,
              scrollable: true,
              colorsets: {1: Theme.of(context).colorScheme.primary},
              onClick: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Activity on ${value.day}/${value.month}: ${provider.heatmapData[value] ?? 0} habits',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTab(
    AnalyticsProvider analyticsProvider,
  ) {
    if (analyticsProvider.analytics.isEmpty) {
      return EmptyState(
        icon: Icons.auto_awesome,
        title: 'Insights will appear here',
        message: 'Log a few habits and return for patterns and tips.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeeklyInsight(analyticsProvider),
          const SizedBox(height: AppTheme.spacingL),
          _buildDailyTip(analyticsProvider),
          const SizedBox(height: AppTheme.spacingL),
          _buildSuggestions(),
          const SizedBox(height: AppTheme.spacingL),
          _buildPatternAnalysis(analyticsProvider),
          const SizedBox(height: AppTheme.spacingL),
          _buildGoalSuggestions(analyticsProvider),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(AnalyticsProvider analyticsProvider) {
    final analytics = analyticsProvider.analytics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics Overview', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Habits',
                    analytics['totalHabits']?.toString() ?? '0',
                    Icons.list_alt,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatCard(
                    'This Week',
                    analytics['recentLogs']?.toString() ?? '0',
                    Icons.today,
                    AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Best Streak',
                    '${analytics['bestStreak'] ?? 0} days',
                    Icons.local_fire_department,
                    AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatCard(
                    'Completion Rate',
                    '${analytics['completionRate'] ?? 0}%',
                    Icons.trending_up,
                    AppTheme.infoColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(AnalyticsProvider analyticsProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time Range', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha(77),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  _buildRangeChip(
                    label: 'Week',
                    isSelected:
                        analyticsProvider.range == AnalyticsRange.week,
                    onTap: () => analyticsProvider.setRange(
                      AnalyticsRange.week,
                    ),
                  ),
                  _buildRangeChip(
                    label: 'Month',
                    isSelected:
                        analyticsProvider.range == AnalyticsRange.month,
                    onTap: () => analyticsProvider.setRange(
                      AnalyticsRange.month,
                    ),
                  ),
                  _buildRangeChip(
                    label: 'Year',
                    isSelected:
                        analyticsProvider.range == AnalyticsRange.year,
                    onTap: () => analyticsProvider.setRange(
                      AnalyticsRange.year,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRangeSummary(AnalyticsProvider analyticsProvider) {
    final summary = analyticsProvider.rangeSummary;
    if (summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final completionRate = (summary['completionRate'] as num?) ?? 0;
    final deltaStr = summary['delta']?.toString() ?? '0.0';
    final delta = double.tryParse(deltaStr) ?? 0.0;
    final isUp = delta >= 0;
    final trendColor = isUp ? AppTheme.successColor : AppTheme.warningColor;
    final rangeLabel = summary['range'] == 'month'
        ? 'This Month'
        : summary['range'] == 'year'
            ? 'This Year'
            : 'This Week';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                rangeLabel,
                '${completionRate.toStringAsFixed(1)}%',
                Icons.track_changes,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: trendColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Column(
                  children: [
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      color: trendColor,
                      size: 32,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}% vs last',
                      style: AppTheme.bodySmall.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart(AnalyticsProvider analyticsProvider) {
    final data = analyticsProvider.progressSeries;
    final title = analyticsProvider.range == AnalyticsRange.month
        ? 'Monthly Progress'
        : analyticsProvider.range == AnalyticsRange.year
            ? 'Yearly Progress'
            : 'Weekly Progress';

    return ProgressChart(
      data: data,
      title: title,
      chartType: ChartType.line,
      primaryColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildHabitBreakdown(
    HabitProvider habitProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Habit Breakdown', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ...habitProvider.habits
                .take(5)
                .map((habit) => _buildHabitProgressItem(habit, habitProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitProgressItem(Habit habit, HabitProvider habitProvider) {
    return FutureBuilder<int>(
      future: habitProvider.getHabitStreak(habit.id!),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingXS),
                decoration: BoxDecoration(
                  color: habit.color.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Icon(
                  Helpers.getHabitIcon(habit.iconName),
                  color: habit.color,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(child: Text(habit.name, style: AppTheme.bodyMedium)),
              Text(
                '${streak}d',
                style: AppTheme.bodySmall.copyWith(
                  color: Helpers.getStreakColor(streak),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakLeaderboard(HabitProvider habitProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Streak Leaderboard', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ...habitProvider.habits
                .take(3)
                .map((habit) => _buildLeaderboardItem(habit, habitProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(Habit habit, HabitProvider habitProvider) {
    return FutureBuilder<int>(
      future: habitProvider.getHabitStreak(habit.id!),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: habit.color.withAlpha(26),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Row(
            children: [
              Icon(
                Helpers.getHabitIcon(habit.iconName),
                color: habit.color,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(child: Text(habit.name, style: AppTheme.bodyMedium)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Helpers.getStreakColor(streak),
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    '$streak',
                    style: AppTheme.bodySmall.copyWith(
                      color: Helpers.getStreakColor(streak),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyInsight(AnalyticsProvider analyticsProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Weekly Insight', style: AppTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => analyticsProvider.refreshInsight(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withAlpha(26),
                    Theme.of(context).colorScheme.secondary.withAlpha(26),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Text(
                      analyticsProvider.weeklyInsight ?? 'Loading insight...',
                      style: AppTheme.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTip(AnalyticsProvider analyticsProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Tip', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            FutureBuilder<String>(
              future: analyticsProvider.getDailyTip(),
              builder: (context, snapshot) {
                final tip = snapshot.data ?? 'Loading tip...';
                return Text(tip, style: AppTheme.bodyMedium);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggestions', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            _buildRecommendationItem(
              'Start small',
              'Consistency beats intensity — keep it easy to repeat.',
              Icons.check_circle_outline,
              AppTheme.successColor,
            ),
            _buildRecommendationItem(
              'Stack habits',
              'Attach a new habit to an existing routine.',
              Icons.link,
              AppTheme.infoColor,
            ),
            _buildRecommendationItem(
              'Protect your streak',
              'If you miss a day, restart immediately.',
              Icons.local_fire_department,
              AppTheme.warningColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternAnalysis(AnalyticsProvider analyticsProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pattern Analysis', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            _buildPatternItem(
              'Best Day',
              analyticsProvider.bestDayLabel,
              Icons.calendar_today,
              AppTheme.successColor,
            ),
            _buildPatternItem(
              'Best Time',
              analyticsProvider.bestTimeLabel,
              Icons.access_time,
              AppTheme.infoColor,
            ),
            _buildPatternItem(
              'Least Active Day',
              analyticsProvider.leastActiveDayLabel,
              Icons.trending_down,
              AppTheme.warningColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSuggestions(AnalyticsProvider analyticsProvider) {
    final analytics = analyticsProvider.analytics;
    final bestStreak = analytics['bestStreak'] ?? 0;
    final completionRate = analytics['completionRate'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal Suggestions', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            _buildGoalItem(
              bestStreak >= 30 ? 'Protect your streak' : 'Reach 30-day streak',
              bestStreak >= 30
                  ? 'You\'re on a $bestStreak day streak — keep it alive'
                  : 'You\'re ${30 - bestStreak} days away from 30',
              Icons.emoji_events,
              AppTheme.warningColor,
            ),
            _buildGoalItem(
              'Maintain 80% completion',
              'You\'re currently at $completionRate% this week',
              Icons.track_changes,
              AppTheme.infoColor,
            ),
            _buildGoalItem(
              'Add a new habit',
              'Consider adding a mindfulness habit',
              Icons.add_circle,
              AppTheme.successColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppTheme.spacingS),
          Text(label, style: AppTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(77)),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
