import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import '../providers/analytics_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/progress_chart.dart';
import '../widgets/premium_dialog.dart';
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
      body: Consumer3<AnalyticsProvider, HabitProvider, UserProvider>(
        builder:
            (context, analyticsProvider, habitProvider, userProvider, child) {
              if (analyticsProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(
                    analyticsProvider,
                    habitProvider,
                    userProvider,
                  ),
                  _buildInsightsTab(analyticsProvider, userProvider),
                ],
              );
            },
      ),
    );
  }

  Widget _buildOverviewTab(
    AnalyticsProvider analyticsProvider,
    HabitProvider habitProvider,
    UserProvider userProvider,
  ) {
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
            _buildProgressChart(analyticsProvider),
            const SizedBox(height: AppTheme.spacingL),
            _buildHabitBreakdown(habitProvider, userProvider),
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
              colorsets: {
                1: Theme.of(context).colorScheme.primary,
              },
              onClick: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Activity on ${value.day}/${value.month}: ${provider.heatmapData[value] ?? 0} habits'))
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
    UserProvider userProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeeklyInsight(analyticsProvider),
          const SizedBox(height: AppTheme.spacingL),
          _buildAIRecommendations(analyticsProvider, userProvider),
          const SizedBox(height: AppTheme.spacingL),
          _buildPatternAnalysis(analyticsProvider, userProvider),
          const SizedBox(height: AppTheme.spacingL),
          _buildGoalSuggestions(analyticsProvider, userProvider),
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
        color: color.withOpacity(0.1),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart(AnalyticsProvider analyticsProvider) {
    final weeklyData = analyticsProvider.getWeeklyProgress();

    return ProgressChart(
      data: weeklyData,
      title: 'Weekly Progress',
      chartType: ChartType.line,
      primaryColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildHabitBreakdown(
    HabitProvider habitProvider,
    UserProvider userProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Habit Breakdown', style: AppTheme.titleMedium),
                // 🔧 ENHANCED: Strict premium check
                if (!userProvider.canAccessPremiumFeature('detailed_breakdown'))
                  TextButton(
                    onPressed: () => showPremiumDialog(
                      context,
                      feature: 'Detailed habit breakdown',
                    ),
                    child: const Text('Premium'),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            // 🔧 ENHANCED: More robust premium gating
            if (userProvider.canAccessPremiumFeature('detailed_breakdown')) ...[
              // Premium detailed breakdown
              ...habitProvider.habits
                  .take(5)
                  .map(
                    (habit) => _buildHabitProgressItem(habit, habitProvider),
                  ),
            ] else ...[
              // Free tier limited view
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Detailed breakdown available in Premium',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
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
                  color: habit.color.withOpacity(0.1),
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
            color: habit.color.withOpacity(0.1),
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
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology,
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

  Widget _buildAIRecommendations(
    AnalyticsProvider analyticsProvider,
    UserProvider userProvider,
  ) {
    // 🔧 ENHANCED: Strict premium check
    if (!userProvider.canAccessPremiumFeature('ai_recommendations')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            children: [
              Icon(
                Icons.stars,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text('AI Recommendations', style: AppTheme.titleMedium),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Get personalized recommendations based on your habit patterns',
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingM),
              ElevatedButton(
                onPressed: () =>
                    showPremiumDialog(context, feature: 'AI Recommendations'),
                child: const Text('Upgrade to Premium'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Recommendations', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            _buildRecommendationItem(
              'Try morning habits',
              'Your completion rate is higher in the morning',
              Icons.wb_sunny,
              AppTheme.warningColor,
            ),
            _buildRecommendationItem(
              'Link habits together',
              'Consider habit stacking for better consistency',
              Icons.link,
              AppTheme.infoColor,
            ),
            _buildRecommendationItem(
              'Focus on streaks',
              'Aim for 7-day streaks to build momentum',
              Icons.local_fire_department,
              AppTheme.successColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternAnalysis(
    AnalyticsProvider analyticsProvider,
    UserProvider userProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pattern Analysis', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            // 🔧 ENHANCED: Strict premium check
            if (userProvider.canAccessPremiumFeature('pattern_analysis')) ...[
              _buildPatternItem(
                'Best Day',
                'Monday',
                Icons.calendar_today,
                AppTheme.successColor,
              ),
              _buildPatternItem(
                'Best Time',
                '8:00 AM',
                Icons.access_time,
                AppTheme.infoColor,
              ),
              _buildPatternItem(
                'Consistency',
                '78%',
                Icons.trending_up,
                AppTheme.warningColor,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Text(
                        'Detailed pattern analysis available in Premium',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSuggestions(
    AnalyticsProvider analyticsProvider,
    UserProvider userProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal Suggestions', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            _buildGoalItem(
              'Reach 30-day streak',
              'You\'re 23 days away from your longest streak',
              Icons.emoji_events,
              AppTheme.warningColor,
            ),
            _buildGoalItem(
              'Maintain 80% completion',
              'You\'re currently at 78% this week',
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
        color: color.withOpacity(0.1),
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
                    ).colorScheme.onSurface.withOpacity(0.7),
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
        border: Border.all(color: color.withOpacity(0.3)),
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
                    ).colorScheme.onSurface.withOpacity(0.7),
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
