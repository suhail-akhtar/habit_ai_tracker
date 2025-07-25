import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/custom_category_provider.dart';
import '../providers/user_provider.dart';
import '../models/custom_habit_category.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/premium_dialog.dart';

class CustomCategoriesScreen extends StatefulWidget {
  const CustomCategoriesScreen({super.key});

  @override
  State<CustomCategoriesScreen> createState() => _CustomCategoriesScreenState();
}

class _CustomCategoriesScreenState extends State<CustomCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomCategoryProvider>().loadCustomCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Categories'),
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return IconButton(
                onPressed: () =>
                    _showCreateCategoryDialog(userProvider.isPremium),
                icon: const Icon(Icons.add),
                tooltip: 'Add Custom Category',
              );
            },
          ),
        ],
      ),
      body: Consumer2<CustomCategoryProvider, UserProvider>(
        builder: (context, categoryProvider, userProvider, child) {
          if (categoryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => categoryProvider.loadCustomCategories(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPremiumBanner(userProvider),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildDefaultCategories(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildCustomCategories(categoryProvider, userProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumBanner(UserProvider userProvider) {
    if (userProvider.isPremium) {
      return Card(
        color: AppTheme.successColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              Icon(Icons.star, color: AppTheme.successColor, size: 24),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Active',
                      style: AppTheme.titleMedium.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Create up to ${Constants.maxCustomCategories} custom categories',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.successColor,
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

    return Card(
      color: AppTheme.warningColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Icon(Icons.lock, color: AppTheme.warningColor, size: 24),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Categories',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Upgrade to Premium to create custom categories with custom icons',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  showPremiumDialog(context, feature: 'Custom Categories'),
              child: Text(
                'Upgrade',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Default Categories', style: AppTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingM),
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: Constants.habitCategories.map((category) {
            return _buildCategoryChip(
              category,
              Icons.category,
              Colors.blue,
              isDefault: true,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomCategories(
    CustomCategoryProvider categoryProvider,
    UserProvider userProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Custom Categories', style: AppTheme.titleMedium),
            if (userProvider.isPremium)
              Text(
                '${categoryProvider.customCategories.length}/${Constants.maxCustomCategories}',
                style: AppTheme.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        if (categoryProvider.customCategories.isEmpty)
          _buildEmptyCustomCategories(userProvider)
        else
          Wrap(
            spacing: AppTheme.spacingS,
            runSpacing: AppTheme.spacingS,
            children: categoryProvider.customCategories.map((category) {
              return _buildCategoryChip(
                category.name,
                categoryProvider.getCategoryIcon(category.name),
                categoryProvider.getCategoryColor(category.name),
                isDefault: false,
                onLongPress: userProvider.isPremium
                    ? () => _showCategoryOptions(category)
                    : null,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildEmptyCustomCategories(UserProvider userProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            userProvider.isPremium ? Icons.add_circle_outline : Icons.lock,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            userProvider.isPremium
                ? 'No custom categories yet'
                : 'Premium Feature',
            style: AppTheme.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            userProvider.isPremium
                ? 'Tap the + button to create your first custom category'
                : 'Upgrade to Premium to create custom categories',
            style: AppTheme.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          if (!userProvider.isPremium) ...[
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: () =>
                  showPremiumDialog(context, feature: 'Custom Categories'),
              child: const Text('Upgrade to Premium'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    String name,
    IconData icon,
    Color color, {
    bool isDefault = false,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, size: 16, color: color),
        ),
        label: Text(name),
        backgroundColor: isDefault
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : color.withOpacity(0.1),
        side: BorderSide(
          color: isDefault
              ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
              : color.withOpacity(0.3),
        ),
      ),
    );
  }

  void _showCreateCategoryDialog(bool isPremium) {
    if (!isPremium) {
      showPremiumDialog(context, feature: 'Custom Categories');
      return;
    }

    showDialog(context: context, builder: (context) => _CreateCategoryDialog());
  }

  void _showCategoryOptions(CustomHabitCategory category) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _CategoryOptionsSheet(category: category),
    );
  }
}

class _CreateCategoryDialog extends StatefulWidget {
  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = 'category';
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;

  final List<String> _availableIcons = [
    'category',
    'sports',
    'school',
    'home',
    'favorite',
    'star',
    'lightbulb',
    'palette',
    'shopping_cart',
    'travel_explore',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Custom Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Gaming, Photography',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text('Select Icon', style: AppTheme.titleSmall),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              children: _availableIcons.map((iconName) {
                final icon = _getIconFromName(iconName);
                final isSelected = _selectedIcon == iconName;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = iconName),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withOpacity(0.2)
                          : null,
                      border: Border.all(
                        color: isSelected
                            ? _selectedColor
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? _selectedColor : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text('Select Color', style: AppTheme.titleSmall),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              children: Constants.habitColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createCategory,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  void _createCategory() async {
    if (_nameController.text.trim().isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please enter a category name',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await context
          .read<CustomCategoryProvider>()
          .createCustomCategory(
            name: _nameController.text.trim(),
            iconName: _selectedIcon,
            colorCode: Helpers.colorToHex(_selectedColor),
            isPremium: true, // We've already checked premium status
          );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          Helpers.showSnackBar(
            context,
            'Custom category created successfully!',
          );
        } else {
          final error = context.read<CustomCategoryProvider>().error;
          Helpers.showSnackBar(
            context,
            error ?? 'Failed to create category',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'category':
        return Icons.category;
      case 'sports':
        return Icons.sports;
      case 'school':
        return Icons.school;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'palette':
        return Icons.palette;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'travel_explore':
        return Icons.travel_explore;
      default:
        return Icons.category;
    }
  }
}

class _CategoryOptionsSheet extends StatelessWidget {
  final CustomHabitCategory category;

  const _CategoryOptionsSheet({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(category.name, style: AppTheme.titleLarge),
          const SizedBox(height: AppTheme.spacingL),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Category'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement edit functionality
              Helpers.showSnackBar(context, 'Edit feature coming soon!');
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: AppTheme.errorColor),
            title: Text(
              'Delete Category',
              style: TextStyle(color: AppTheme.errorColor),
            ),
            onTap: () => _showDeleteConfirmation(context),
          ),
          const SizedBox(height: AppTheme.spacingL),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    Navigator.pop(context); // Close the options sheet

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final success = await context
                  .read<CustomCategoryProvider>()
                  .deleteCustomCategory(category.id!);

              if (context.mounted) {
                Helpers.showSnackBar(
                  context,
                  success
                      ? 'Category deleted successfully'
                      : context.read<CustomCategoryProvider>().error ??
                            'Failed to delete category',
                  isError: !success,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
