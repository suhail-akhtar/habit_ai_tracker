import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/ai_insight.dart';
import '../models/user_settings.dart';
import '../models/notification_settings.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'habit_tracker.db';
  static const int _databaseVersion =
      6; // 🔔 UPDATED: Version 6 for habit-level reminders

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
        has_freeze INTEGER DEFAULT 0,
        frequency_type TEXT DEFAULT 'daily',
        interval_minutes INTEGER,
        window_start_time TEXT,
        window_end_time TEXT,
        is_reminder_enabled INTEGER DEFAULT 0,
        reminder_time TEXT,
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
        status TEXT DEFAULT 'completed',
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
      // 🔔 ADD: Freeze column for existing databases
      await db.execute(
        'ALTER TABLE habits ADD COLUMN has_freeze INTEGER DEFAULT 0',
      );
    }
    
    if (oldVersion < 4) {
      // 🔔 ADD: Status column for logs (skips/freezes)
      await db.execute(
        "ALTER TABLE habit_logs ADD COLUMN status TEXT DEFAULT 'completed'",
      );
    }

    if (oldVersion < 5) {
      // 🔔 ADD: Flexible scheduling columns
      await db.execute(
        "ALTER TABLE habits ADD COLUMN frequency_type TEXT DEFAULT 'daily'",
      );
      await db.execute(
        'ALTER TABLE habits ADD COLUMN interval_minutes INTEGER',
      );
      await db.execute(
        'ALTER TABLE habits ADD COLUMN window_start_time TEXT',
      );
      await db.execute(
        'ALTER TABLE habits ADD COLUMN window_end_time TEXT',
      );
    }
    
    if (oldVersion < 6) {
      // 🔔 ADD: Reminder settings for habits
      await db.execute(
        'ALTER TABLE habits ADD COLUMN is_reminder_enabled INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE habits ADD COLUMN reminder_time TEXT',
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

  Future<Map<DateTime, int>> getHeatmapData() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DATE(completed_at) as date, COUNT(*) as count 
      FROM habit_logs 
      GROUP BY DATE(completed_at)
    ''');

    final Map<DateTime, int> heatmapData = {};
    for (var row in result) {
      final dateStr = row['date'] as String;
      final count = row['count'] as int;
      final date = DateTime.parse(dateStr);
      // Normalized date (strip time)
      heatmapData[DateTime(date.year, date.month, date.day)] = count;
    }
    return heatmapData;
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

    // 0. Get Habit Target
    final habitResult = await db.query(
      'habits',
      columns: ['target_frequency'],
      where: 'id = ?',
      whereArgs: [habitId],
    );
    if (habitResult.isEmpty) return 0;
    final target = (habitResult.first['target_frequency'] as int?) ?? 1;

    // 1. Fetch all logs sorted by date DESC
    final result = await db.query(
      'habit_logs',
      columns: ['completed_at', 'status'],
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'completed_at DESC',
    );

    if (result.isEmpty) return 0;

    // 2. Process logs into a Date -> Count/Status map
    final Map<String, int> dailyCount = {};
    final Map<String, String> dailyStatus = {};
    
    for (var row in result) {
      final dateStr = (row['completed_at'] as String).substring(0, 10);
      final status = (row['status'] as String?) ?? 'completed';
      
      if (status == 'completed') {
        dailyCount[dateStr] = (dailyCount[dateStr] ?? 0) + 1;
      } else if (status == 'skipped') {
        // If ANY skip exists for the day, we mark day as skipped (frozen)
        dailyStatus[dateStr] = 'skipped'; 
      }
    }

    // 3. Calculate Streak
    int streak = 0;
    final now = DateTime.now();
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    
    // Check if we have an entry for Today
    final todayKey = checkDate.toIso8601String().substring(0, 10);
    final todayCount = dailyCount[todayKey] ?? 0;
    final todayStatus = dailyStatus[todayKey];
    
    // If today is NOT met (count < target) AND NOT skipped, we don't count it,
    // BUT we also don't break streak yet (user has time left).
    // So we start checking from Yesterday.
    // UNLESS user has ALREADY met the target today, then we count it.
    
    bool countToday = false;
    if (todayStatus == 'skipped') {
       // Skipped today -> streak frozen, don't increment, start check from yesterday
       checkDate = checkDate.subtract(const Duration(days: 1));
    } else if (todayCount >= target) {
      // Completed today -> increment streak, start check from yesterday (handled in loop)
      countToday = true;
    } else {
      // Incomplete today -> ignore today, start check from yesterday
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Loop logic
    if (countToday) {
       streak++;
       checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Iterate backwards
    while (true) {
      final checkKey = checkDate.toIso8601String().substring(0, 10);
      
      final count = dailyCount[checkKey] ?? 0;
      final status = dailyStatus[checkKey];

      if (status == 'skipped') {
         // Skip maintains the streak but does not increment it
      } else if (count >= target) {
         streak++;
      } else {
         // Target not met and not skipped -> Break
         break;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
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
}
