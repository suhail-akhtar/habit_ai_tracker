import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/habit_report.dart';
import '../services/database_service.dart';
import '../utils/helpers.dart';
import '../utils/theme.dart';

class HabitReportScreen extends StatefulWidget {
  final Habit habit;

  const HabitReportScreen({super.key, required this.habit});

  @override
  State<HabitReportScreen> createState() => _HabitReportScreenState();
}

class _HabitReportScreenState extends State<HabitReportScreen> {
  static const int _rangeDays = 30;

  final _db = DatabaseService();

  late Future<HabitReport?> _reportFuture;
  late Future<List<HabitLog>> _recentLogsFuture;
  late Future<Map<String, dynamic>> _goalProgressFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _db.getHabitReport(widget.habit.id!, days: _rangeDays);
    _recentLogsFuture = _db.getHabitLogs(widget.habit.id!, limit: 25);
    _goalProgressFuture = _db.getHabitGoalProgress(widget.habit.id!);
  }

  Future<void> _refresh() async {
    setState(() {
      _reportFuture = _db.getHabitReport(widget.habit.id!, days: _rangeDays);
      _recentLogsFuture = _db.getHabitLogs(widget.habit.id!, limit: 25);
      _goalProgressFuture = _db.getHabitGoalProgress(widget.habit.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;

    return Scaffold(
      appBar: AppBar(
        title: Text('${habit.name} Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareReport(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          children: [
            _buildHeader(habit),
            const SizedBox(height: AppTheme.spacingM),
            FutureBuilder<HabitReport?>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final report = snapshot.data;
                if (report == null) {
                  return _buildEmpty('No report data yet');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildKeyStats(report),
                    const SizedBox(height: AppTheme.spacingM),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _goalProgressFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const SizedBox.shrink();
                        }
                        final data = snapshot.data ?? {};
                        if (data.isEmpty) return const SizedBox.shrink();
                        return _buildGoalProgress(data);
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    _build30DayGrid(report),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildBreakdown(report),
                  ],
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text('Recent Activity', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingS),
            FutureBuilder<List<HabitLog>>(
              future: _recentLogsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final logs = snapshot.data ?? const <HabitLog>[];
                if (logs.isEmpty) {
                  return _buildEmpty('No activity yet');
                }

                return Card(
                  child: Column(
                    children: [
                      for (final log in logs) _buildLogRow(log),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Habit habit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
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
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name, style: AppTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    habit.category,
                    style: AppTheme.bodyMedium.copyWith(color: habit.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyStats(HabitReport report) {
    String pct(double v) => '${(v * 100).round()}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last $_rangeDays days', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    'Completion',
                    pct(report.completionRate),
                    Icons.check_circle_outline,
                    AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _statTile(
                    'Adherence',
                    pct(report.adherenceRate),
                    Icons.track_changes,
                    AppTheme.infoColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    'Current Streak',
                    '${report.currentStreak}',
                    Icons.local_fire_department,
                    AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _statTile(
                    'Best Streak',
                    '${report.bestStreak}',
                    Icons.emoji_events_outlined,
                    AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    'Total Completions',
                    '${report.totalCompletions}',
                    Icons.done_all,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _statTile(
                    'Last Done',
                    report.lastCompletedAt == null
                        ? '—'
                        : Helpers.formatDate(report.lastCompletedAt!),
                    Icons.schedule,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(Map<String, dynamic> progress) {
    final type = progress['type'] as String? ?? '';
    final target = progress['target'] as int? ?? 0;
    final completed = progress['completed'] as int? ?? 0;
    final expected = progress['expected'] as int? ?? target;
    final onTrack = progress['onTrack'] as bool? ?? false;

    if (target <= 0) return const SizedBox.shrink();

    String label;
    switch (type) {
      case 'weekly':
        label = '$completed of $target this week';
        break;
      case 'total':
        label = '$completed of $target total';
        break;
      default:
        label = '$completed of $target streak';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal Progress', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (onTrack
                            ? AppTheme.successColor
                            : AppTheme.warningColor)
                        .withAlpha(26),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(
                    onTrack ? 'On track' : 'Catch up',
                    style: AppTheme.bodySmall.copyWith(
                      color: onTrack
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (type == 'weekly') ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Pace target by today: $expected',
                style: AppTheme.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(179),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _build30DayGrid(HabitReport report) {
    // Render as a simple 30-day grid (5 rows x 6 cols) newest at end.
    final days = report.days;

    Color cellColor(HabitDaySummary d) {
      if (!d.isDue) {
        return Theme.of(context).colorScheme.outline.withAlpha(25);
      }
      if (d.isSkipped) {
        return Colors.grey.withAlpha(90);
      }
      if (d.isTargetMet) {
        return AppTheme.successColor.withAlpha(180);
      }
      return AppTheme.errorColor.withAlpha(160);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('30-day calendar', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in days)
                  Tooltip(
                    message: _tooltipForDay(d),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: cellColor(d),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                _legendDot(AppTheme.successColor.withAlpha(180)),
                const SizedBox(width: 6),
                const Text('Done'),
                const SizedBox(width: 12),
                _legendDot(Colors.grey.withAlpha(90)),
                const SizedBox(width: 6),
                const Text('Skipped'),
                const SizedBox(width: 12),
                _legendDot(AppTheme.errorColor.withAlpha(160)),
                const SizedBox(width: 6),
                const Text('Missed'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color c) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }

  String _tooltipForDay(HabitDaySummary d) {
    final date = Helpers.formatDate(d.date);
    if (!d.isDue) return '$date: Rest day';
    if (d.isSkipped) return '$date: Skipped';
    if (d.isTargetMet) {
      return d.completedCount > 1
          ? '$date: Done (${d.completedCount})'
          : '$date: Done';
    }
    return '$date: Missed';
  }

  Widget _buildBreakdown(HabitReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Breakdown', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            _kv('Due days', '${report.dueDays}'),
            _kv('Completed', '${report.completedDays}'),
            _kv('Skipped', '${report.skippedDays}'),
            _kv('Missed', '${report.missedDays}'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: AppTheme.bodyMedium)),
          Text(v, style: AppTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _buildLogRow(HabitLog log) {
    final isCompleted = log.status == 'completed';
    final icon = isCompleted ? Icons.check_circle : Icons.skip_next;
    final color = isCompleted ? AppTheme.successColor : Colors.grey;

    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(Helpers.formatDateTime(log.completedAt)),
      subtitle: log.note == null || log.note!.isEmpty ? null : Text(log.note!),
      trailing: Text(
        isCompleted ? 'Done' : 'Skipped',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEmpty(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Text(text, style: AppTheme.bodyMedium),
      ),
    );
  }

  Future<void> _shareReport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await _reportFuture;
      final goal = await _goalProgressFuture;

      if (report == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('No report data to share')),
        );
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('${widget.habit.name} — Habit Report');
      buffer.writeln('Range: last $_rangeDays days');
      buffer.writeln('Completion rate: ${(report.completionRate * 100).round()}%');
      buffer.writeln('Adherence rate: ${(report.adherenceRate * 100).round()}%');
      buffer.writeln('Current streak: ${report.currentStreak} days');
      buffer.writeln('Best streak: ${report.bestStreak} days');
      buffer.writeln('Total completions: ${report.totalCompletions}');

      if (goal.isNotEmpty) {
        final type = goal['type'] as String? ?? '';
        final target = goal['target'] as int? ?? 0;
        final completed = goal['completed'] as int? ?? 0;
        if (target > 0) {
          final label = type == 'weekly'
              ? 'Weekly goal'
              : type == 'total'
                  ? 'Total goal'
                  : 'Streak goal';
          buffer.writeln('$label: $completed / $target');
        }
      }

      await Share.share(buffer.toString());
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }
}
