import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/habit_card.dart';
import '../widgets/streak_counter.dart';
import '../widgets/voice_button.dart';
import '../widgets/premium_dialog.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import 'voice_input_screen.dart';
import 'habit_setup_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<HabitProvider>().loadHabits();
          await context.read<UserProvider>().loadUserData();
        },
        child: Consumer2<HabitProvider, UserProvider>(
          builder: (context, habitProvider, userProvider, child) {
            if (habitProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text('Today', style: AppTheme.headlineSmall),
                  floating: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.mic),
                      onPressed: () => _openVoiceInput(context),
                      tooltip: 'Voice Input',
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeSection(context, userProvider),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildStreakSection(context, habitProvider),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildQuickStatsSection(context, habitProvider),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildTodayHabitsSection(
                          context,
                          habitProvider,
                          userProvider,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final habit = habitProvider.todayHabits[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingS,
                      ),
                      child: HabitCard(habit: habit),
                    );
                  }, childCount: habitProvider.todayHabits.length),
                ),
                // 🔧 FIXED: Add proper bottom padding to ensure navigation bar is accessible
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom +
                        kBottomNavigationBarHeight +
                        AppTheme
                            .spacingXL, // Extra space for floating action button
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: VoiceButton(
        onPressed: () => _openVoiceInput(context),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, UserProvider userProvider) {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.person,
                size: 30,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: AppTheme.titleMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Ready to build great habits?',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  if (!userProvider.isPremium) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Habits: ${userProvider.habitCount}/${Constants.freeHabitLimit}',
                      style: AppTheme.bodySmall.copyWith(
                        color: userProvider.hasReachedFreeLimit
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!userProvider.isPremium)
              TextButton(
                onPressed: () => showPremiumDialog(context),
                child: const Text('Upgrade'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakSection(
    BuildContext context,
    HabitProvider habitProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Streak', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingS),
            StreakCounter(streak: habitProvider.longestStreak),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection(
    BuildContext context,
    HabitProvider habitProvider,
  ) {
    final completedToday = habitProvider.todayHabits
        .where((habit) => habitProvider.isHabitCompletedToday(habit.id!))
        .length;
    final totalHabits = habitProvider.todayHabits.length;
    final completionRate = totalHabits > 0
        ? (completedToday / totalHabits) * 100
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Progress', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Completed',
                  completedToday.toString(),
                  Icons.check_circle,
                  AppTheme.successColor,
                ),
                _buildStatItem(
                  context,
                  'Total',
                  totalHabits.toString(),
                  Icons.list_alt,
                  Theme.of(context).colorScheme.primary,
                ),
                _buildStatItem(
                  context,
                  'Rate',
                  '${completionRate.toStringAsFixed(0)}%',
                  Icons.trending_up,
                  AppTheme.infoColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          value,
          style: AppTheme.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayHabitsSection(
    BuildContext context,
    HabitProvider habitProvider,
    UserProvider userProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Today\'s Habits', style: AppTheme.titleMedium),
        TextButton(
          onPressed: () => _handleAddNewHabit(context, userProvider),
          child: const Text('Add New'),
        ),
      ],
    );
  }

  void _handleAddNewHabit(BuildContext context, UserProvider userProvider) {
    final validation = userProvider.validateHabitCreation();

    if (!validation.isAllowed) {
      showPremiumDialog(
        context,
        feature: 'Create more than ${Constants.freeHabitLimit} habits',
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const HabitSetupScreen()));
  }

  void _openVoiceInput(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const VoiceInputScreen()));
  }
}
