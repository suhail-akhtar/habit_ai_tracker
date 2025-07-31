import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../providers/custom_category_provider.dart';
import '../models/habit.dart';
import '../models/notification_settings.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../services/ai_habit_assistant_service.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/premium_dialog.dart';

class HabitSetupScreen extends StatefulWidget {
  final Habit? habitToEdit;
  final Function(int)? onTabSwitch;

  const HabitSetupScreen({super.key, this.habitToEdit, this.onTabSwitch});

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
  String _frequencyType = 'daily'; // daily, weekly, custom
  List<bool> _weekDays = [true, true, true, true, true, true, true]; // Mon-Sun
  int _customDays = 3; // for "X times per week"

  // 🔔 NEW: Auto-notification settings
  bool _enableAutoNotifications = true;
  TimeOfDay _notificationTime = const TimeOfDay(
    hour: 9,
    minute: 0,
  ); // Default 9:00 AM
  String _selectedNotificationType = 'gentle'; // gentle, motivational, reminder
  bool _enableSmartTiming = true; // AI-suggested optimal timing

  bool _isLoading = false;

  // 🤖 AI Suggestion properties
  final _goalController = TextEditingController();
  bool _isLoadingAISuggestions = false;
  List<HabitSuggestion> _aiSuggestions = [];

