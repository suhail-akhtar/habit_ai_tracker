import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../providers/custom_category_provider.dart';
import '../models/habit.dart';
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

  bool _isLoading = false;

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

                // Sanitize and validate the input
                String sanitized = Helpers.sanitizeHabitName(value);
                if (!Helpers.isValidHabitName(sanitized)) {
                  return 'Please enter a valid habit name (2-${Constants.maxHabitNameLength} characters)';
                }

                return null;
              },
              onChanged: (value) {
                // Auto-sanitize input as user types
                String sanitized = Helpers.sanitizeHabitName(value);
                if (sanitized != value) {
                  _nameController.text = sanitized;
                  _nameController.selection = TextSelection.fromPosition(
                    TextPosition(offset: sanitized.length),
                  );
                }
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
                if (value != null && value.isNotEmpty) {
                  String sanitized = Helpers.sanitizeNotes(value);
                  if (!Helpers.isValidNotes(sanitized)) {
                    return 'Description contains invalid content or exceeds ${Constants.maxHabitDescriptionLength} characters';
                  }
                }
                return null;
              },
              onChanged: (value) {
                // Auto-sanitize description input
                String sanitized = Helpers.sanitizeNotes(value);
                if (sanitized != value) {
                  _descriptionController.text = sanitized;
                  _descriptionController.selection = TextSelection.fromPosition(
                    TextPosition(offset: sanitized.length),
                  );
                }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daily', style: AppTheme.bodyMedium),
                Switch(
                  value: _targetFrequency == 1,
                  onChanged: (value) {
                    setState(() {
                      _targetFrequency = value ? 1 : 7;
                    });
                  },
                ),
                Text('Weekly', style: AppTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              _targetFrequency == 1
                  ? 'Complete this habit every day'
                  : 'Complete this habit once per week',
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
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

  void _handleCancel() {
    try {
      Navigator.of(context).pop();
    } catch (e) {
      // If pop fails, navigate to dashboard
      Navigator.of(context).pushReplacementNamed('/dashboard');
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
      // Sanitize inputs before creating habit
      final sanitizedName = Helpers.sanitizeHabitName(_nameController.text);
      final sanitizedDescription = _descriptionController.text.trim().isEmpty
          ? null
          : Helpers.sanitizeNotes(_descriptionController.text);
      final sanitizedCategory = Helpers.sanitizeCategory(_selectedCategory);

      final habit = Habit(
        id: widget.habitToEdit?.id,
        name: sanitizedName,
        description: sanitizedDescription,
        category: sanitizedCategory,
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

          // 🔧 FIXED: Show success message and properly navigate back
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
