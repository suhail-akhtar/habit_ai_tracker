import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/custom_habit_category.dart';
import '../utils/constants.dart';

class CustomCategoryProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<CustomHabitCategory> _customCategories = [];
  bool _isLoading = false;
  String? _error;

  List<CustomHabitCategory> get customCategories => _customCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get all available categories (default + custom)
  List<String> getAllCategories({bool isPremium = false}) {
    final defaultCategories = Constants.habitCategories;

    if (!isPremium) {
      return defaultCategories;
    }

    final customCategoryNames = _customCategories.map((c) => c.name).toList();
    return [...defaultCategories, ...customCategoryNames];
  }

  /// Get custom category by name
  CustomHabitCategory? getCustomCategoryByName(String name) {
    try {
      return _customCategories.firstWhere((c) => c.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Check if category is custom (premium feature)
  bool isCustomCategory(String categoryName) {
    return _customCategories.any((c) => c.name == categoryName);
  }

  /// Load all custom categories
  Future<void> loadCustomCategories() async {
    _setLoading(true);
    try {
      _customCategories = await _databaseService.getCustomCategories();
      _clearError();
    } catch (e) {
      _setError('Failed to load custom categories: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new custom category (Premium only)
  Future<bool> createCustomCategory({
    required String name,
    required String iconName,
    required String colorCode,
    required bool isPremium,
  }) async {
    try {
      if (!isPremium) {
        _setError(
          'Custom categories are a Premium feature. Upgrade to create custom categories.',
        );
        return false;
      }

      // Check if category name already exists
      if (Constants.habitCategories.contains(name) ||
          _customCategories.any(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
          )) {
        _setError(
          'Category name already exists. Please choose a different name.',
        );
        return false;
      }

      // Check premium limits
      if (_customCategories.length >= Constants.maxCustomCategories) {
        _setError(
          'Maximum ${Constants.maxCustomCategories} custom categories allowed.',
        );
        return false;
      }

      _setLoading(true);

      final category = CustomHabitCategory(
        name: name,
        iconName: iconName,
        colorCode: colorCode,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final categoryId = await _databaseService.insertCustomCategory(category);

      if (categoryId != null) {
        final categoryWithId = category.copyWith(id: categoryId);
        _customCategories.add(categoryWithId);

        _clearError();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _setError('Failed to create custom category: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing custom category
  Future<bool> updateCustomCategory(CustomHabitCategory category) async {
    try {
      _setLoading(true);

      final updated = category.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateCustomCategory(updated);

      final index = _customCategories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _customCategories[index] = updated;

        _clearError();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update custom category: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a custom category
  Future<bool> deleteCustomCategory(int categoryId) async {
    try {
      _setLoading(true);

      // Check if category is being used by any habits
      final isUsed = await _databaseService.isCategoryInUse(categoryId);
      if (isUsed) {
        _setError('Cannot delete category that is being used by habits.');
        return false;
      }

      await _databaseService.deleteCustomCategory(categoryId);
      _customCategories.removeWhere((c) => c.id == categoryId);

      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete custom category: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get icon for category (checks custom categories first)
  IconData getCategoryIcon(String categoryName) {
    final customCategory = getCustomCategoryByName(categoryName);
    if (customCategory != null) {
      return _getIconFromName(customCategory.iconName);
    }

    // Return default icon for default categories
    return Icons.category;
  }

  /// Get color for category (checks custom categories first)
  Color getCategoryColor(String categoryName) {
    final customCategory = getCustomCategoryByName(categoryName);
    if (customCategory != null) {
      return Color(
        int.parse(customCategory.colorCode.replaceFirst('#', '0xFF')),
      );
    }

    // Return default color for default categories
    return Colors.blue;
  }

  /// Convert icon name to IconData
  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'local_drink':
        return Icons.local_drink;
      case 'book':
        return Icons.book;
      case 'music_note':
        return Icons.music_note;
      case 'brush':
        return Icons.brush;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'savings':
        return Icons.savings;
      case 'work':
        return Icons.work;
      case 'psychology':
        return Icons.psychology;
      case 'nature':
        return Icons.nature;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_run':
        return Icons.directions_run;
      case 'bedtime':
        return Icons.bedtime;
      case 'phone':
        return Icons.phone;
      case 'eco':
        return Icons.eco;
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

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
