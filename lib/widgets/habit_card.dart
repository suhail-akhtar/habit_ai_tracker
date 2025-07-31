import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/ai_habit_assistant_service.dart';
import '../services/ai_cache_service.dart';
import '../utils/theme.dart';
import '../screens/habit_setup_screen.dart';
import '../screens/habit_history_screen.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final VoidCallback? onTap;

  const HabitCard({super.key, required this.habit, this.onTap});

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.shortAnimation,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitProvider>(
      builder: (context, habitProvider, child) {
        _isCompleted = habitProvider.isHabitCompletedToday(widget.habit.id!);

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Card(
                elevation: _isCompleted
                    ? AppTheme.elevationS
                    : AppTheme.elevationM,
                child: InkWell(
                  onTap: widget.onTap ?? () => _showHabitDetails(context),
                  onTapDown: (_) => _animationController.forward(),
                  onTapUp: (_) => _animationController.reverse(),
                  onTapCancel: () => _animationController.reverse(),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: _isCompleted
                          ? Border.all(color: Colors.green, width: 2)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildHabitIcon(),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(child: _buildHabitInfo()),
                            _buildCompletionButton(habitProvider),
                          ],
                        ),
                        if (widget.habit.description != null) ...[
                          const SizedBox(height: AppTheme.spacingS),
                          _buildDescription(),
                        ],
                        const SizedBox(height: AppTheme.spacingS),
                        _buildProgressIndicator(habitProvider),
                        const SizedBox(height: AppTheme.spacingS),
                        _buildStreakMotivation(habitProvider),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHabitIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: widget.habit.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Icon(
        Icons.star, // Simple fallback icon
        color: widget.habit.color,
        size: 24,
      ),
    );
  }

  Widget _buildHabitInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.habit.name,
          style: AppTheme.headlineSmall.copyWith(
            color: _isCompleted ? Colors.green : null,
            decoration: _isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.habit.category,
          style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.habit.description!,
      style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCompletionButton(HabitProvider habitProvider) {
    return GestureDetector(
      onTap: () => _toggleCompletion(habitProvider),
      child: AnimatedContainer(
        duration: AppTheme.shortAnimation,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _isCompleted ? Colors.green : Colors.transparent,
          border: Border.all(
            color: _isCompleted ? Colors.green : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: _isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _buildProgressIndicator(HabitProvider habitProvider) {
    return FutureBuilder<int>(
      future: habitProvider.getHabitStreak(widget.habit.id!),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Streak: $streak days',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Target: ${widget.habit.targetFrequency}/day',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _isCompleted ? 1.0 : 0.5,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.habit.color,
                    ),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 🤖 AI-Powered Streak Motivation
  Widget _buildStreakMotivation(HabitProvider habitProvider) {
    return FutureBuilder<int>(
      future: habitProvider.getHabitStreak(widget.habit.id!),
      builder: (context, streakSnapshot) {
        if (!streakSnapshot.hasData || streakSnapshot.data == 0) {
          return const SizedBox.shrink();
        }

        final currentStreak = streakSnapshot.data!;

        return FutureBuilder<String>(
          future: _getStreakMotivation(currentStreak),
          builder: (context, motivationSnapshot) {
            if (!motivationSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            return Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: widget.habit.color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(color: widget.habit.color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: widget.habit.color, size: 14),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      motivationSnapshot.data!,
                      style: AppTheme.bodySmall.copyWith(
                        color: widget.habit.color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _getStreakMotivation(int currentStreak) async {
    try {
      // 🧠 NEW: AI Message Caching System (5 hours cache)
      final cachedMessage = await AICacheService.getCachedMotivation(
        widget.habit.id!,
        currentStreak,
      );

      if (cachedMessage != null) {
        return cachedMessage;
      }

      print(
        '🧠 Generating new AI message for habit ${widget.habit.name} (streak: $currentStreak)',
      );
      // Generate new AI message
      final aiService = AIHabitAssistantService();
      final newMessage = await aiService.generateStreakMotivation(
        habit: widget.habit,
        currentStreak: currentStreak,
        longestStreak: currentStreak, // For now, using current as longest
      );

      // Cache the new message
      await AICacheService.cacheMotivation(
        widget.habit.id!,
        currentStreak,
        newMessage,
      );

      return newMessage;
    } catch (e) {
      print('❌ AI motivation generation failed: $e');
      // Fallback motivation messages
      if (currentStreak < 7) {
        return "Building momentum! $currentStreak days strong 🔥";
      } else if (currentStreak < 30) {
        return "Amazing progress! $currentStreak days! 💪";
      } else {
        return "Incredible dedication! $currentStreak days! 🏆";
      }
    }
  }

  // 🧠 NEW: Cache invalidation for habit changes
  static Future<void> invalidateHabitCache(int habitId) async {
    await AICacheService.invalidateHabitCache(habitId);
  }

  void _toggleCompletion(HabitProvider habitProvider) async {
    if (_isCompleted) {
      // TODO: Add ability to unmark completion if needed
      return;
    }

    await habitProvider.logHabitCompletion(widget.habit.id!);

    // 🧠 NEW: Invalidate AI cache when habit is completed (streak changed)
    await invalidateHabitCache(widget.habit.id!);

    if (mounted) {
      setState(() {
        _isCompleted = true;
      });
    }
  }

  void _showHabitDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusL),
            ),
          ),
          child: _buildHabitDetailsContent(context, scrollController),
        ),
      ),
    );
  }

  Widget _buildHabitDetailsContent(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return Consumer<HabitProvider>(
      builder: (context, habitProvider, child) {
        return FutureBuilder<int>(
          future: habitProvider.getHabitStreak(widget.habit.id!),
          builder: (context, snapshot) {
            final streak = snapshot.data ?? 0;

            return Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingM,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildHabitIcon(),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.habit.name,
                                    style: AppTheme.headlineMedium,
                                  ),
                                  Text(
                                    widget.habit.category,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppTheme.spacingL),

                        // Description
                        if (widget.habit.description != null) ...[
                          Text('Description', style: AppTheme.titleMedium),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            widget.habit.description!,
                            style: AppTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingL),
                        ],

                        // Statistics
                        Text('Statistics', style: AppTheme.titleMedium),
                        const SizedBox(height: AppTheme.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Current Streak',
                                '$streak days',
                                Icons.local_fire_department,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: _buildStatCard(
                                'Target',
                                '${widget.habit.targetFrequency}/day',
                                Icons.trending_up,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppTheme.spacingL),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _editHabit(context),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Habit'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingM,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _viewHistory(context),
                                icon: const Icon(Icons.history),
                                label: const Text('View History'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingM,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom padding for safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 🔧 ADDED: Edit habit functionality
  void _editHabit(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitSetupScreen(habitToEdit: widget.habit),
      ),
    );
  }

  // 🔧 ADDED: View history functionality
  void _viewHistory(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitHistoryScreen(habit: widget.habit),
      ),
    );
  }
}
