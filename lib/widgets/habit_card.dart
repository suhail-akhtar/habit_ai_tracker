import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
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
  int _currentCount = 0; // 🎯 NEW: Track progress count

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
        _currentCount = habitProvider.getCompletionCountToday(
          widget.habit.id!,
        ); // 🎯 NEW

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: _isCompleted
                          ? widget.habit.color.withAlpha(77)
                          : Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).cardTheme.color,
                  child: InkWell(
                    onTap: widget.onTap ?? () => _showHabitDetails(context),
                    onTapDown: (_) => _animationController.forward(),
                    onTapUp: (_) => _animationController.reverse(),
                    onTapCancel: () => _animationController.reverse(),
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Row(
                        children: [
                          _buildHabitIcon(),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.habit.name,
                                  style: AppTheme.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    decoration: _isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: _isCompleted
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface.withAlpha(128)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: widget.habit.color.withAlpha(38),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                      ),
                                      child: Text(
                                        widget.habit.category.toUpperCase(),
                                        style: AppTheme.bodySmall.copyWith(
                                          color: widget.habit.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStreakBadge(habitProvider),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildCompletionButton(habitProvider),
                        ],
                      ),
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _isCompleted
            ? widget.habit.color.withAlpha(51)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Center(
        child: Icon(
          Helpers.getHabitIcon(widget.habit.iconName),
          color: _isCompleted
              ? widget.habit.color
              : Theme.of(context).colorScheme.onSurface.withAlpha(128),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildStreakBadge(HabitProvider habitProvider) {
    return FutureBuilder<int>(
      future: habitProvider.getHabitStreak(widget.habit.id!),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;
        if (streak == 0) return const SizedBox.shrink();

        return Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompletionButton(HabitProvider habitProvider) {
    // 🎯 NEW: Interactive Radial Progress for frequency > 1
    if (widget.habit.targetFrequency > 1) {
      final progress = _currentCount / widget.habit.targetFrequency;
      final isFull = _currentCount >= widget.habit.targetFrequency;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleHabitCompletion(habitProvider),
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: progress > 1.0 ? 1.0 : progress,
                  strokeWidth: 4,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.outline.withAlpha(51),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFull
                        ? widget.habit.color
                        : widget.habit.color.withAlpha(204),
                  ),
                ),
              ),
              if (isFull)
                Icon(Icons.check, color: widget.habit.color, size: 24)
              else
                Text(
                  '$_currentCount/${widget.habit.targetFrequency}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.habit.color,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Existing Simple Checkbox logic
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleHabitCompletion(habitProvider),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isCompleted
                ? widget.habit.color
                : Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(
              color: _isCompleted
                  ? widget.habit.color
                  : Theme.of(context).colorScheme.outline.withAlpha(51),
              width: 2,
            ),
            boxShadow: _isCompleted
                ? [
                    BoxShadow(
                      color: widget.habit.color.withAlpha(102),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: _isCompleted
              ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 24,
                ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack)
              : Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.outline.withAlpha(128),
                  size: 24,
                ),
        ),
      ),
    );
  }

  void _toggleHabitCompletion(HabitProvider habitProvider) async {
    // Immediate Haptic Feedback
    HapticFeedback.lightImpact();

    try {
      // 🎯 NEW: Simplified Toggle Logic
      // If target > 1, we just ADD a log (we don't remove unless complex logic needed)
      // For now, simple "Add" is best for frequency.

      if (widget.habit.targetFrequency > 1) {
        // Multi-step habit: Always ADD until full (or even if full for over-achievement)
        // To "undo", user might need to go to history, but for main card, just ADD.
        await habitProvider.logHabitCompletion(
          widget.habit.id!,
          inputMethod: 'manual',
        );
      } else {
        // Binary Habit: Toggle as before
        if (_isCompleted) {
          Helpers.showSnackBar(
            context,
            'To undo, please remove the log from History.', // Simplified for now since we don't have delete-latest easily exposed
            isError: false,
          );
        } else {
          // Success Haptic Feedback
          HapticFeedback.mediumImpact();

          await habitProvider.logHabitCompletion(
            widget.habit.id!,
            inputMethod: 'manual',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Helpers.showSnackBar(
        context,
        'Failed to update: $e', // Show actual error
        isError: true,
      );
    }
  }

  void _showHabitDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusL),
        ),
      ),
      builder: (context) => _HabitDetailsSheet(habit: widget.habit),
    );
  }
}

class _HabitDetailsSheet extends StatelessWidget {
  final Habit habit;

  const _HabitDetailsSheet({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),

          // Habit header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: habit.color.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  Helpers.getHabitIcon(habit.iconName),
                  color: habit.color,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: AppTheme.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      habit.category.toUpperCase(),
                      style: AppTheme.bodyMedium.copyWith(
                        color: habit.color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (habit.description != null && habit.description!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'ABOUT THIS HABIT',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(habit.description!, style: AppTheme.bodyLarge),
          ],

          const SizedBox(height: AppTheme.spacingL),
          const Divider(),
          const SizedBox(height: AppTheme.spacingM),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editHabit(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _viewHistory(context),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('History'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Skip Button
          Consumer<HabitProvider>(
            builder: (context, provider, _) {
              final isSkipped = provider.isHabitSkippedToday(habit.id!);
              final isCompleted = provider.isHabitCompletedToday(habit.id!);

              if (isCompleted) return const SizedBox.shrink();

              return SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: isSkipped ? null : () => _skipHabit(context),
                  icon: Icon(
                    isSkipped
                        ? Icons.check_circle_outline
                        : Icons.skip_next_rounded,
                    color: isSkipped
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    isSkipped
                        ? 'Habit Skipped For Today'
                        : 'Skip Today (Maintain Streak)',
                    style: TextStyle(
                      color: isSkipped
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha(13),
                  ),
                ),
              );
            },
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  //  ADDED: Edit habit functionality
  void _editHabit(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitSetupScreen(habitToEdit: habit),
      ),
    );
  }

  //  ADDED: View history functionality
  void _viewHistory(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HabitHistoryScreen(habit: habit)),
    );
  }

  void _skipHabit(BuildContext context) {
    final provider = Provider.of<HabitProvider>(context, listen: false);
    provider.logHabitSkip(habit.id!);
    Navigator.pop(context);
    Helpers.showSnackBar(context, 'Habit skipped. Streak maintained.');
  }
}
