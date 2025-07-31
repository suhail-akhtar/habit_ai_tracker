import 'package:shared_preferences/shared_preferences.dart';

/// 🧠 AI Message Cache Service
/// Manages caching of AI-generated messages to reduce API calls
/// Cache duration: 5 hours per message
class AICacheService {
  static const int _cacheDurationMs =
      5 * 60 * 60 * 1000; // 5 hours in milliseconds

  /// Get cached AI motivation message for a habit and streak
  static Future<String?> getCachedMotivation(int habitId, int streak) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'ai_motivation_${habitId}_$streak';
      final timestampKey = 'ai_motivation_timestamp_${habitId}_$streak';

      final cachedMessage = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt(timestampKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedMessage != null &&
          cachedTimestamp != null &&
          (now - cachedTimestamp) < _cacheDurationMs) {
        print(
          '🧠 Cache HIT: AI motivation for habit $habitId (streak: $streak)',
        );
        return cachedMessage;
      }

      print(
        '🧠 Cache MISS: AI motivation for habit $habitId (streak: $streak)',
      );
      return null;
    } catch (e) {
      print('❌ Failed to get cached motivation: $e');
      return null;
    }
  }

  /// Cache AI motivation message for a habit and streak
  static Future<void> cacheMotivation(
    int habitId,
    int streak,
    String message,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'ai_motivation_${habitId}_$streak';
      final timestampKey = 'ai_motivation_timestamp_${habitId}_$streak';
      final now = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString(cacheKey, message);
      await prefs.setInt(timestampKey, now);

      print('🧠 Cached AI motivation for habit $habitId (streak: $streak)');
    } catch (e) {
      print('❌ Failed to cache motivation: $e');
    }
  }

  /// Invalidate all cached messages for a specific habit
  static Future<void> invalidateHabitCache(int habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Remove all cache entries for this habit
      final keysToRemove = keys
          .where(
            (key) =>
                key.startsWith('ai_motivation_$habitId') ||
                key.startsWith('ai_motivation_timestamp_$habitId'),
          )
          .toList();

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      print(
        '🧠 Invalidated AI cache for habit $habitId (${keysToRemove.length} entries)',
      );
    } catch (e) {
      print('❌ Failed to invalidate habit cache: $e');
    }
  }

  /// Clear all AI cache entries
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      final aiKeys = keys
          .where(
            (key) =>
                key.startsWith('ai_motivation_') ||
                key.startsWith('ai_motivation_timestamp_'),
          )
          .toList();

      for (final key in aiKeys) {
        await prefs.remove(key);
      }

      print('🧠 Cleared all AI cache (${aiKeys.length} entries)');
    } catch (e) {
      print('❌ Failed to clear all AI cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, int>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      final messageKeys = keys
          .where(
            (key) =>
                key.startsWith('ai_motivation_') && !key.contains('timestamp'),
          )
          .toList();
      final timestampKeys = keys
          .where((key) => key.startsWith('ai_motivation_timestamp_'))
          .toList();

      int validEntries = 0;
      int expiredEntries = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final timestampKey in timestampKeys) {
        final timestamp = prefs.getInt(timestampKey);
        if (timestamp != null) {
          if ((now - timestamp) < _cacheDurationMs) {
            validEntries++;
          } else {
            expiredEntries++;
          }
        }
      }

      return {
        'total': messageKeys.length,
        'valid': validEntries,
        'expired': expiredEntries,
      };
    } catch (e) {
      print('❌ Failed to get cache stats: $e');
      return {'total': 0, 'valid': 0, 'expired': 0};
    }
  }
}
