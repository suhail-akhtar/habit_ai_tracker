import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../providers/user_provider.dart';
import '../models/habit.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/premium_dialog.dart';

class HabitSetupScreen extends StatefulWidget {
  final Habit? habitToEdit;

  const HabitSetupScreen({
    super.key,
    this.habitToEdit,
  });

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
        title:
            Text(widget.habitToEdit != null ? 'Edit Habit' : 'Add New Habit'),
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
          return Form(
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
          );
        },
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
            Text(
              'Preview',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
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
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5)
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
            Text(
              'Basic Information',
              style: AppTheme.titleMedium,
            ),
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
            Text(
              'Category',
              style: AppTheme.titleMedium,
            ),
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
            Text(
              'Icon',
              style: AppTheme.titleMedium,
            ),
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
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
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
            Text(
              'Color',
              style: AppTheme.titleMedium,
            ),
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
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
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
            Text(
              'Target Frequency',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily',
                  style: AppTheme.bodyMedium,
                ),
                Switch(
                  value: _targetFrequency == 1,
                  onChanged: (value) {
                    setState(() {
                      _targetFrequency = value ? 1 : 7;
                    });
                  },
                ),
                Text(
                  'Weekly',
                  style: AppTheme.bodyMedium,
                ),
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
      HabitProvider habitProvider, UserProvider userProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () => _saveHabit(habitProvider, userProvider),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.habitToEdit != null
                    ? 'Update Habit'
                    : 'Create Habit'),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  void _saveHabit(
      HabitProvider habitProvider, UserProvider userProvider) async {
    if (!_formKey.currentState!.validate()) return;

    // Check premium limits for new habits
    if (widget.habitToEdit == null && !userProvider.canCreateMoreHabits) {
      showPremiumDialog(context,
          feature: 'Create more than ${Constants.freeHabitLimit} habits');
      return;
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
        createdAt: widget.habitToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.habitToEdit != null) {
        await habitProvider.updateHabit(habit);
        if (mounted) {
          Helpers.showSnackBar(context, Constants.successHabitUpdated);
        }
      } else {
        await habitProvider.addHabit(habit);
        if (mounted) {
          Helpers.showSnackBar(context, Constants.successHabitCreated);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to save habit: $e',
            isError: true);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      if (mounted) {
        Helpers.showSnackBar(context, Constants.successHabitDeleted);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to delete habit: $e',
            isError: true);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
