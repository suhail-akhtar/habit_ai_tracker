import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'theme.dart';

class Helpers {
  // Date and Time Helpers
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
  }

  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  // Color Helpers
  static Color getHabitColor(String colorCode) {
    try {
      return Color(int.parse(colorCode.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  static String colorToHex(Color color) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);

    return '#'
        '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
  }

  // Validation Helpers
  static bool isValidHabitName(String name) {
    return name.trim().isNotEmpty &&
        name.trim().length <= Constants.maxHabitNameLength;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // String Helpers
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Number Helpers
  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  static double calculatePercentage(int completed, int total) {
    if (total == 0) return 0.0;
    return (completed / total) * 100;
  }

  // Icon Helpers
  static IconData getHabitIcon(String iconName) {
    const iconMap = {
      'fitness_center': Icons.fitness_center,
      'local_drink': Icons.local_drink,
      'book': Icons.book,
      'music_note': Icons.music_note,
      'brush': Icons.brush,
      'self_improvement': Icons.self_improvement,
      'savings': Icons.savings,
      'work': Icons.work,
      'psychology': Icons.psychology,
      'nature': Icons.nature,
      'restaurant': Icons.restaurant,
      'directions_run': Icons.directions_run,
      'bedtime': Icons.bedtime,
      'phone': Icons.phone,
      'eco': Icons.eco,
    };

    return iconMap[iconName] ?? Icons.star;
  }

  // UI Helpers
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // Network Helpers
  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Device Helpers
  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Habit Helpers
  static String getStreakText(int streak) {
    if (streak == 0) return 'No streak';
    if (streak == 1) return '1 day streak';
    return '$streak days streak';
  }

  static String getCompletionRateText(double rate) {
    return '${rate.toStringAsFixed(1)}% completion rate';
  }

  static Color getStreakColor(int streak) {
    if (streak >= 30) return Colors.purple;
    if (streak >= 14) return Colors.orange;
    if (streak >= 7) return Colors.green;
    if (streak >= 3) return Colors.blue;
    return Colors.grey;
  }

  /// Get color based on confidence level
  static Color getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.6) return AppTheme.warningColor;
    if (confidence >= 0.4) return AppTheme.infoColor;
    return AppTheme.errorColor;
  }

  /// Format confidence as percentage
  static String formatConfidence(double confidence) {
    return '${(confidence * 100).toInt()}%';
  }

  /// Get confidence description
  static String getConfidenceDescription(double confidence) {
    if (confidence >= 0.9) return 'Excellent';
    if (confidence >= 0.8) return 'Very Good';
    if (confidence >= 0.7) return 'Good';
    if (confidence >= 0.6) return 'Fair';
    if (confidence >= 0.4) return 'Poor';
    return 'Very Poor';
  }

}
