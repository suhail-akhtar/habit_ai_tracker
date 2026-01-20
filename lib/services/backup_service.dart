import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../services/database_service.dart';

class BackupService {
  final DatabaseService _databaseService = DatabaseService();

  Future<File> exportJsonBackup() async {
    final data = await _databaseService.exportAllData();
    final payload = jsonEncode(data);
    return _writeTempFile(
      'habit_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      payload,
    );
  }

  Future<List<File>> exportCsv() async {
    final data = await _databaseService.exportAllData();

    final habits = (data['habits'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final logs = (data['habit_logs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final habitsCsv = _toCsv(habits);
    final logsCsv = _toCsv(logs);

    final habitsFile = await _writeTempFile(
      'habits_${DateTime.now().millisecondsSinceEpoch}.csv',
      habitsCsv,
    );
    final logsFile = await _writeTempFile(
      'habit_logs_${DateTime.now().millisecondsSinceEpoch}.csv',
      logsCsv,
    );

    return [habitsFile, logsFile];
  }

  Future<void> importJsonBackup(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    await _databaseService.importAllData(data, replace: true);
  }

  Future<File> _writeTempFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsString(content, flush: true);
  }

  String _toCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';

    final headers = rows.first.keys.toList();
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final row in rows) {
      final values = headers.map((header) {
        final value = row[header];
        final stringValue = value == null ? '' : value.toString();
        final escaped = stringValue.replaceAll('"', '""');
        return '"$escaped"';
      }).join(',');
      buffer.writeln(values);
    }

    return buffer.toString();
  }
}
