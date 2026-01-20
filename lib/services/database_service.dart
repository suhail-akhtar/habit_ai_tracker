import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/user_settings.dart';
import '../models/notification_settings.dart';
import '../models/habit_report.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'habit_tracker.db';
  static const int _databaseVersion =
  8; // 🎯 UPDATED: Version 8 for goals + tags

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
        schedule_days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
        start_date TEXT,
        frequency_type TEXT DEFAULT 'daily',
        interval_minutes INTEGER,
        window_start_time TEXT,
        window_end_time TEXT,
        is_reminder_enabled INTEGER DEFAULT 0,
        reminder_time TEXT,
        goal_type TEXT DEFAULT 'streak',
        goal_target INTEGER,
        tags TEXT DEFAULT '',
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

    if (oldVersion < 7) {
      // 📅 ADD: Schedule days + start date
      await db.execute(
        "ALTER TABLE habits ADD COLUMN schedule_days_of_week TEXT DEFAULT '1,2,3,4,5,6,7'",
      );
      await db.execute(
        'ALTER TABLE habits ADD COLUMN start_date TEXT',
      );
    }

    if (oldVersion < 8) {
      // 🎯 ADD: Goals + tags
      await db.execute(
        "ALTER TABLE habits ADD COLUMN goal_type TEXT DEFAULT 'streak'",
      );
      await db.execute(
        'ALTER TABLE habits ADD COLUMN goal_target INTEGER',
      );
      await db.execute(
        "ALTER TABLE habits ADD COLUMN tags TEXT DEFAULT ''",
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
      columns: ['target_frequency', 'schedule_days_of_week', 'start_date'],
      where: 'id = ?',
      whereArgs: [habitId],
    );
    if (habitResult.isEmpty) return 0;
    final target = (habitResult.first['target_frequency'] as int?) ?? 1;

    final scheduleStr =
      (habitResult.first['schedule_days_of_week'] as String?) ??
        '1,2,3,4,5,6,7';
    final scheduledDays = scheduleStr
      .split(',')
      .where((s) => s.trim().isNotEmpty)
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toSet();
    // Default to every day if malformed/empty.
    final normalizedScheduledDays = scheduledDays.isEmpty
      ? {1, 2, 3, 4, 5, 6, 7}
      : scheduledDays;

    final startDateRaw = habitResult.first['start_date'] as String?;
    final startDate = (startDateRaw != null && startDateRaw.isNotEmpty)
      ? DateTime.tryParse(startDateRaw)
      : null;
    final startDay = startDate == null
      ? null
      : DateTime(startDate.year, startDate.month, startDate.day);

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

    bool isRestDay(DateTime d) =>
      !normalizedScheduledDays.contains(d.weekday);
    
    // Check if we have an entry for Today
    final todayKey = checkDate.toIso8601String().substring(0, 10);
    final todayCount = dailyCount[todayKey] ?? 0;
    final todayStatus = dailyStatus[todayKey];
    
    // If today is NOT met (count < target) AND NOT skipped, we don't count it,
    // BUT we also don't break streak yet (user has time left).
    // So we start checking from Yesterday.
    // UNLESS user has ALREADY met the target today, then we count it.
    
    bool countToday = false;
    if (startDay != null && checkDate.isBefore(startDay)) {
      return 0;
    }

    if (isRestDay(checkDate)) {
      // Rest day: doesn't increment, doesn't break.
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else if (todayStatus == 'skipped') {
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
      if (startDay != null && checkDate.isBefore(startDay)) {
        break;
      }

      if (isRestDay(checkDate)) {
        // Rest day: doesn't increment, doesn't break.
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

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

  Future<int> getHabitBestStreak(int habitId) async {
    final db = await database;

    final habitResult = await db.query(
      'habits',
      columns: ['target_frequency', 'schedule_days_of_week', 'start_date'],
      where: 'id = ?',
      whereArgs: [habitId],
    );
    if (habitResult.isEmpty) return 0;

    final target = (habitResult.first['target_frequency'] as int?) ?? 1;

    final scheduleStr =
        (habitResult.first['schedule_days_of_week'] as String?) ??
        '1,2,3,4,5,6,7';
    final scheduledDays = scheduleStr
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
    final normalizedScheduledDays = scheduledDays.isEmpty
        ? {1, 2, 3, 4, 5, 6, 7}
        : scheduledDays;

    final startDateRaw = habitResult.first['start_date'] as String?;
    final startDate = (startDateRaw != null && startDateRaw.isNotEmpty)
        ? DateTime.tryParse(startDateRaw)
        : null;
    final startDay = startDate == null
        ? null
        : DateTime(startDate.year, startDate.month, startDate.day);

    final rows = await db.query(
      'habit_logs',
      columns: ['completed_at', 'status'],
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'completed_at ASC',
    );
    if (rows.isEmpty) return 0;

    final Map<String, int> dailyCount = {};
    final Map<String, String> dailyStatus = {};
    DateTime? firstLogDay;
    for (final row in rows) {
      final completedAt = DateTime.tryParse(row['completed_at'] as String);
      if (completedAt == null) continue;
      final dateStr = completedAt.toIso8601String().substring(0, 10);
      final status = (row['status'] as String?) ?? 'completed';

      firstLogDay ??= DateTime(completedAt.year, completedAt.month, completedAt.day);

      if (status == 'completed') {
        dailyCount[dateStr] = (dailyCount[dateStr] ?? 0) + 1;
      } else if (status == 'skipped') {
        dailyStatus[dateStr] = 'skipped';
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final effectiveStart = () {
      final a = startDay;
      final b = firstLogDay;
      if (a == null) return b ?? today;
      if (b == null) return a;
      return a.isAfter(b) ? a : b;
    }();

    bool isDueDay(DateTime d) {
      if (startDay != null && d.isBefore(startDay)) return false;
      return normalizedScheduledDays.contains(d.weekday);
    }

    int best = 0;
    int current = 0;

    for (
      DateTime d = effectiveStart;
      !d.isAfter(today);
      d = d.add(const Duration(days: 1))
    ) {
      if (!isDueDay(d)) continue;

      final key = d.toIso8601String().substring(0, 10);
      final count = dailyCount[key] ?? 0;
      final status = dailyStatus[key];

      if (status == 'skipped') {
        // Frozen day: doesn't increment, doesn't break.
      } else if (count >= target) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }

    return best;
  }

  Future<HabitReport?> getHabitReport(int habitId, {int days = 30}) async {
    final habit = await getHabit(habitId);
    if (habit == null) return null;

    final db = await database;
    final now = DateTime.now();
    final rangeEnd = DateTime(now.year, now.month, now.day);
    final rangeStart = rangeEnd.subtract(Duration(days: days - 1));

    final startOfRange = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final endOfRange = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day, 23, 59, 59, 999);

    final rows = await db.rawQuery(
      '''
      SELECT DATE(completed_at) as day,
             SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
             MAX(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) as skipped_flag
      FROM habit_logs
      WHERE habit_id = ?
        AND completed_at BETWEEN ? AND ?
      GROUP BY DATE(completed_at)
    ''',
      [habitId, startOfRange.toIso8601String(), endOfRange.toIso8601String()],
    );

    final Map<String, int> completedCountByDay = {
      for (final row in rows)
        (row['day'] as String): (row['completed_count'] as int? ?? 0),
    };
    final Set<String> skippedDays = {
      for (final row in rows)
        if ((row['skipped_flag'] as int? ?? 0) > 0) (row['day'] as String),
    };

    final scheduleDays = habit.scheduleDaysOfWeek.isEmpty
        ? const [1, 2, 3, 4, 5, 6, 7]
        : habit.scheduleDaysOfWeek;
    final scheduleSet = scheduleDays.toSet();
    final startDate = habit.startDate;
    final startDay = startDate == null
        ? null
        : DateTime(startDate.year, startDate.month, startDate.day);

    bool isDueDay(DateTime d) {
      if (startDay != null && d.isBefore(startDay)) return false;
      return scheduleSet.contains(d.weekday);
    }

    final target = habit.targetFrequency <= 0 ? 1 : habit.targetFrequency;

    final daySummaries = <HabitDaySummary>[];
    int dueDaysCount = 0;
    int completedDaysCount = 0;
    int skippedDaysCount = 0;
    int missedDaysCount = 0;

    for (
      DateTime d = startOfRange;
      !d.isAfter(rangeEnd);
      d = d.add(const Duration(days: 1))
    ) {
      final due = isDueDay(d);
      final key = d.toIso8601String().substring(0, 10);
      final completedCount = completedCountByDay[key] ?? 0;
      final skipped = skippedDays.contains(key);
      final met = completedCount >= target;

      if (due) {
        dueDaysCount++;
        if (skipped) {
          skippedDaysCount++;
        } else if (met) {
          completedDaysCount++;
        } else {
          missedDaysCount++;
        }
      }

      daySummaries.add(
        HabitDaySummary(
          date: d,
          isDue: due,
          completedCount: completedCount,
          isSkipped: skipped,
          isTargetMet: met,
        ),
      );
    }

    final totalCompletionsResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM habit_logs WHERE habit_id = ? AND status = 'completed'",
      [habitId],
    );
    final totalCompletions = totalCompletionsResult.first['c'] as int? ?? 0;

    final lastCompletedResult = await db.rawQuery(
      "SELECT completed_at as t FROM habit_logs WHERE habit_id = ? AND status = 'completed' ORDER BY completed_at DESC LIMIT 1",
      [habitId],
    );
    final lastCompletedAt = lastCompletedResult.isNotEmpty
        ? DateTime.tryParse(lastCompletedResult.first['t'] as String)
        : null;

    final currentStreak = await getHabitStreak(habitId);
    final bestStreak = await getHabitBestStreak(habitId);

    return HabitReport(
      habitId: habitId,
      rangeStart: startOfRange,
      rangeEnd: rangeEnd,
      dueDays: dueDaysCount,
      completedDays: completedDaysCount,
      skippedDays: skippedDaysCount,
      missedDays: missedDaysCount,
      totalCompletions: totalCompletions,
      lastCompletedAt: lastCompletedAt,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      days: daySummaries,
    );
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

  Future<int> getBestStreakAcrossActiveHabits() async {
    final db = await database;

    final habitIdRows = await db.query(
      'habits',
      columns: ['id'],
      where: 'is_active = 1',
    );

    int best = 0;
    for (final row in habitIdRows) {
      final habitId = row['id'] as int?;
      if (habitId == null) continue;
      final streak = await getHabitStreak(habitId);
      if (streak > best) best = streak;
    }
    return best;
  }

  Future<List<Map<String, dynamic>>> getWeeklyProgress({int days = 7}) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final start = today.subtract(Duration(days: days - 1));
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    final totalHabitsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM habits WHERE is_active = 1',
    );
    final totalHabits = totalHabitsResult.first['count'] as int;

    final rows = await db.rawQuery(
      '''
      SELECT DATE(completed_at) as day, COUNT(DISTINCT habit_id) as completed_count
      FROM habit_logs
      WHERE status = 'completed'
        AND completed_at BETWEEN ? AND ?
      GROUP BY DATE(completed_at)
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final Map<String, int> completedByDay = {
      for (final row in rows)
        (row['day'] as String): (row['completed_count'] as int? ?? 0),
    };

    return List.generate(days, (i) {
      final date = start.add(Duration(days: i));
      final key = date.toIso8601String().substring(0, 10);
      return {
        'date': date,
        'completedHabits': completedByDay[key] ?? 0,
        'totalHabits': totalHabits,
      };
    });
  }

  Future<List<Map<String, dynamic>>> getProgressSeries({
    required String range,
  }) async {
    if (range == 'year') {
      return _getMonthlyProgressSeries(months: 12);
    }

    final days = range == 'month' ? 30 : 7;
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    final totalHabitsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM habits WHERE is_active = 1',
    );
    final totalHabits = totalHabitsResult.first['count'] as int;

    final rows = await db.rawQuery(
      '''
      SELECT DATE(completed_at) as day, COUNT(DISTINCT habit_id) as completed_count
      FROM habit_logs
      WHERE status = 'completed'
        AND completed_at BETWEEN ? AND ?
      GROUP BY DATE(completed_at)
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final Map<String, int> completedByDay = {
      for (final row in rows)
        (row['day'] as String): (row['completed_count'] as int? ?? 0),
    };

    return List.generate(days, (i) {
      final date = start.add(Duration(days: i));
      final key = date.toIso8601String().substring(0, 10);
      return {
        'date': date,
        'label': date.day.toString(),
        'completedHabits': completedByDay[key] ?? 0,
        'totalHabits': totalHabits,
      };
    });
  }

  Future<List<Map<String, dynamic>>> _getMonthlyProgressSeries({
    int months = 12,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final start = _shiftMonths(currentMonthStart, -(months - 1));
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final totalHabitsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM habits WHERE is_active = 1',
    );
    final totalHabits = totalHabitsResult.first['count'] as int;

    final rows = await db.rawQuery(
      '''
      SELECT STRFTIME('%Y-%m', completed_at) as ym, COUNT(DISTINCT habit_id) as completed_count
      FROM habit_logs
      WHERE status = 'completed'
        AND completed_at BETWEEN ? AND ?
      GROUP BY STRFTIME('%Y-%m', completed_at)
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final Map<String, int> completedByMonth = {
      for (final row in rows)
        (row['ym'] as String): (row['completed_count'] as int? ?? 0),
    };

    return List.generate(months, (i) {
      final date = _shiftMonths(start, i);
      final key = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
      return {
        'date': date,
        'label': _monthLabel(date.month),
        'completedHabits': completedByMonth[key] ?? 0,
        'totalHabits': totalHabits,
      };
    });
  }

  Future<Map<String, dynamic>> getRangeSummary({
    required String range,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final days = range == 'month'
        ? 30
        : range == 'year'
            ? 365
            : 7;

    final start = today.subtract(Duration(days: days - 1));
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    final totalHabitsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM habits WHERE is_active = 1',
    );
    final totalHabits = totalHabitsResult.first['count'] as int;

    final completionsResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE status = 'completed' AND completed_at BETWEEN ? AND ?",
      [start.toIso8601String(), end.toIso8601String()],
    );
    final completions = completionsResult.first['count'] as int;

    final completionRate = await _getCompletionRate(
      start: start,
      end: end,
      totalHabits: totalHabits,
    );

    final prevEnd = start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: days - 1));

    final previousRate = await _getCompletionRate(
      start: prevStart,
      end: prevEnd,
      totalHabits: totalHabits,
    );

    return {
      'range': range,
      'days': days,
      'completions': completions,
      'completionRate': completionRate,
      'previousCompletionRate': previousRate,
      'delta': (completionRate - previousRate).toStringAsFixed(1),
      'totalHabits': totalHabits,
    };
  }

  Future<Map<String, dynamic>> getHabitAnalytics(int habitId) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start30 = today.subtract(const Duration(days: 29));
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    final totalLogsResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE habit_id = ?",
      [habitId],
    );
    final totalLogs = totalLogsResult.first['count'] as int;

    final totalCompletionsResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE habit_id = ? AND status = 'completed'",
      [habitId],
    );
    final totalCompletions = totalCompletionsResult.first['count'] as int;

    final recentCompletionsResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE habit_id = ? AND status = 'completed' AND completed_at BETWEEN ? AND ?",
      [habitId, start30.toIso8601String(), end.toIso8601String()],
    );
    final recentCompletions =
        recentCompletionsResult.first['count'] as int;

    final distinctDaysResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM (
        SELECT DATE(completed_at) as day
        FROM habit_logs
        WHERE habit_id = ? AND status = 'completed' AND completed_at BETWEEN ? AND ?
        GROUP BY DATE(completed_at)
      )
    ''',
      [habitId, start30.toIso8601String(), end.toIso8601String()],
    );
    final distinctDays = distinctDaysResult.first['count'] as int;

    final completionRate = 30 > 0 ? (distinctDays / 30 * 100) : 0.0;

    return {
      'totalLogs': totalLogs,
      'totalCompletions': totalCompletions,
      'recentCompletions': recentCompletions,
      'completionRate': completionRate,
    };
  }

  Future<Map<int, int>> getCompletionsByHour({int days = 30}) async {
    final db = await database;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final start = end.subtract(Duration(days: days - 1));

    final rows = await db.rawQuery(
      '''
      SELECT CAST(STRFTIME('%H', completed_at) as INTEGER) as hour,
             COUNT(*) as count
      FROM habit_logs
      WHERE status = 'completed'
        AND completed_at BETWEEN ? AND ?
      GROUP BY CAST(STRFTIME('%H', completed_at) as INTEGER)
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return {
      for (final row in rows)
        (row['hour'] as int? ?? 0): (row['count'] as int? ?? 0),
    };
  }

  Future<Map<int, int>> getCompletionsByWeekday({int days = 30}) async {
    final db = await database;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final start = end.subtract(Duration(days: days - 1));

    final rows = await db.rawQuery(
      '''
      SELECT CAST(STRFTIME('%w', completed_at) as INTEGER) as weekday,
             COUNT(*) as count
      FROM habit_logs
      WHERE status = 'completed'
        AND completed_at BETWEEN ? AND ?
      GROUP BY CAST(STRFTIME('%w', completed_at) as INTEGER)
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final Map<int, int> result = {};
    for (final row in rows) {
      final raw = row['weekday'] as int? ?? 0; // 0=Sunday
      final weekday = raw == 0 ? 7 : raw; // 1=Mon ... 7=Sun
      result[weekday] = row['count'] as int? ?? 0;
    }
    return result;
  }

  Future<int> getHabitCompletionsInRange(
    int habitId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE habit_id = ? AND status = 'completed' AND completed_at BETWEEN ? AND ?",
      [habitId, start.toIso8601String(), end.toIso8601String()],
    );
    return result.first['count'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> getHabitGoalProgress(int habitId) async {
    final habit = await getHabit(habitId);
    if (habit == null) return {};

    final goalTarget = habit.goalTarget ?? 0;
    if (goalTarget <= 0) return {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (habit.goalType == 'weekly') {
      final start = today.subtract(const Duration(days: 6));
      final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
      final completed = await getHabitCompletionsInRange(
        habitId,
        start: start,
        end: end,
      );
      final dayOfWeek = today.weekday;
      final expected = (goalTarget * (dayOfWeek / 7)).ceil();
      return {
        'type': 'weekly',
        'target': goalTarget,
        'completed': completed,
        'expected': expected,
        'onTrack': completed >= expected,
      };
    }

    if (habit.goalType == 'total') {
      final totalResult = await getHabitAnalytics(habitId);
      final completed = totalResult['totalCompletions'] as int? ?? 0;
      return {
        'type': 'total',
        'target': goalTarget,
        'completed': completed,
        'expected': goalTarget,
        'onTrack': completed >= goalTarget,
      };
    }

    final currentStreak = await getHabitStreak(habitId);
    return {
      'type': 'streak',
      'target': goalTarget,
      'completed': currentStreak,
      'expected': goalTarget,
      'onTrack': currentStreak >= goalTarget,
    };
  }

  Future<double> _getCompletionRate({
    required DateTime start,
    required DateTime end,
    required int totalHabits,
  }) async {
    if (totalHabits == 0) return 0.0;
    final db = await database;

    final distinctResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM (
        SELECT habit_id, DATE(completed_at) as day
        FROM habit_logs
        WHERE status = 'completed' AND completed_at BETWEEN ? AND ?
        GROUP BY habit_id, DATE(completed_at)
      )
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final distinctCompletions = distinctResult.first['count'] as int;
    final days = end.difference(start).inDays + 1;
    return (distinctCompletions / (totalHabits * days) * 100);
  }

  DateTime _shiftMonths(DateTime date, int offset) {
    final base = date.year * 12 + (date.month - 1) + offset;
    final newYear = base ~/ 12;
    final newMonth = (base % 12) + 1;
    return DateTime(newYear, newMonth < 1 ? newMonth + 12 : newMonth, 1);
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return labels[month - 1];
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

    // Total completions/skips
    final totalCompletionsResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE status = 'completed'",
    );
    final totalCompletions = totalCompletionsResult.first['count'] as int;

    final totalSkipsResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE status = 'skipped'",
    );
    final totalSkips = totalSkipsResult.first['count'] as int;

    // Last 7 days (rolling)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentLogsResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM habit_logs 
      WHERE completed_at >= ?
    ''',
      [sevenDaysAgo.toIso8601String()],
    );
    final recentLogs = recentLogsResult.first['count'] as int;

    final recentCompletionsResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM habit_logs WHERE status = 'completed' AND completed_at >= ?",
      [sevenDaysAgo.toIso8601String()],
    );
    final recentCompletions = recentCompletionsResult.first['count'] as int;

    // Distinct habit/day completions for a fair completion rate.
    final recentDistinctResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM (
        SELECT habit_id, DATE(completed_at) as day
        FROM habit_logs
        WHERE status = 'completed' AND completed_at >= ?
        GROUP BY habit_id, DATE(completed_at)
      )
    ''',
      [sevenDaysAgo.toIso8601String()],
    );
    final recentDistinctCompletions = recentDistinctResult.first['count'] as int;

    final bestStreak = await getBestStreakAcrossActiveHabits();

    return {
      'totalHabits': totalHabits,
      'totalLogs': totalLogs,
      'recentLogs': recentLogs,
      'totalCompletions': totalCompletions,
      'totalSkips': totalSkips,
      'recentCompletions': recentCompletions,
      'recentDistinctCompletions': recentDistinctCompletions,
      'bestStreak': bestStreak,
      'completionRate': totalHabits > 0
          ? (recentDistinctCompletions / (totalHabits * 7) * 100).round()
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

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;

    final habits = await db.query('habits');
    final logs = await db.query('habit_logs');
    final settings = await db.query('user_settings');
    final notifications = await db.query('notification_settings');
    final insights = await db.query('ai_insights');

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'schema_version': _databaseVersion,
      'habits': habits,
      'habit_logs': logs,
      'user_settings': settings,
      'notification_settings': notifications,
      'ai_insights': insights,
    };
  }

  Future<void> importAllData(
    Map<String, dynamic> data, {
    bool replace = true,
  }) async {
    final db = await database;

    final habits = (data['habits'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final logs = (data['habit_logs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final settings = (data['user_settings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final notifications =
        (data['notification_settings'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final insights = (data['ai_insights'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    await db.transaction((txn) async {
      if (replace) {
        await txn.delete('habit_logs');
        await txn.delete('habits');
        await txn.delete('user_settings');
        await txn.delete('notification_settings');
        await txn.delete('ai_insights');
      }

      for (final row in habits) {
        await txn.insert('habits', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in logs) {
        await txn.insert('habit_logs', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in settings) {
        await txn.insert('user_settings', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in notifications) {
        await txn.insert('notification_settings', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in insights) {
        await txn.insert('ai_insights', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('habit_logs');
      await txn.delete('habits');
      await txn.delete('user_settings');
      await txn.delete('notification_settings');
      await txn.delete('ai_insights');
    });
  }
}
