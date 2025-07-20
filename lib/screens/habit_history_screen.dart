import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../providers/habit_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class HabitHistoryScreen extends StatefulWidget {
  final Habit habit;

  const HabitHistoryScreen({super.key, required this.habit});

  @override
  State<HabitHistoryScreen> createState() => _HabitHistoryScreenState();
}

class _HabitHistoryScreenState extends State<HabitHistoryScreen> {
  List<HabitLog> _logs = [];
  bool _isLoading = true;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final habitProvider = context.read<HabitProvider>();
      final logs = await habitProvider.getHabitHistory(widget.habit.id!);
      final streak = await habitProvider.getHabitStreak(widget.habit.id!);

      setState(() {
        _logs = logs;
        _currentStreak = streak;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to load history: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.habit.name} History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: Column(
                children: [
                  _buildHabitHeader(),
                  Expanded(
                    child: _logs.isEmpty
                        ? _buildEmptyState()
                        : _buildHistoryList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHabitHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: widget.habit.color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: widget.habit.color.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: widget.habit.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(
              Helpers.getHabitIcon(widget.habit.iconName),
              color: widget.habit.color,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.habit.name, style: AppTheme.titleLarge),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  widget.habit.category,
                  style: AppTheme.bodyMedium.copyWith(
                    color: widget.habit.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                Icons.local_fire_department,
                color: Helpers.getStreakColor(_currentStreak),
                size: 24,
              ),
              Text(
                '$_currentStreak',
                style: AppTheme.titleMedium.copyWith(
                  color: Helpers.getStreakColor(_currentStreak),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'day streak',
                style: AppTheme.bodySmall.copyWith(
                  color: Helpers.getStreakColor(_currentStreak),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No history yet',
            style: AppTheme.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Start completing this habit to see your progress here',
            style: AppTheme.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildHistoryItem(log);
      },
    );
  }

  Widget _buildHistoryItem(HabitLog log) {
    final isSkipped = log.inputMethod == 'skip';
    final isVoice = log.inputMethod == 'voice';

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: isSkipped
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(
                isSkipped ? Icons.close : Icons.check,
                color: isSkipped ? AppTheme.errorColor : AppTheme.successColor,
                size: 16,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Helpers.formatDate(log.completedAt),
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          if (isVoice) ...[
                            Icon(
                              Icons.mic,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                          ],
                          Text(
                            Helpers.formatTime(log.completedAt),
                            style: AppTheme.bodySmall.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (log.note != null && log.note!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      log.note!,
                      style: AppTheme.bodySmall.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
