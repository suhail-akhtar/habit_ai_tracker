import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import '../providers/voice_provider.dart';
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

  static String formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  // Validation Helpers
  /// Enhanced habit name validation with sanitization
  static bool isValidHabitName(String name) {
    String sanitized = sanitizeHabitName(name);
    if (sanitized.isEmpty) return false;
    if (sanitized.length < 2) return false; // Minimum length
    if (sanitized.length > Constants.maxHabitNameLength) return false;

    // Check for suspicious patterns
    if (_containsSuspiciousContent(sanitized)) return false;

    return true;
  }

  /// Comprehensive input sanitization for habit names
  static String sanitizeHabitName(String input) {
    // Remove HTML tags and script content
    String sanitized = _removeHtmlTags(input);

    // Remove or escape special characters that could be problematic
    sanitized = _removeSpecialCharacters(sanitized);

    // Normalize whitespace
    sanitized = _normalizeWhitespace(sanitized);

    // Trim and limit length
    sanitized = sanitized.trim();
    if (sanitized.length > Constants.maxHabitNameLength) {
      sanitized = sanitized.substring(0, Constants.maxHabitNameLength);
    }

    return sanitized;
  }

  /// Sanitize category names
  static String sanitizeCategory(String input) {
    String sanitized = _removeHtmlTags(input);
    sanitized = _removeSpecialCharacters(sanitized);
    sanitized = _normalizeWhitespace(sanitized);
    sanitized = sanitized.trim();

    if (sanitized.length > 30) {
      // Category length limit
      sanitized = sanitized.substring(0, 30);
    }

    return sanitized;
  }

  /// Sanitize notes and descriptions
  static String sanitizeNotes(String input) {
    String sanitized = _removeHtmlTags(input);
    sanitized = _removeSpecialCharacters(sanitized, allowPunctuation: true);
    sanitized = _normalizeWhitespace(sanitized);
    sanitized = sanitized.trim();

    if (sanitized.length > Constants.maxNoteLength) {
      sanitized = sanitized.substring(0, Constants.maxNoteLength);
    }

    return sanitized;
  }

  /// Validate category name
  static bool isValidCategory(String category) {
    String sanitized = sanitizeCategory(category);
    if (sanitized.isEmpty) return false;
    if (sanitized.length < 2) return false;
    if (sanitized.length > 30) return false;

    return !_containsSuspiciousContent(sanitized);
  }

  /// Validate notes
  static bool isValidNotes(String notes) {
    String sanitized = sanitizeNotes(notes);
    if (sanitized.length > Constants.maxNoteLength) return false;

    return !_containsSuspiciousContent(sanitized);
  }

  /// Remove HTML tags and script content
  static String _removeHtmlTags(String input) {
    // Remove script tags and their content
    String result = input.replaceAll(
      RegExp(
        r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
        caseSensitive: false,
      ),
      '',
    );

    // Remove style tags and their content
    result = result.replaceAll(
      RegExp(
        r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>',
        caseSensitive: false,
      ),
      '',
    );

    // Remove all HTML tags
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode common HTML entities
    result = result.replaceAll('&amp;', '&');
    result = result.replaceAll('&lt;', '<');
    result = result.replaceAll('&gt;', '>');
    result = result.replaceAll('&quot;', '"');
    result = result.replaceAll('&#39;', "'");
    result = result.replaceAll('&nbsp;', ' ');

    return result;
  }

  /// Remove potentially dangerous special characters
  static String _removeSpecialCharacters(
    String input, {
    bool allowPunctuation = false,
  }) {
    if (allowPunctuation) {
      // Allow basic punctuation but remove dangerous characters
      return input.replaceAll(RegExp(r'[<>{}[\]\\`|~^]'), '');
    } else {
      // Only allow alphanumeric, spaces, hyphens, underscores, and basic punctuation
      return input.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_.,!?]'), '');
    }
  }

  /// Normalize whitespace
  static String _normalizeWhitespace(String input) {
    // Replace multiple whitespaces with single space
    String result = input.replaceAll(RegExp(r'\s+'), ' ');

    // Remove leading/trailing whitespace
    return result.trim();
  }

  /// Check for suspicious content patterns
  static bool _containsSuspiciousContent(String input) {
    String lower = input.toLowerCase();

    // Check for script-like patterns
    List<String> suspiciousPatterns = [
      'javascript:',
      'data:',
      'vbscript:',
      'onclick',
      'onload',
      'onerror',
      'eval(',
      'alert(',
      'document.',
      'window.',
    ];

    return suspiciousPatterns.any((pattern) => lower.contains(pattern));
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

  /// Validate voice command input (enhanced)
  static bool isValidVoiceCommand(String input) {
    String sanitized = sanitizeNotes(
      input,
    ); // Use notes sanitization for voice input
    if (sanitized.length < 3) return false;
    if (sanitized.length > 200) return false;

    return !_containsSuspiciousContent(sanitized);
  }

  /// Extract habit name from voice text using simple NLP
  static String? extractHabitName(String voiceText, List<String> habitNames) {
    final words = voiceText.toLowerCase().split(' ');

    // Find the best matching habit name
    String? bestMatch;
    int maxMatchCount = 0;

    for (final habitName in habitNames) {
      final habitWords = habitName.toLowerCase().split(' ');
      int matchCount = 0;

      for (final habitWord in habitWords) {
        if (words.contains(habitWord)) {
          matchCount++;
        }
      }

      if (matchCount > maxMatchCount && matchCount > 0) {
        maxMatchCount = matchCount;
        bestMatch = habitName;
      }
    }

    return bestMatch;
  }

  /// Format voice feedback message
  static String formatVoiceFeedback(VoiceCommand command) {
    if (command.habitName == null && command.action != VoiceAction.reminder) {
      return 'Could not identify the habit from your voice input';
    }

    switch (command.action) {
      case VoiceAction.completed:
        return '✅ "${command.habitName}" marked as completed!';
      case VoiceAction.skipped:
        return '⏭️ "${command.habitName}" marked as skipped';
      case VoiceAction.createHabit:
        return '🆕 Habit "${command.habitName}" created successfully!';
      case VoiceAction.reminder:
        if (command.reminderMessage != null) {
          return '⏰ Voice reminder set: "${command.reminderMessage}"';
        } else {
          return '⏰ Voice reminder created successfully!';
        }
      case VoiceAction.none:
        return '❓ Unable to determine action for "${command.habitName ?? 'your request'}"';
    }
  }
}
