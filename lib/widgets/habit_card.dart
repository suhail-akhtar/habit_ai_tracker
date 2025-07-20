import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                          ? Border.all(color: AppTheme.successColor, width: 2)
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
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: widget.habit.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Icon(
        Helpers.getHabitIcon(widget.habit.iconName),
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
          style: AppTheme.titleMedium.copyWith(
            decoration: _isCompleted ? TextDecoration.lineThrough : null,
            color: _isCompleted
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          widget.habit.category,
          style: AppTheme.bodySmall.copyWith(
            color: widget.habit.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.habit.description!,
      style: AppTheme.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCompletionButton(HabitProvider habitProvider) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isCompleted
            ? AppTheme.successColor
            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
      ),
      child: IconButton(
        onPressed: () => _toggleHabitCompletion(habitProvider),
        icon: Icon(
          _isCompleted ? Icons.check : Icons.add,
          color: _isCompleted
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
        ),
        tooltip: _isCompleted ? 'Mark as incomplete' : 'Mark as complete',
      ),
    );
  }

  Widget _buildProgressIndicator(HabitProvider habitProvider) {
    return FutureBuilder<int>(
      future: habitProvider.getHabitStreak(widget.habit.id!),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: Helpers.getStreakColor(streak),
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  Helpers.getStreakText(streak),
                  style: AppTheme.bodySmall.copyWith(
                    color: Helpers.getStreakColor(streak),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              'Daily',
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleHabitCompletion(HabitProvider habitProvider) async {
    try {
      if (_isCompleted) {
        // For simplicity, we'll just show a message
        // In a real app, you might want to allow "uncompleting"
        Helpers.showSnackBar(
          context,
          'Habit already completed today!',
          isError: false,
        );
      } else {
        await habitProvider.logHabitCompletion(
          widget.habit.id!,
          inputMethod: 'manual',
        );

        Helpers.showSnackBar(
          context,
          'Great job! ${widget.habit.name} completed!',
          isError: false,
        );
      }
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'Failed to update habit: $e',
        isError: true,
      );
    }
  }

  void _showHabitDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                color: Theme.of(context).colorScheme.outline,
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
                  color: habit.color.withOpacity(0.1),
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
                    Text(habit.name, style: AppTheme.headlineSmall),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      habit.category,
                      style: AppTheme.bodyMedium.copyWith(
                        color: habit.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (habit.description != null) ...[
            const SizedBox(height: AppTheme.spacingL),
            Text('Description', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingS),
            Text(habit.description!, style: AppTheme.bodyMedium),
          ],

          const SizedBox(height: AppTheme.spacingL),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _editHabit(context), // 🔧 FIXED: Implement edit
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _viewHistory(context), // 🔧 FIXED: Implement history
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                ),
              ),
            ],
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
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
        builder: (context) => HabitSetupScreen(habitToEdit: habit),
      ),
    );
  }

  // 🔧 ADDED: View history functionality
  void _viewHistory(BuildContext context) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HabitHistoryScreen(habit: habit)),
    );
  }
}
