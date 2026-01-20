import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/habit.dart';
import '../models/habit_template.dart';
import '../providers/analytics_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/helpers.dart';
import '../utils/app_log.dart';
import '../main.dart' show MainNavigationScreen;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const prefOnboardingComplete = 'onboarding_complete';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _selected = <String>{};

  bool _enableReminders = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  bool _isSaving = false;

  List<HabitTemplate> get _templates => HabitTemplate.defaults;

  Future<void> _finish() async {
    if (_isSaving) return;

    final userProvider = context.read<UserProvider>();
    final habitProvider = context.read<HabitProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();

    setState(() {
      _isSaving = true;
    });

    try {
      final notificationService = NotificationService();
      var remindersAllowed = _enableReminders;

      if (_enableReminders) {
        final hasPermission = await notificationService.requestPermissions();
        remindersAllowed = hasPermission;
        if (!hasPermission && mounted) {
          Helpers.showConfirmDialog(
            context,
            title: 'Enable Notifications',
            content:
                'Notifications are required to schedule reminders. Please enable them in Settings.',
            confirmText: 'Open Settings',
            onConfirm: () {
              openAppSettings();
            },
          );
        }
      }

      // Create selected habits (max 3 by UI, but enforce defensively here too)
      final chosen = _templates
          .where((t) => _selected.contains(t.id))
          .take(3)
          .toList(growable: false);

      final db = DatabaseService();

      for (final template in chosen) {
        final habit = Habit(
          id: null,
          name: template.name,
          description: null,
          category: template.category,
          targetFrequency: template.targetFrequency,
          colorCode: Helpers.colorToHex(template.color),
          iconName: template.iconName,
          isActive: true,
          // Scheduling defaults: start today, all weekdays
          scheduleDaysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
          startDate: DateTime.now(),
          frequencyType: 'daily',
          intervalMinutes: null,
          windowStartTime: null,
          windowEndTime: null,
          isReminderEnabled: _enableReminders,
          reminderTime: _enableReminders
              ? '${_reminderTime.hour}:${_reminderTime.minute.toString().padLeft(2, '0')}'
              : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final id = await db.createHabit(habit);
        final created = habit.copyWith(id: id);

        if (remindersAllowed) {
          try {
            await notificationService.scheduleHabitReminders(created);
          } catch (e) {
            AppLog.e('Failed to schedule onboarding reminder', e);
          }
        }
      }

      // Mark onboarding complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingScreen.prefOnboardingComplete, true);

      // Refresh providers best-effort
      if (!mounted) return;
      await userProvider.loadUserData();
      await habitProvider.loadHabits();
      await analyticsProvider.loadAnalytics();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } catch (e) {
      AppLog.e('Onboarding finish failed', e);
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to finish onboarding: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefOnboardingComplete, true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        if (_selected.length >= 3) return;
        _selected.add(id);
      }
    });
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;
    setState(() {
      _reminderTime = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get started'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick up to 3 starter habits',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'You can edit schedules, reminders, and details later.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _templates.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = _templates[index];
                    final selected = _selected.contains(t.id);
                    final disabled = !selected && _selected.length >= 3;

                    return Opacity(
                      opacity: disabled ? 0.55 : 1,
                      child: Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: disabled ? null : () => _toggle(t.id),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: t.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _iconFromName(t.iconName),
                                    color: t.color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.category,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Checkbox(
                                  value: selected,
                                  onChanged: disabled
                                      ? null
                                      : (_) {
                                          _toggle(t.id);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable reminders'),
                        subtitle: const Text('Schedules notifications for selected habits'),
                        value: _enableReminders,
                        onChanged: _isSaving
                            ? null
                            : (v) {
                                setState(() {
                                  _enableReminders = v;
                                });
                              },
                      ),
                      if (_enableReminders)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Reminder time'),
                          subtitle: Text(_reminderTime.format(context)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _isSaving ? null : _pickReminderTime,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _isSaving ? null : _finish,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Finish'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFromName(String name) {
    // Minimal mapping so templates remain stable even if icon picker changes.
    switch (name) {
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'menu_book':
        return Icons.menu_book;
      case 'edit_note':
        return Icons.edit_note;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'accessibility_new':
        return Icons.accessibility_new;
      default:
        return Icons.check_circle_outline;
    }
  }
}