  @override
  void initState() {
    super.initState();
    if (widget.habitToEdit != null) {
      _initializeWithExistingHabit();
    }
    // Load custom categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomCategoryProvider>().loadCustomCategories();
      _checkPremiumLimitsOnLoad();
    });
  }

  void _checkPremiumLimitsOnLoad() {
    if (widget.habitToEdit != null) return; // Editing existing habit

    final userProvider = context.read<UserProvider>();
    final validation = userProvider.validateHabitCreation();

    if (!validation.isAllowed) {
      // Show premium dialog immediately and go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showPremiumDialog(
          context,
          feature: 'Create more than ${Constants.freeHabitLimit} habits',
          onClose: () => Navigator.of(context).pop(),
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
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
          return LayoutBuilder(
            builder: (context, constraints) {
              // Responsive padding and spacing based on screen size
              final isSmallScreen = constraints.maxWidth < 600;
              final padding = isSmallScreen ? 12.0 : AppTheme.spacingM;
              final sectionSpacing = isSmallScreen ? 16.0 : AppTheme.spacingL;

              return Column(
                children: [
                  // Premium status banner for new habits
                  if (widget.habitToEdit == null)
                    _buildPremiumStatusBanner(userProvider),

                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHabitPreview(),
                            SizedBox(height: sectionSpacing),
                            _buildBasicInfo(),
                            SizedBox(height: sectionSpacing),
                            // AI-Powered Habit Suggestions (only for new habits)
                            if (widget.habitToEdit == null) ...[
                              _buildAISuggestions(),
                              SizedBox(height: sectionSpacing),
                            ],
                            _buildCategorySelection(),
                            SizedBox(height: sectionSpacing),
                            _buildIconSelection(),
                            SizedBox(height: sectionSpacing),
                            _buildColorSelection(),
                            SizedBox(height: sectionSpacing),
                            _buildFrequencySelection(),
                            SizedBox(height: sectionSpacing),
                            _buildNotificationSection(),
                            SizedBox(height: sectionSpacing * 2),
                            _buildActionButtons(habitProvider, userProvider),
                            SizedBox(height: padding), // Bottom padding
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
      backgroundColor = AppTheme.errorColor.withOpacity(0.1);
      textColor = AppTheme.errorColor;
      icon = Icons.block;
    } else if (validation.type == PremiumValidationType.warning) {
      backgroundColor = AppTheme.warningColor.withOpacity(0.1);
      textColor = AppTheme.warningColor;
      icon = Icons.warning;
    } else {
      backgroundColor = AppTheme.infoColor.withOpacity(0.1);
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
                color: _selectedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: _selectedColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.2),
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
                                  ).colorScheme.onSurface.withOpacity(0.5)
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

                if (value.trim().length < 2) {
                  return 'Habit name must be at least 2 characters';
                }
                if (value.trim().length > Constants.maxHabitNameLength) {
                  return 'Habit name must be less than ${Constants.maxHabitNameLength} characters';
                }

                return null;
              },
              onChanged: (value) {
                setState(() {});
              },
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
                    value.trim().isNotEmpty &&
                    value.trim().length > Constants.maxHabitDescriptionLength) {
                  return 'Description must be less than ${Constants.maxHabitDescriptionLength} characters';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Consumer<CustomCategoryProvider>(
      builder: (context, categoryProvider, child) {
        final customCategories = categoryProvider.customCategories;
        final allCategories = [...Constants.habitCategories];

        // Add custom categories to the list
        for (final customCategory in customCategories) {
          allCategories.add(customCategory.name);
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Category', style: AppTheme.titleMedium),
                    if (customCategories.isNotEmpty)
                      Text(
                        '${customCategories.length} custom',
                        style: AppTheme.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: allCategories.map((category) {
                    final isSelected = _selectedCategory == category;
                    final isCustom = customCategories.any(
                      (c) => c.name == category,
                    );
                    final customCategory = isCustom
                        ? customCategories.firstWhere((c) => c.name == category)
                        : null;

                    return FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCustom && customCategory != null) ...[
                            Icon(
                              Helpers.getHabitIcon(customCategory.iconName),
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : Helpers.getHabitColor(
                                      customCategory.colorCode,
                                    ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(category),
                        ],
                      ),
                      backgroundColor: isCustom && customCategory != null
                          ? Helpers.getHabitColor(
                              customCategory.colorCode,
                            ).withOpacity(0.1)
                          : null,
                      selectedColor: isCustom && customCategory != null
                          ? Helpers.getHabitColor(customCategory.colorCode)
                          : null,
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
                if (customCategories.isEmpty) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Create custom categories in Settings for more options',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
                          ? _selectedColor.withOpacity(0.2)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                        color: isSelected
                            ? _selectedColor
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.3),
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
            Text('Target Frequency', style: AppTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingM),

            // Frequency Type Selection
            _buildFrequencyTypeSelector(),
            const SizedBox(height: AppTheme.spacingM),

            // Specific frequency controls
            if (_frequencyType == 'daily') _buildDailyOptions(),
            if (_frequencyType == 'weekly') _buildWeeklyOptions(),
            if (_frequencyType == 'custom') _buildCustomOptions(),

            const SizedBox(height: AppTheme.spacingS),
            _buildFrequencyDescription(),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyTypeSelector() {
    return Row(
      children: [
        Expanded(child: _buildFrequencyChip('Daily', 'daily', Icons.today)),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: _buildFrequencyChip(
            'Weekly',
            'weekly',
            Icons.calendar_view_week,
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(child: _buildFrequencyChip('Custom', 'custom', Icons.tune)),
      ],
    );
  }

  Widget _buildFrequencyChip(String label, String type, IconData icon) {
    final isSelected = _frequencyType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _frequencyType = type;
          _updateTargetFrequency();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingS,
          horizontal: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Every day', style: AppTheme.bodyMedium),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Build consistency with daily practice',
              style: AppTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select days of the week:', style: AppTheme.bodyMedium),
        const SizedBox(height: AppTheme.spacingS),
        _buildWeekDaySelector(),
      ],
    );
  }

  Widget _buildWeekDaySelector() {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _weekDays[index] = !_weekDays[index];
              _updateTargetFrequency();
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _weekDays[index]
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: _weekDays[index]
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Center(
              child: Text(
                dayLabels[index],
                style: AppTheme.bodySmall.copyWith(
                  color: _weekDays[index]
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: _weekDays[index]
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCustomOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Times per week:', style: AppTheme.bodyMedium),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            IconButton(
              onPressed: _customDays > 1
                  ? () {
                      setState(() {
                        _customDays--;
                        _updateTargetFrequency();
                      });
                    }
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Text('$_customDays times', style: AppTheme.bodyMedium),
            ),
            IconButton(
              onPressed: _customDays < 7
                  ? () {
                      setState(() {
                        _customDays++;
                        _updateTargetFrequency();
                      });
                    }
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrequencyDescription() {
    String description;
    switch (_frequencyType) {
      case 'daily':
        description = 'Complete this habit every day to build consistency';
        break;
      case 'weekly':
        final selectedDays = _weekDays.where((day) => day).length;
        description = selectedDays > 0
            ? 'Complete this habit $selectedDays ${selectedDays == 1 ? 'time' : 'times'} per week'
            : 'Please select at least one day';
        break;
      case 'custom':
        description =
            'Complete this habit $_customDays ${_customDays == 1 ? 'time' : 'times'} per week, any days you choose';
        break;
      default:
        description = '';
    }

    return Text(
      description,
      style: AppTheme.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
      ),
    );
  }

  void _updateTargetFrequency() {
    switch (_frequencyType) {
      case 'daily':
        _targetFrequency = 1;
        break;
      case 'weekly':
        _targetFrequency = _weekDays.where((day) => day).length;
        break;
      case 'custom':
        _targetFrequency = _customDays;
        break;
    }
  }

  // 🤖 AI-Powered Habit Suggestions
  Widget _buildAISuggestions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text('AI Habit Suggestions ✨', style: AppTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Goal input field for AI suggestions
            TextField(
              decoration: InputDecoration(
                hintText:
                    'Tell me your goal (e.g., "lose weight", "be more productive")',
                prefixIcon: const Icon(Icons.lightbulb_outline),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: _generateAISuggestions,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
              controller: _goalController,
              onSubmitted: (_) => _generateAISuggestions(),
            ),

            const SizedBox(height: AppTheme.spacingM),

            // AI-generated suggestions or default ones
            if (_isLoadingAISuggestions)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingM),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_aiSuggestions.isNotEmpty)
              Wrap(
                spacing: AppTheme.spacingS,
                runSpacing: AppTheme.spacingS,
                children: _aiSuggestions
                    .take(6)
                    .map((suggestion) => _buildAISuggestionChip(suggestion))
                    .toList(),
              )
            else
              // Fallback to default suggestions
              Wrap(
                spacing: AppTheme.spacingS,
                runSpacing: AppTheme.spacingS,
                children: [
                  _buildSuggestionChip(
                    '🏃‍♂️ Morning Run',
                    'Exercise',
                    Icons.directions_run,
                    Colors.orange,
                  ),
                  _buildSuggestionChip(
                    '📚 Read 20 Pages',
                    'Learning',
                    Icons.book,
                    Colors.blue,
                  ),
                  _buildSuggestionChip(
                    '💧 Drink 8 Glasses',
                    'Health',
                    Icons.local_drink,
                    Colors.cyan,
                  ),
                  _buildSuggestionChip(
                    '🧘‍♀️ 10min Meditation',
                    'Mindfulness',
                    Icons.self_improvement,
                    Colors.purple,
                  ),
                  _buildSuggestionChip(
                    '📱 Digital Detox',
                    'Productivity',
                    Icons.phone_android,
                    Colors.red,
                  ),
                ],
              ),

            const SizedBox(height: AppTheme.spacingM),

            // Smart input assistant
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'Type your goal above and tap ✨ to get personalized AI suggestions!',
                      style: AppTheme.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
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

  Widget _buildSuggestionChip(
    String title,
    String category,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => _applySuggestion(title, category, icon, color),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              title,
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applySuggestion(
    String title,
    String category,
    IconData icon,
    Color color,
  ) {
    setState(() {
      _nameController.text = title.split(' ').skip(1).join(' '); // Remove emoji
      _selectedCategory = category;
      _selectedIcon = icon.codePoint.toString();
      _selectedColor = color;

      // Smart frequency suggestions based on habit type
      if (title.contains('Morning') || title.contains('Daily')) {
        _frequencyType = 'daily';
        _targetFrequency = 1;
      } else if (title.contains('Week')) {
        _frequencyType = 'custom';
        _customDays = 3;
        _targetFrequency = 3;
      }
    });

    // Show feedback
    Helpers.showSnackBar(
      context,
      'Applied suggestion: ${title.split(' ').skip(1).join(' ')}',
    );
  }

  // 🤖 AI Suggestion Methods
  Future<void> _generateAISuggestions() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please enter your goal first',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoadingAISuggestions = true;
    });

    try {
      final aiService = AIHabitAssistantService();
      final habitProvider = context.read<HabitProvider>();

      final suggestions = await aiService.generateHabitSuggestions(
        userGoal: goal,
        existingHabits: habitProvider.habits,
        userLevel: 'beginner', // Could be dynamic based on user data
      );

      setState(() {
        _aiSuggestions = suggestions;
        _isLoadingAISuggestions = false;
      });

      if (suggestions.isNotEmpty) {
        Helpers.showSnackBar(
          context,
          'Generated ${suggestions.length} personalized suggestions!',
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingAISuggestions = false;
      });

      Helpers.showSnackBar(
        context,
        'Failed to generate AI suggestions. Using defaults.',
        isError: true,
      );
    }
  }

  Widget _buildAISuggestionChip(HabitSuggestion suggestion) {
    // Map category to color and icon
    final categoryData = _getCategoryData(suggestion.category);

    return GestureDetector(
      onTap: () => _applyAISuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: categoryData['color'].withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: categoryData['color'].withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  categoryData['icon'],
                  color: categoryData['color'],
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Flexible(
                  child: Text(
                    suggestion.name,
                    style: AppTheme.bodySmall.copyWith(
                      color: categoryData['color'],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${suggestion.timeCommitment} • ${suggestion.difficulty}',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getCategoryData(String category) {
    switch (category.toLowerCase()) {
      case 'health':
        return {'color': Colors.green, 'icon': Icons.favorite};
      case 'fitness':
      case 'exercise':
        return {'color': Colors.orange, 'icon': Icons.fitness_center};
      case 'learning':
      case 'education':
        return {'color': Colors.blue, 'icon': Icons.school};
      case 'mindfulness':
      case 'meditation':
        return {'color': Colors.purple, 'icon': Icons.self_improvement};
      case 'productivity':
        return {'color': Colors.red, 'icon': Icons.work};
      case 'social':
        return {'color': Colors.pink, 'icon': Icons.people};
      case 'creativity':
        return {'color': Colors.amber, 'icon': Icons.palette};
      default:
        return {'color': Colors.grey, 'icon': Icons.star};
    }
  }

  void _applyAISuggestion(HabitSuggestion suggestion) {
    final categoryData = _getCategoryData(suggestion.category);

    setState(() {
      _nameController.text = suggestion.name;
      _selectedCategory = suggestion.category;
      _selectedIcon = categoryData['icon'].codePoint.toString();
      _selectedColor = categoryData['color'];

      // Smart frequency suggestions based on time commitment
      if (suggestion.timeCommitment.contains('daily') ||
          suggestion.difficulty.toLowerCase() == 'easy') {
        _frequencyType = 'daily';
        _targetFrequency = 1;
      } else if (suggestion.timeCommitment.contains('week')) {
        _frequencyType = 'custom';
        _customDays = 3;
        _targetFrequency = 3;
      }
    });

    // Show feedback with benefit
    Helpers.showSnackBar(
      context,
      '✨ Applied: ${suggestion.name} - ${suggestion.benefit}',
    );
  }

  // 🔔 NEW: Auto-Notification Section
  Widget _buildNotificationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Smart Reminders',
                  style: AppTheme.titleMedium.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _enableAutoNotifications,
                  onChanged: (value) {
                    setState(() {
                      _enableAutoNotifications = value;
                    });
                  },
                ),
              ],
            ),
            if (_enableAutoNotifications) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Automatically create helpful reminders for this habit',
                style: AppTheme.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Notification Time Picker
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    size: 18,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text('Reminder Time:', style: AppTheme.bodyMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: _pickNotificationTime,
                    child: Text(
                      _notificationTime.format(context),
                      style: AppTheme.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingS),

              // Notification Type Selection
              Text('Reminder Style:', style: AppTheme.bodyMedium),
              const SizedBox(height: AppTheme.spacingS),
              _buildNotificationTypeChips(),

              const SizedBox(height: AppTheme.spacingM),

              // Smart Timing Toggle
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    size: 18,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI-Optimized Timing', style: AppTheme.bodyMedium),
                        Text(
                          'Let AI suggest the best reminder times',
                          style: AppTheme.bodySmall.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enableSmartTiming,
                    onChanged: (value) {
                      setState(() {
                        _enableSmartTiming = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypeChips() {
    final types = [
      {'key': 'gentle', 'label': 'Gentle', 'icon': Icons.spa},
      {
        'key': 'motivational',
        'label': 'Motivational',
        'icon': Icons.fitness_center,
      },
      {'key': 'reminder', 'label': 'Simple', 'icon': Icons.notifications},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedNotificationType == type['key'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingS),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    type['label'] as String,
                    style: AppTheme.bodySmall.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                  ),
                ],
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedNotificationType = type['key'] as String;
                  });
                }
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (picked != null && picked != _notificationTime) {
      setState(() {
        _notificationTime = picked;
      });
    }
  }

  // 🔔 NEW: Create auto-notifications for habit
  Future<void> _createAutoNotifications(
    Habit habit, {
    required bool isUpdate,
  }) async {
    try {
      // Debug logging
      print(
        '🔔 Creating auto-notifications for habit: ${habit.name} (ID: ${habit.id})',
      );

      if (habit.id == null) {
        throw Exception('Habit ID is null - cannot create notifications');
      }

      final notificationService = NotificationService();
      final databaseService = DatabaseService();

      // Ensure notification service is initialized
      print('🔔 Initializing notification service...');
      await notificationService.initialize();

      if (isUpdate) {
        // 🔧 FIXED: For updates, delete existing notifications first
        print('🔔 Removing existing notifications for habit update...');
        await _removeExistingNotifications(habit.id!);
      }

      // Generate personalized notification messages
      List<String> messages = _generateNotificationMessages(habit);

      // Create notification settings for the habit
      final notificationSettings = NotificationSettings(
        id: null, // Will be auto-generated
        title: _getNotificationTitle(habit),
        message: messages.first,
        time: _notificationTime,
        type: _getNotificationTypeEnum(_selectedNotificationType),
        repetition: RepetitionType.daily,
        isEnabled: true,
        habitIds: [habit.id!],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('🔔 Saving notification settings to database...');
      // Save to database
      await databaseService.createNotificationSetting(notificationSettings);

      print('🔔 Scheduling notification with NotificationService...');
      // Schedule the notification using the legacy method
      await notificationService.scheduleHabitReminder(
        habit.id!,
        habit.name,
        _notificationTime,
        enabled: true,
      );

      // If smart timing is enabled, schedule additional optimized reminders
      if (_enableSmartTiming) {
        print('🔔 Scheduling smart reminders...');
        await _scheduleSmartReminders(habit, messages);
      }

      if (mounted) {
        final action = isUpdate ? 'updated' : 'created';
        Helpers.showSnackBar(
          context,
          'Smart reminders $action for ${habit.name}',
        );
      }

      print('🔔 Auto-notifications successfully created for ${habit.name}');
    } catch (e) {
      print('❌ Failed to create auto-notifications: $e');
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to set up reminders: $e',
          isError: true,
        );
      }
    }
  }

  // 🔧 NEW: Remove existing notifications for a habit
  Future<void> _removeExistingNotifications(int habitId) async {
    try {
      final databaseService = DatabaseService();
      final notificationService = NotificationService();

      // Get existing notifications for this habit
      final existingNotifications = await databaseService
          .getNotificationSettings();
      final habitNotifications = existingNotifications
          .where((notification) => notification.habitIds.contains(habitId))
          .toList();

      // Remove from database and cancel scheduled notifications
      for (final notification in habitNotifications) {
        if (notification.id != null) {
          await databaseService.deleteNotificationSetting(notification.id!);
          await notificationService.cancelNotification(habitId);

          // Also cancel smart timing notifications
          for (int i = 1; i <= 3; i++) {
            final smartReminderId = (habitId * 1000) + i;
            await notificationService.cancelNotification(smartReminderId);
          }
        }
      }

      print(
        '🔔 Removed ${habitNotifications.length} existing notifications for habit $habitId',
      );
    } catch (e) {
      print('❌ Failed to remove existing notifications: $e');
      // Don't throw - we can continue with creating new notifications
    }
  }

  NotificationType _getNotificationTypeEnum(String type) {
    switch (type) {
      case 'gentle':
      case 'reminder':
        return NotificationType.simple;
      case 'motivational':
        return NotificationType.ringing;
      default:
        return NotificationType.simple;
    }
  }

  List<String> _generateNotificationMessages(Habit habit) {
    final messages = <String>[];

    switch (_selectedNotificationType) {
      case 'gentle':
        messages.addAll([
          'Gentle reminder: Time for ${habit.name} 🌱',
          'Your ${habit.name} journey continues today ✨',
          'A peaceful moment for ${habit.name} awaits 🕊️',
        ]);
        break;
      case 'motivational':
        messages.addAll([
          'You\'ve got this! Time for ${habit.name} 💪',
          'Another step towards greatness: ${habit.name} 🚀',
          'Your future self will thank you for ${habit.name} 🌟',
        ]);
        break;
      case 'reminder':
        messages.addAll([
          'Reminder: ${habit.name}',
          'Time for ${habit.name}',
          'Don\'t forget: ${habit.name}',
        ]);
        break;
      default:
        messages.add('Time for ${habit.name}');
    }

    return messages;
  }

  String _getNotificationTitle(Habit habit) {
    switch (_selectedNotificationType) {
      case 'gentle':
        return 'Gentle Reminder';
      case 'motivational':
        return 'You\'ve Got This!';
      case 'reminder':
        return 'Habit Reminder';
      default:
        return 'Habit Tracker';
    }
  }

  Future<void> _scheduleSmartReminders(
    Habit habit,
    List<String> messages,
  ) async {
    // AI-optimized reminder times based on habit category and user patterns
    final smartTimes = _getSmartReminderTimes(habit);
    final notificationService = NotificationService();

    // Create additional smart reminders with incremental IDs
    for (int i = 0; i < smartTimes.length && i < messages.length; i++) {
      final smartReminderId =
          (habit.id! * 1000) + i + 1; // Unique ID for smart reminders

      await notificationService.scheduleHabitReminder(
        smartReminderId,
        '${habit.name} (Smart Timing)',
        smartTimes[i],
        enabled: true,
      );
    }
  }

  List<TimeOfDay> _getSmartReminderTimes(Habit habit) {
    final baseTime = _notificationTime;
    final smartTimes = <TimeOfDay>[];

    // Generate smart times based on habit category
    switch (habit.category.toLowerCase()) {
      case 'fitness':
        // Early morning and evening
        smartTimes.addAll([
          const TimeOfDay(hour: 6, minute: 30),
          const TimeOfDay(hour: 18, minute: 0),
        ]);
        break;
      case 'health':
        // Morning, lunch, evening
        smartTimes.addAll([
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 12, minute: 30),
          const TimeOfDay(hour: 20, minute: 0),
        ]);
        break;
      case 'productivity':
        // Work hours
        smartTimes.addAll([
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 16, minute: 30),
        ]);
        break;
      default:
        // Default times around user's selected time
        final hour = baseTime.hour;
        smartTimes.addAll([
          TimeOfDay(hour: (hour - 1).clamp(0, 23), minute: baseTime.minute),
          TimeOfDay(hour: (hour + 1).clamp(0, 23), minute: baseTime.minute),
        ]);
    }

    return smartTimes;
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

  void _handleCancel() {
    // If we're in a tab context, we need to reset the form and stay
    if (widget.habitToEdit != null) {
      // For editing, we can navigate back
      Navigator.of(context).pop();
    } else {
      // For new habits, reset the form and switch to dashboard tab
      _resetForm();
      // Always switch to dashboard tab after canceling
      if (widget.onTabSwitch != null) {
        widget.onTabSwitch!(0); // Switch to dashboard tab (index 0)
      } else {
        // Fallback: try to navigate back
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = Constants.habitCategories.first;
      _selectedIcon = Constants.habitIcons.first;
      _selectedColor = Constants.habitColors.first;
      _targetFrequency = 1;
      _frequencyType = 'daily';
      _weekDays = [true, true, true, true, true, true, true];
      _customDays = 3;
    });
  }

  void _switchToDashboardTab() {
    // Find the parent MainNavigationScreen and switch to dashboard tab
    final navigator = Navigator.of(context);

    // Primary approach: Use the callback if available
    if (widget.onTabSwitch != null) {
      widget.onTabSwitch!(0); // Switch to dashboard tab (index 0)
      return;
    }

    // Secondary approach: Pop back to main navigation
    if (navigator.canPop()) {
      // Pop back to the main navigation screen
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    // Tertiary approach: Force navigation state update
    if (mounted) {
      // Schedule a rebuild to ensure UI state is updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Try to find and update parent state
          context.visitAncestorElements((element) {
            if (element.widget.runtimeType.toString().contains(
              'MainNavigation',
            )) {
              // Force rebuild of navigation
              element.markNeedsBuild();
              return false;
            }
            return true;
          });
        }
      });
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
      // Simple trimming without sanitization
      final trimmedName = _nameController.text.trim();
      final trimmedDescription = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final trimmedCategory = _selectedCategory.trim();

      // Check for duplicate habit names (case-insensitive)
      final existingHabits = habitProvider.habits;
      final isDuplicate = existingHabits.any(
        (habit) =>
            habit.name.toLowerCase() == trimmedName.toLowerCase() &&
            (widget.habitToEdit == null || habit.id != widget.habitToEdit!.id),
      );

      if (isDuplicate) {
        Helpers.showSnackBar(
          context,
          'A habit with this name already exists. Please choose a different name.',
          isError: true,
        );
        return;
      }

      final habit = Habit(
        id: widget.habitToEdit?.id,
        name: trimmedName,
        description: trimmedDescription,
        category: trimmedCategory,
        targetFrequency: _targetFrequency,
        colorCode: Helpers.colorToHex(_selectedColor),
        iconName: _selectedIcon,
        isActive: true,
        createdAt: widget.habitToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.habitToEdit != null) {
        // Updating existing habit
        await habitProvider.updateHabit(habit);

        // 🔔 NEW: Update auto-notifications for edited habit
        if (_enableAutoNotifications && mounted) {
          await _createAutoNotifications(habit, isUpdate: true);
        }

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

          // 🔔 NEW: Create auto-notifications for new habit
          if (_enableAutoNotifications) {
            // Get the newly created habit with its ID from the provider
            final createdHabit = habitProvider.habits.firstWhere(
              (h) => h.name == habit.name && h.category == habit.category,
            );
            await _createAutoNotifications(createdHabit, isUpdate: false);
          }

          // 🔧 FIXED: Show success message and properly navigate back
          Helpers.showSnackBar(context, 'Habit created successfully');

          // Reset form and navigate back to dashboard
          _resetForm();

          // Always switch to dashboard tab after creating habit
          if (widget.onTabSwitch != null) {
            widget.onTabSwitch!(0); // Switch to dashboard tab (index 0)
          } else {
            _switchToDashboardTab(); // Fallback method
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
      await context.read<HabitProvider>().deleteHabit(widget.habitToEdit!.id!);
      // Update user provider habit count
      await context.read<UserProvider>().decrementHabitCount();

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
