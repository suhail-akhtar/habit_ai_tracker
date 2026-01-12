import 'package:home_widget/home_widget.dart';
import '../utils/app_log.dart';

class WidgetService {
  static const String _androidWidgetName =
      'HabitWidgetProvider'; // Class name in Android

  static Future<void> updateStreak(int streak) async {
    try {
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await _updateWidget();
    } catch (e) {
      AppLog.e('Error updating widget streak', e);
    }
  }

  static Future<void> updateHabitStatus(int completed, int total) async {
    try {
      await HomeWidget.saveWidgetData<int>('completed_count', completed);
      await HomeWidget.saveWidgetData<int>('total_count', total);
      // Calculate percentage for progress bar
      final int percent = total > 0 ? ((completed / total) * 100).toInt() : 0;
      await HomeWidget.saveWidgetData<int>('percent', percent);

      await _updateWidget();
    } catch (e) {
      AppLog.e('Error updating widget status', e);
    }
  }

  static Future<void> _updateWidget() async {
    try {
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: 'HabitWidget', // iOS Widget Name
      );
    } catch (e) {
      AppLog.e('Error triggering widget update', e);
    }
  }
}
