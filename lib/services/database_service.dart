import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/ai_insight.dart';
import '../models/user_settings.dart';
import '../models/notification_settings.dart';
import '../models/voice_reminder.dart';
import '../models/custom_habit_category.dart';
import '../models/analytics_models.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'habit_tracker.db';
  static const int _databaseVersion =
      4; // 🔔 UPDATED: Version 4 for custom categories

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        target_frequency INTEGER DEFAULT 1,
        color_code TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        note TEXT,
        input_method TEXT NOT NULL,
        mood_rating INTEGER,
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_insights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        insight_type TEXT NOT NULL,
        content TEXT NOT NULL,
        data_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 🔔 NEW: Notification settings table
    await db.execute('''
      CREATE TABLE notification_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        time_hour INTEGER NOT NULL,
        time_minute INTEGER NOT NULL,
        days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
        type TEXT DEFAULT 'simple',
        repetition TEXT DEFAULT 'daily',
        is_enabled INTEGER DEFAULT 1,
        habit_ids TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_scheduled_time TEXT
      )
    ''');

    // 🎤 NEW: Voice reminders table
    await db.execute('''
      CREATE TABLE voice_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL,
        reminder_time TEXT NOT NULL,
        habit_ids TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 🎨 NEW: Custom habit categories table
    await db.execute('''
      CREATE TABLE custom_habit_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon_name TEXT NOT NULL,
        color_code TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute(
      'CREATE INDEX idx_habit_logs_habit_id ON habit_logs(habit_id)',
    );
    await db.execute(
      'CREATE INDEX idx_habit_logs_completed_at ON habit_logs(completed_at)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_insights_user_id ON ai_insights(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_insights_expires_at ON ai_insights(expires_at)',
    );
    await db.execute(
      'CREATE INDEX idx_notification_settings_enabled ON notification_settings(is_enabled)',
    ); // 🔔 NEW
    await db.execute(
      'CREATE INDEX idx_voice_reminders_active ON voice_reminders(is_active)',
    ); // 🎤 NEW
    await db.execute(
      'CREATE INDEX idx_voice_reminders_time ON voice_reminders(reminder_time)',
    ); // 🎤 NEW
    await db.execute(
      'CREATE INDEX idx_custom_categories_name ON custom_habit_categories(name)',
    ); // 🎨 NEW
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 🔔 ADD: Notification settings table for existing databases
      await db.execute('''
        CREATE TABLE notification_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          time_hour INTEGER NOT NULL,
          time_minute INTEGER NOT NULL,
          days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
          type TEXT DEFAULT 'simple',
          repetition TEXT DEFAULT 'daily',
          is_enabled INTEGER DEFAULT 1,
          habit_ids TEXT DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          next_scheduled_time TEXT
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_notification_settings_enabled ON notification_settings(is_enabled)',
      );
    }

    if (oldVersion < 3) {
      // 🎤 ADD: Voice reminders table for existing databases
      await db.execute('''
        CREATE TABLE voice_reminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message TEXT NOT NULL,
          reminder_time TEXT NOT NULL,
          habit_ids TEXT DEFAULT '',
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_voice_reminders_active ON voice_reminders(is_active)',
      );
      await db.execute(
        'CREATE INDEX idx_voice_reminders_time ON voice_reminders(reminder_time)',
      );
    }

    if (oldVersion < 4) {
      // 🎨 ADD: Custom habit categories table for existing databases
      await db.execute('''
        CREATE TABLE custom_habit_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          icon_name TEXT NOT NULL,
          color_code TEXT NOT NULL,
          is_default INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_custom_categories_name ON custom_habit_categories(name)',
      );
    }
  }

  // Habit CRUD operations (existing - unchanged)
  Future<int> createHabit(Habit habit) async {
    final db = await database;
    return await db.insert('habits', habit.toMap());
  }

  Future<List<Habit>> getActiveHabits() async {
    final db = await database;
    final result = await db.query(
      'habits',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Habit.fromMap(map)).toList();
  }

  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final result = await db.query('habits', orderBy: 'created_at DESC');
    return result.map((map) => Habit.fromMap(map)).toList();
  }

  Future<Habit?> getHabit(int id) async {
    final db = await database;
    final result = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? Habit.fromMap(result.first) : null;
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await database;
    return await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // Habit log operations (existing - unchanged)
  Future<int> logHabit(HabitLog habitLog) async {
    final db = await database;
    return await db.insert('habit_logs', habitLog.toMap());
  }

  Future<List<HabitLog>> getHabitLogs(int habitId, {int? limit}) async {
    final db = await database;
    final result = await db.query(
      'habit_logs',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return result.map((map) => HabitLog.fromMap(map)).toList();
  }

  Future<List<HabitLog>> getLogsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      'habit_logs',
      where: 'completed_at BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'completed_at DESC',
    );
    return result.map((map) => HabitLog.fromMap(map)).toList();
  }

  Future<int> getHabitStreak(int habitId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as streak FROM (
        SELECT DATE(completed_at) as log_date 
        FROM habit_logs 
        WHERE habit_id = ? 
        GROUP BY DATE(completed_at)
        ORDER BY log_date DESC
      ) WHERE log_date >= DATE('now', '-' || (
        SELECT COUNT(*) FROM (
          SELECT DATE(completed_at) as log_date 
          FROM habit_logs 
          WHERE habit_id = ? 
          GROUP BY DATE(completed_at)
          ORDER BY log_date DESC
        )
      ) || ' days')
    ''',
      [habitId, habitId],
    );

    return result.first['streak'] as int;
  }

  // 🔔 NEW: Notification settings CRUD operations
  Future<int> createNotificationSetting(
    NotificationSettings notification,
  ) async {
    final db = await database;
    return await db.insert('notification_settings', notification.toMap());
  }

  Future<List<NotificationSettings>> getNotificationSettings({
    bool enabledOnly = false,
  }) async {
    final db = await database;
    final result = await db.query(
      'notification_settings',
      where: enabledOnly ? 'is_enabled = ?' : null,
      whereArgs: enabledOnly ? [1] : null,
      orderBy: 'created_at DESC',
    );
    return result.map((map) => NotificationSettings.fromMap(map)).toList();
  }

  Future<NotificationSettings?> getNotificationSetting(int id) async {
    final db = await database;
    final result = await db.query(
      'notification_settings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty
        ? NotificationSettings.fromMap(result.first)
        : null;
  }

  Future<int> updateNotificationSetting(
    NotificationSettings notification,
  ) async {
    final db = await database;
    return await db.update(
      'notification_settings',
      notification.toMap(),
      where: 'id = ?',
      whereArgs: [notification.id],
    );
  }

  Future<int> deleteNotificationSetting(int id) async {
    final db = await database;
    return await db.delete(
      'notification_settings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getNotificationCount({bool enabledOnly = false}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notification_settings${enabledOnly ? ' WHERE is_enabled = 1' : ''}',
    );
    return result.first['count'] as int;
  }

  // AI insights operations (existing - unchanged)
  Future<int> saveAIInsight(AIInsight insight) async {
    final db = await database;
    return await db.insert('ai_insights', insight.toMap());
  }

  Future<AIInsight?> getAIInsight(String userId, String insightType) async {
    final db = await database;
    final result = await db.query(
      'ai_insights',
      where: 'user_id = ? AND insight_type = ? AND expires_at > ?',
      whereArgs: [userId, insightType, DateTime.now().toIso8601String()],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return result.isNotEmpty ? AIInsight.fromMap(result.first) : null;
  }

  Future<int> deleteExpiredInsights() async {
    final db = await database;
    return await db.delete(
      'ai_insights',
      where: 'expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  // User settings operations (existing - unchanged)
  Future<int> saveSetting(UserSettings setting) async {
    final db = await database;
    return await db.insert(
      'user_settings',
      setting.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserSettings?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return result.isNotEmpty ? UserSettings.fromMap(result.first) : null;
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final db = await database;

    // Get total habits
    final totalHabitsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM habits WHERE is_active = 1',
    );
    final totalHabits = totalHabitsResult.first['count'] as int;

    // Get total logs
    final totalLogsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM habit_logs',
    );
    final totalLogs = totalLogsResult.first['count'] as int;

    // Get logs for last 7 days
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
    final recentLogsResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM habit_logs 
      WHERE completed_at >= ?
    ''',
      [sevenDaysAgo.toIso8601String()],
    );
    final recentLogs = recentLogsResult.first['count'] as int;

    // Get best streak
    final bestStreakResult = await db.rawQuery('''
      SELECT MAX(streak) as max_streak FROM (
        SELECT COUNT(*) as streak FROM (
          SELECT habit_id, DATE(completed_at) as log_date 
          FROM habit_logs 
          GROUP BY habit_id, DATE(completed_at)
          ORDER BY habit_id, log_date
        ) GROUP BY habit_id
      )
    ''');
    final bestStreak = bestStreakResult.first['max_streak'] as int? ?? 0;

    return {
      'totalHabits': totalHabits,
      'totalLogs': totalLogs,
      'recentLogs': recentLogs,
      'bestStreak': bestStreak,
      'completionRate': totalHabits > 0
          ? (recentLogs / (totalHabits * 7) * 100).round()
          : 0,
    };
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // 🎤 Voice Reminder CRUD operations
  Future<int?> insertVoiceReminder(VoiceReminder reminder) async {
    try {
      final db = await database;
      return await db.insert('voice_reminders', reminder.toMap());
    } catch (e) {
      print('Error inserting voice reminder: $e');
      return null;
    }
  }

  Future<List<VoiceReminder>> getVoiceReminders() async {
    final db = await database;
    final result = await db.query(
      'voice_reminders',
      orderBy: 'reminder_time ASC',
    );
    return result.map((map) => VoiceReminder.fromMap(map)).toList();
  }

  Future<VoiceReminder?> getVoiceReminder(int id) async {
    final db = await database;
    final result = await db.query(
      'voice_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? VoiceReminder.fromMap(result.first) : null;
  }

  Future<void> updateVoiceReminder(VoiceReminder reminder) async {
    final db = await database;
    await db.update(
      'voice_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> deleteVoiceReminder(int id) async {
    final db = await database;
    await db.delete('voice_reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<VoiceReminder>> getActiveVoiceReminders() async {
    final db = await database;
    final result = await db.query(
      'voice_reminders',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'reminder_time ASC',
    );
    return result.map((map) => VoiceReminder.fromMap(map)).toList();
  }

  // 🎨 Custom Habit Categories CRUD operations
  Future<int?> insertCustomCategory(CustomHabitCategory category) async {
    try {
      final db = await database;
      return await db.insert('custom_habit_categories', category.toMap());
    } catch (e) {
      print('Error inserting custom category: $e');
      return null;
    }
  }

  Future<List<CustomHabitCategory>> getCustomCategories() async {
    final db = await database;
    final result = await db.query(
      'custom_habit_categories',
      orderBy: 'created_at ASC',
    );
    return result.map((map) => CustomHabitCategory.fromMap(map)).toList();
  }

  Future<CustomHabitCategory?> getCustomCategory(int id) async {
    final db = await database;
    final result = await db.query(
      'custom_habit_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? CustomHabitCategory.fromMap(result.first) : null;
  }

  Future<void> updateCustomCategory(CustomHabitCategory category) async {
    final db = await database;
    await db.update(
      'custom_habit_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCustomCategory(int id) async {
    final db = await database;
    await db.delete(
      'custom_habit_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isCategoryInUse(int categoryId) async {
    final db = await database;

    // First get the category name
    final categoryResult = await db.query(
      'custom_habit_categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    );

    if (categoryResult.isEmpty) return false;

    final categoryName = categoryResult.first['name'] as String;

    // Check if any habits use this category
    final habitResult = await db.query(
      'habits',
      where: 'category = ? AND is_active = 1',
      whereArgs: [categoryName],
    );

    return habitResult.isNotEmpty;
  }

  // ============ ANALYTICS METHODS ============

  /// Get heatmap data for the specified date range
  Future<List<HeatmapData>> getHeatmapData(DateTime start, DateTime end) async {
    final db = await database;

    final startStr = start.toIso8601String().split('T')[0];
    final endStr = end.toIso8601String().split('T')[0];

    final result = await db.rawQuery(
      '''
      SELECT 
        DATE(hl.completed_at) as date,
        COUNT(DISTINCT hl.habit_id) as completed_habits,
        COUNT(DISTINCT h.id) as total_habits,
        CAST(COUNT(DISTINCT hl.habit_id) AS REAL) / COUNT(DISTINCT h.id) as completion_rate
      FROM habits h
      LEFT JOIN habit_logs hl ON h.id = hl.habit_id 
        AND DATE(hl.completed_at) >= ? 
        AND DATE(hl.completed_at) <= ?
      WHERE h.is_active = 1
      GROUP BY DATE(hl.completed_at)
      ORDER BY date
    ''',
      [startStr, endStr],
    );

    return result
        .map((row) {
          final dateStr = row['date'] as String?;
          if (dateStr == null) return null;

          return HeatmapData(
            date: DateTime.parse(dateStr),
            completedHabits: (row['completed_habits'] as int?) ?? 0,
            totalHabits: (row['total_habits'] as int?) ?? 0,
            completionRate: (row['completion_rate'] as double?) ?? 0.0,
          );
        })
        .where((data) => data != null)
        .cast<HeatmapData>()
        .toList();
  }

  /// Get recent habit completion data
  Future<Map<String, dynamic>> getRecentHabitData({
    required int days,
    required List<Habit> habits,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));
    final startStr = startDate.toIso8601String().split('T')[0];

    final result = await db.rawQuery(
      '''
      SELECT 
        h.id,
        h.name,
        h.category,
        COUNT(hl.id) as completions,
        COUNT(DISTINCT DATE(hl.completed_at)) as unique_days
      FROM habits h
      LEFT JOIN habit_logs hl ON h.id = hl.habit_id 
        AND DATE(hl.completed_at) >= ?
      WHERE h.is_active = 1
      GROUP BY h.id, h.name, h.category
    ''',
      [startStr],
    );

    return {'habits': result, 'period_days': days, 'start_date': startStr};
  }

  /// Get weekly completion statistics for a habit
  Future<Map<int, double>> getWeeklyCompletionStats(int habitId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT 
        CAST(strftime('%w', completed_at) AS INTEGER) as day_of_week,
        COUNT(*) as completions,
        COUNT(DISTINCT DATE(completed_at)) as total_days
      FROM habit_logs 
      WHERE habit_id = ?
        AND completed_at >= date('now', '-90 days')
      GROUP BY day_of_week
    ''',
      [habitId],
    );

    final stats = <int, double>{};

    for (final row in result) {
      final dayOfWeek = (row['day_of_week'] as int?) ?? 0;
      final completions = (row['completions'] as int?) ?? 0;
      final totalDays = (row['total_days'] as int?) ?? 1;

      // Convert Sunday (0) to 7 for Monday-first week
      final adjustedDay = dayOfWeek == 0 ? 7 : dayOfWeek;
      stats[adjustedDay] = completions / totalDays;
    }

    return stats;
  }

  /// Get hourly completion statistics for a habit
  Future<Map<int, double>> getHourlyCompletionStats(int habitId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT 
        CAST(strftime('%H', completed_at) AS INTEGER) as hour,
        COUNT(*) as completions
      FROM habit_logs 
      WHERE habit_id = ?
        AND completed_at >= date('now', '-90 days')
      GROUP BY hour
    ''',
      [habitId],
    );

    final stats = <int, double>{};
    final totalCompletions = result.fold<int>(
      0,
      (sum, row) => sum + ((row['completions'] as int?) ?? 0),
    );

    for (final row in result) {
      final hour = (row['hour'] as int?) ?? 0;
      final completions = (row['completions'] as int?) ?? 0;

      stats[hour] = totalCompletions > 0 ? completions / totalCompletions : 0.0;
    }

    return stats;
  }

  /// Get streak analysis for a habit
  Future<Map<String, dynamic>> getStreakAnalysis(int habitId) async {
    final db = await database;

    // Get all completion dates for the habit
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT DATE(completed_at) as date
      FROM habit_logs 
      WHERE habit_id = ?
      ORDER BY date
    ''',
      [habitId],
    );

    if (result.isEmpty) {
      return {'average_streak': 0.0, 'longest_streak': 0, 'consistency': 0.0};
    }

    final dates = result
        .map((row) => DateTime.parse(row['date'] as String))
        .toList();

    // Calculate streaks
    final streaks = <int>[];
    int currentStreak = 1;

    for (int i = 1; i < dates.length; i++) {
      final daysDiff = dates[i].difference(dates[i - 1]).inDays;

      if (daysDiff == 1) {
        currentStreak++;
      } else {
        streaks.add(currentStreak);
        currentStreak = 1;
      }
    }
    streaks.add(currentStreak);

    final averageStreak = streaks.isNotEmpty
        ? streaks.reduce((a, b) => a + b) / streaks.length
        : 0.0;
    final longestStreak = streaks.isNotEmpty
        ? streaks.reduce((a, b) => a > b ? a : b)
        : 0;

    // Calculate consistency (completions vs expected days)
    final daysSinceFirst = DateTime.now().difference(dates.first).inDays + 1;
    final consistency = dates.length / daysSinceFirst;

    return {
      'average_streak': averageStreak,
      'longest_streak': longestStreak,
      'consistency': consistency.clamp(0.0, 1.0),
    };
  }
}
