import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_settings.dart';
import '../providers/user_provider.dart';
import '../providers/habit_provider.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/premium_dialog.dart';

class NotificationSetupScreen extends StatefulWidget {
  final NotificationSettings? notification;

  const NotificationSetupScreen({super.key, this.notification});

  @override
  State<NotificationSetupScreen> createState() =>
      _NotificationSetupScreenState();
}

class _NotificationSetupScreenState extends State<NotificationSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  TimeOfDay _selectedTime = TimeOfDay.now();
  NotificationType _selectedType = NotificationType.simple;
  RepetitionType _selectedRepetition = RepetitionType.daily;
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7];
  List<int> _selectedHabits = [];
  bool _isEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.notification != null) {
      _initializeWithExisting();
    }
  }

  void _initializeWithExisting() {
    final notification = widget.notification!;
    _titleController.text = notification.title;
    _messageController.text = notification.message;
    _selectedTime = notification.time;
    _selectedType = notification.type;
    _selectedRepetition = notification.repetition;
    _selectedDays = List.from(notification.daysOfWeek);
    _selectedHabits = List.from(notification.habitIds);
    _isEnabled = notification.isEnabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.notification != null
              ? 'Edit Notification'
              : 'New Notification',
        ),
        actions: [
          if (widget.notification != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: Consumer2<UserProvider, HabitProvider>(
        builder: (context, userProvider, habitProvider, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationPreview(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildBasicSettings(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildTimeSettings(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildNotificationTypeSettings(userProvider),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildRepetitionSettings(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildDaySelection(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildHabitAssociation(habitProvider, userProvider),
                  const SizedBox(height: AppTheme.spacingXL),
                  _buildActionButtons(userProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getTypeIcon(), color: _getTypeColor()),
                const SizedBox(width: AppTheme.spacingS),
                Text('Preview', style: AppTheme.titleMedium),
                const Spacer(),
                Switch(
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(77),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications, size: 16),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        _titleController.text.isEmpty
                            ? 'Habit Reminder'
                            : _titleController.text,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Helpers.formatTime(DateTime.now()),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    _messageController.text.isEmpty
                        ? 'Time to check your habits! 🎯'
                        : _messageController.text,
                    style: AppTheme.bodySmall,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '${_selectedTime.format(context)} • ${_selectedType.name} • ${_selectedRepetition.name}',
                    style: AppTheme.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
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

  Widget _buildBasicSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Settings', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (Optional)',
                hintText: 'e.g., Morning Routine',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message (Optional)',
                hintText: 'e.g., Time to start your day!',
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time Settings', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            ListTile(
              leading: Icon(
                Icons.access_time,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Notification Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypeSettings(UserProvider userProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Notification Type', style: AppTheme.titleMedium),
                if (!userProvider.isPremium &&
                    (_selectedType == NotificationType.ringing ||
                        _selectedType == NotificationType.alarm))
                  const Spacer(),
                if (!userProvider.isPremium &&
                    (_selectedType == NotificationType.ringing ||
                        _selectedType == NotificationType.alarm))
                  TextButton(
                    onPressed: () => showPremiumDialog(
                      context,
                      feature: 'Advanced notification types',
                    ),
                    child: const Text('Premium'),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...NotificationType.values.map((type) {
              final isPremiumType = type != NotificationType.simple;
              final isDisabled = isPremiumType && !userProvider.isPremium;

              return RadioListTile<NotificationType>(
                title: Row(
                  children: [
                    Icon(
                      _getTypeIconForType(type),
                      color: _getTypeColorForType(type),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(type.name.toUpperCase()),
                    if (isPremiumType && !userProvider.isPremium) ...[
                      const SizedBox(width: AppTheme.spacingS),
                      Icon(Icons.star, size: 16, color: AppTheme.warningColor),
                    ],
                  ],
                ),
                subtitle: Text(_getTypeDescription(type)),
                value: type,
                // ignore: deprecated_member_use
                groupValue: _selectedType,
                // ignore: deprecated_member_use
                onChanged: isDisabled
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRepetitionSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repetition', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              children: RepetitionType.values.map((type) {
                return FilterChip(
                  selected: _selectedRepetition == type,
                  label: Text(type.name.toUpperCase()),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRepetition = type);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelection() {
    if (_selectedRepetition != RepetitionType.daily) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Days of Week', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDayChip('M', 1),
                _buildDayChip('T', 2),
                _buildDayChip('W', 3),
                _buildDayChip('T', 4),
                _buildDayChip('F', 5),
                _buildDayChip('S', 6),
                _buildDayChip('S', 7),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedDays = [1, 2, 3, 4, 5]),
                  child: const Text('Weekdays'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedDays = [6, 7]),
                  child: const Text('Weekends'),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedDays = [1, 2, 3, 4, 5, 6, 7]),
                  child: const Text('All Days'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = _selectedDays.contains(day);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(day);
          } else {
            _selectedDays.add(day);
          }
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withAlpha(77),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitAssociation(
    HabitProvider habitProvider,
    UserProvider userProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Habit Association (Optional)', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Link specific habits to this notification',
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            if (habitProvider.habits.isEmpty)
              Text(
                'No habits available',
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                ),
              )
            else
              ...habitProvider
                  .getAccessibleHabits(isPremium: userProvider.isPremium)
                  .map(
                    (habit) => CheckboxListTile(
                      title: Text(habit.name),
                      subtitle: Text(habit.category),
                      value: _selectedHabits.contains(habit.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedHabits.add(habit.id!);
                          } else {
                            _selectedHabits.remove(habit.id!);
                          }
                        });
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(UserProvider userProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () => _saveNotification(userProvider),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.notification != null
                        ? 'Update Notification'
                        : 'Create Notification',
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _saveNotification(UserProvider userProvider) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notification = NotificationSettings(
        id: widget.notification?.id,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        time: _selectedTime,
        daysOfWeek: _selectedDays,
        type: _selectedType,
        repetition: _selectedRepetition,
        isEnabled: _isEnabled,
        habitIds: _selectedHabits,
        createdAt: widget.notification?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 🔧 FIXED: Save to database first, then schedule
      final DatabaseService databaseService = DatabaseService();
      int notificationId;

      if (widget.notification != null) {
        // Update existing
        await databaseService.updateNotificationSetting(notification);
        notificationId = notification.id!;
      } else {
        // Create new
        notificationId = await databaseService.createNotificationSetting(
          notification,
        );
      }

      // Create notification with database ID for scheduling
      final notificationWithId = notification.copyWith(id: notificationId);

      // Schedule the notification
      final success = await NotificationService().scheduleNotification(
        notificationWithId,
      );

      if (success) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            widget.notification != null
                ? 'Notification updated successfully'
                : 'Notification created successfully',
          );
          Navigator.of(
            context,
          ).pop(true); // 🔧 FIXED: Return true to trigger refresh
        }
      } else {
        throw Exception('Failed to schedule notification');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to save notification: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteConfirmation() {
    Helpers.showConfirmDialog(
      context,
      title: 'Delete Notification',
      content: 'Are you sure you want to delete this notification?',
      onConfirm: _deleteNotification,
      confirmText: 'Delete',
    );
  }

  void _deleteNotification() async {
    if (widget.notification?.id == null) return;

    setState(() => _isLoading = true);

    try {
      // 🔧 FIXED: Delete from database and cancel notification
      final DatabaseService databaseService = DatabaseService();
      await databaseService.deleteNotificationSetting(widget.notification!.id!);
      await NotificationService().cancelNotification(widget.notification!.id!);

      if (mounted) {
        Helpers.showSnackBar(context, 'Notification deleted successfully');
        Navigator.of(
          context,
        ).pop(true); // 🔧 FIXED: Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to delete notification: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getTypeIcon() => _getTypeIconForType(_selectedType);
  Color _getTypeColor() => _getTypeColorForType(_selectedType);

  IconData _getTypeIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.simple:
        return Icons.notifications;
      case NotificationType.ringing:
        return Icons.notifications_active;
      case NotificationType.alarm:
        return Icons.alarm;
    }
  }

  Color _getTypeColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.simple:
        return AppTheme.infoColor;
      case NotificationType.ringing:
        return AppTheme.warningColor;
      case NotificationType.alarm:
        return AppTheme.errorColor;
    }
  }

  String _getTypeDescription(NotificationType type) {
    switch (type) {
      case NotificationType.simple:
        return 'Standard notification with sound and vibration';
      case NotificationType.ringing:
        return 'Persistent notification with repeating sound';
      case NotificationType.alarm:
        return 'Full-screen alarm with strong vibration';
    }
  }
}
