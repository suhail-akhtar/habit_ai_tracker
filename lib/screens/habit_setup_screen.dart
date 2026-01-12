import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/premium_dialog.dart';

class HabitSetupScreen extends StatefulWidget {
  final Habit? habitToEdit;

  const HabitSetupScreen({super.key, this.habitToEdit});

  @override
  State<HabitSetupScreen> createState() => _HabitSetupScreenState();
}

class _HabitSetupScreenState extends State<HabitSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = Constants.habitCategories.first;
  String _selectedIcon = Constants.habitIcons.first;
  Color _selectedColor = Constants.habitColors.first;
  int _targetFrequency = 1;

  // 🕒 NEW: Flexible Scheduling State
  String _frequencyType = 'daily';
  int _intervalMinutes = 60;
  TimeOfDay _windowStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _windowEndTime = const TimeOfDay(hour: 21, minute: 0);

  // 🔔 NEW: Notification State
  bool _isReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.habitToEdit != null) {
      _initializeWithExistingHabit();
    }
    // Check premium limits on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPremiumLimitsOnLoad();
    });
  }

  void _checkPremiumLimitsOnLoad() {
    if (widget.habitToEdit != null) return; // Editing existing habit
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final validation = userProvider.validateHabitCreation();

    if (!validation.isAllowed) {
      // Show premium dialog immediately and go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showPremiumDialog(
          context,
          feature: 'Create more than ${Constants.freeHabitLimit} habits',
          onClose: () {
            if (mounted) Navigator.of(context).pop();
          },
        );
      });
    }
  }

  void _initializeWithExistingHabit() {
    final habit = widget.habitToEdit!;
    _nameController.text = habit.name;
    _descriptionController.text = habit.description ?? '';
    _selectedCategory = habit.category;
    _selectedIcon = habit.iconName;
    _selectedColor = habit.color;
    _targetFrequency = habit.targetFrequency;

    // 🕒 NEW: Load Scheduling Data
    _frequencyType = habit.frequencyType;
    if (habit.intervalMinutes != null) {
      _intervalMinutes = habit.intervalMinutes!;
    }
    if (habit.windowStartTime != null) {
      final split = habit.windowStartTime!.split(':');
      _windowStartTime = TimeOfDay(
        hour: int.parse(split[0]),
        minute: int.parse(split[1]),
      );
    }
    if (habit.windowEndTime != null) {
      final split = habit.windowEndTime!.split(':');
      _windowEndTime = TimeOfDay(
        hour: int.parse(split[0]),
        minute: int.parse(split[1]),
      );
    }

    // 🔔 NEW: Load Notification Data
    _isReminderEnabled = habit.isReminderEnabled;
    if (habit.reminderTime != null) {
      final split = habit.reminderTime!.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(split[0]),
        minute: int.parse(split[1]),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.habitToEdit != null ? 'Edit Habit' : 'Add New Habit',
        ),
        actions: [
          if (widget.habitToEdit != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: Consumer2<HabitProvider, UserProvider>(
        builder: (context, habitProvider, userProvider, child) {
          return Column(
            children: [
              // Premium status banner for new habits
              if (widget.habitToEdit == null)
                _buildPremiumStatusBanner(userProvider),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHabitPreview(),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildBasicInfo(),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildCategorySelection(),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildIconSelection(),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildColorSelection(),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildFrequencySelection(),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildReminderSettings(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildActionButtons(habitProvider, userProvider),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumStatusBanner(UserProvider userProvider) {
    final validation = userProvider.validateHabitCreation();

    if (validation.type == PremiumValidationType.success &&
        userProvider.isPremium) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    Color textColor;
    IconData icon;

    if (!validation.isAllowed) {
      backgroundColor = AppTheme.errorColor.withAlpha(26);
      textColor = AppTheme.errorColor;
      icon = Icons.block;
    } else if (validation.type == PremiumValidationType.warning) {
      backgroundColor = AppTheme.warningColor.withAlpha(26);
      textColor = AppTheme.warningColor;
      icon = Icons.warning;
    } else {
      backgroundColor = AppTheme.infoColor.withAlpha(26);
      textColor = AppTheme.infoColor;
      icon = Icons.info;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!userProvider.isPremium) ...[
                  Text(
                    'Free Tier: ${userProvider.habitCount}/${Constants.freeHabitLimit} habits used',
                    style: AppTheme.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (validation.message != null) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      validation.message!,
                      style: AppTheme.bodySmall.copyWith(color: textColor),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (!userProvider.isPremium)
            TextButton(
              onPressed: () => showPremiumDialog(context),
              child: Text(
                'Upgrade',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHabitPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preview', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: _selectedColor.withAlpha(26),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: _selectedColor.withAlpha(77)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: _selectedColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      Helpers.getHabitIcon(_selectedIcon),
                      color: _selectedColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isEmpty
                              ? 'Habit Name'
                              : _nameController.text,
                          style: AppTheme.titleMedium.copyWith(
                            color: _nameController.text.isEmpty
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withAlpha(128)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          _selectedCategory,
                          style: AppTheme.bodySmall.copyWith(
                            color: _selectedColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Information', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                hintText: 'e.g., Drink 8 glasses of water',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a habit name';
                }
                if (value.trim().length > Constants.maxHabitNameLength) {
                  return 'Name must be less than ${Constants.maxHabitNameLength} characters';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add more details about your habit',
              ),
              maxLines: 3,
              validator: (value) {
                if (value != null &&
                    value.length > Constants.maxHabitDescriptionLength) {
                  return 'Description must be less than ${Constants.maxHabitDescriptionLength} characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              children: Constants.habitCategories.map((category) {
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  selected: isSelected,
                  label: Text(category),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
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

  Widget _buildIconSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Icon', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
                crossAxisSpacing: AppTheme.spacingS,
                mainAxisSpacing: AppTheme.spacingS,
              ),
              itemCount: Constants.habitIcons.length,
              itemBuilder: (context, index) {
                final icon = Constants.habitIcons[index];
                final isSelected = _selectedIcon == icon;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withAlpha(51)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                        color: isSelected
                            ? _selectedColor
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withAlpha(77),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      Helpers.getHabitIcon(icon),
                      color: isSelected
                          ? _selectedColor
                          : Theme.of(context).colorScheme.onSurface,
                      size: 24,
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

  Widget _buildColorSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Color', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
                crossAxisSpacing: AppTheme.spacingS,
                mainAxisSpacing: AppTheme.spacingS,
              ),
              itemCount: Constants.habitColors.length,
              itemBuilder: (context, index) {
                final color = Constants.habitColors[index];
                final isSelected = _selectedColor == color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule & Frequency', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),

            // Scheduling Type Selection
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _frequencyType = 'daily'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _frequencyType == 'daily'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Center(
                          child: Text(
                            'Simple Goal',
                            style: TextStyle(
                              color: _frequencyType == 'daily'
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: _frequencyType == 'daily'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _frequencyType = 'interval';
                          _updateCalculatedFrequency();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _frequencyType == 'interval'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Center(
                          child: Text(
                            'Recurring',
                            style: TextStyle(
                              color: _frequencyType == 'interval'
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: _frequencyType == 'interval'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),

            if (_frequencyType == 'daily')
              _buildDailyControls()
            else
              _buildIntervalControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Times per day:', style: AppTheme.bodyLarge),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _targetFrequency > 1
                      ? () => setState(() => _targetFrequency--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      '$_targetFrequency',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _targetFrequency < 50
                      ? () => setState(() => _targetFrequency++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          'You will aim to complete this $_targetFrequency times at any time during the day.',
          style: AppTheme.bodySmall.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildIntervalControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat Every:', style: AppTheme.bodyMedium),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withAlpha(77)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _intervalMinutes < 60
                        ? _intervalMinutes
                        : (_intervalMinutes % 60 == 0 ? _intervalMinutes : 60),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                      DropdownMenuItem(value: 45, child: Text('45 Minutes')),
                      DropdownMenuItem(value: 60, child: Text('1 Hour')),
                      DropdownMenuItem(value: 90, child: Text('1.5 Hours')),
                      DropdownMenuItem(value: 120, child: Text('2 Hours')),
                      DropdownMenuItem(value: 180, child: Text('3 Hours')),
                      DropdownMenuItem(value: 240, child: Text('4 Hours')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _intervalMinutes = val;
                          _updateCalculatedFrequency();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingL),

        Text('Active Hours:', style: AppTheme.bodyMedium),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: _buildTimePickerButton(
                time: _windowStartTime,
                label: 'Start',
                onPick: (t) {
                  setState(() {
                    _windowStartTime = t;
                    _updateCalculatedFrequency();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimePickerButton(
                time: _windowEndTime,
                label: 'End',
                onPick: (t) {
                  setState(() {
                    _windowEndTime = t;
                    _updateCalculatedFrequency();
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spacingL),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withAlpha(128),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Based on this schedule, your target is approx $_targetFrequency times per day.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerButton({
    required TimeOfDay time,
    required String label,
    required Function(TimeOfDay) onPick,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withAlpha(77)),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _updateCalculatedFrequency() {
    int startMins = _windowStartTime.hour * 60 + _windowStartTime.minute;
    int endMins = _windowEndTime.hour * 60 + _windowEndTime.minute;

    // Handle overnight schedules (e.g. 23:00 to 07:00)
    int diff = endMins - startMins;
    if (diff <= 0) diff += 24 * 60;

    if (_intervalMinutes > 0) {
      int count = (diff / _intervalMinutes).floor();
      // Ensure at least 1
      if (count < 1) count = 1;
      // Cap at 50 for safety
      if (count > 50) count = 50;

      setState(() {
        _targetFrequency = count;
      });
    }
  }

  Widget _buildReminderSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reminders', style: AppTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      _isReminderEnabled ? 'Enabled' : 'Disabled',
                      style: AppTheme.bodySmall.copyWith(
                        color: _isReminderEnabled ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isReminderEnabled,
                  onChanged: (val) {
                    setState(() {
                      _isReminderEnabled = val;
                    });
                  },
                ),
              ],
            ),

            if (_isReminderEnabled) ...[
              const Divider(height: 30),
              if (_frequencyType == 'daily') ...[
                Text('Reminder Time', style: AppTheme.bodyMedium),
                const SizedBox(height: AppTheme.spacingS),
                _buildTimePickerButton(
                  time: _reminderTime,
                  label: 'Notify at',
                  onPick: (t) => setState(() => _reminderTime = t),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'You will receive a notification at this time every day.',
                  style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      Icons.access_alarm,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifications will be scheduled for every interval between ${_windowStartTime.format(context)} and ${_windowEndTime.format(context)}.',
                        style: AppTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withAlpha(77)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Includes "Mark Done" action',
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    HabitProvider habitProvider,
    UserProvider userProvider,
  ) {
    // Check if save should be disabled
    final validation = userProvider.validateHabitCreation();
    final canSave = widget.habitToEdit != null || validation.isAllowed;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading || !canSave
                ? null
                : () => _saveHabit(habitProvider, userProvider),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.habitToEdit != null
                        ? 'Update Habit'
                        : 'Create Habit',
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => _handleCancel(),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCancel() async {
    // 🔧 FIXED: Unfocus input to close keyboard gracefully before navigation
    // This prevents IME/platform view crashes on some Android versions
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
      // Allow a brief moment for keyboard animation to start
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;

    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (kDebugMode) print('Navigation error: $e');
    }
  }

  // 🔧 FIXED: Save habit with proper navigation handling
  void _saveHabit(
    HabitProvider habitProvider,
    UserProvider userProvider,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    // Double-check premium limits before saving
    if (widget.habitToEdit == null) {
      final validation = userProvider.validateHabitCreation();
      if (!validation.isAllowed) {
        showPremiumDialog(
          context,
          feature: 'Create more than ${Constants.freeHabitLimit} habits',
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final habit = Habit(
        id: widget.habitToEdit?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        targetFrequency: _targetFrequency,
        colorCode: Helpers.colorToHex(_selectedColor),
        iconName: _selectedIcon,
        isActive: true,
        // 🕒 NEW: Save Scheduling Data
        frequencyType: _frequencyType,
        intervalMinutes: _frequencyType == 'interval' ? _intervalMinutes : null,
        windowStartTime: _frequencyType == 'interval'
            ? '${_windowStartTime.hour}:${_windowStartTime.minute.toString().padLeft(2, '0')}'
            : null,
        windowEndTime: _frequencyType == 'interval'
            ? '${_windowEndTime.hour}:${_windowEndTime.minute.toString().padLeft(2, '0')}'
            : null,

        // 🔔 NEW: Save Notification Data
        isReminderEnabled: _isReminderEnabled,
        reminderTime: _isReminderEnabled && _frequencyType == 'daily'
            ? '${_reminderTime.hour}:${_reminderTime.minute.toString().padLeft(2, '0')}'
            : null,

        createdAt: widget.habitToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.habitToEdit != null) {
        // Updating existing habit
        await habitProvider.updateHabit(habit);

        // 🔔 Schedule Reminders
        await NotificationService().scheduleHabitReminders(habit);

        if (mounted) {
          Helpers.showSnackBar(context, 'Habit updated successfully');
          Navigator.of(context).pop();
        }
      } else {
        // Creating new habit
        final success = await habitProvider.addHabit(
          habit,
          isPremium: userProvider.isPremium,
        );
        if (success && mounted) {
          // Update user provider habit count
          await userProvider.incrementHabitCount();

          if (!mounted) return;

          // � Schedule Reminders (Get newly created habit with ID)
          if (habitProvider.habits.isNotEmpty) {
            await NotificationService().scheduleHabitReminders(
              habitProvider.habits.first,
            );

            if (!mounted) return;
          }

          // �🔧 FIXED: Show success message and properly navigate back
          Helpers.showSnackBar(context, 'Habit created successfully');

          // Ensure we navigate back to the previous screen (dashboard)
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // Fallback navigation
            Navigator.of(context).pushReplacementNamed('/dashboard');
          }
        } else if (mounted) {
          // Show error from habitProvider if creation failed
          Helpers.showSnackBar(
            context,
            habitProvider.error ?? 'Failed to create habit',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to save habit: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeleteConfirmation() {
    Helpers.showConfirmDialog(
      context,
      title: 'Delete Habit',
      content:
          'Are you sure you want to delete this habit? This action cannot be undone.',
      onConfirm: () => _deleteHabit(),
      confirmText: 'Delete',
    );
  }

  void _deleteHabit() async {
    if (widget.habitToEdit?.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final habitProvider = context.read<HabitProvider>();
      final userProvider = context.read<UserProvider>();

      await habitProvider.deleteHabit(widget.habitToEdit!.id!);
      // Update user provider habit count
      await userProvider.decrementHabitCount();

      if (mounted) {
        Helpers.showSnackBar(context, 'Habit deleted successfully');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to delete habit: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
