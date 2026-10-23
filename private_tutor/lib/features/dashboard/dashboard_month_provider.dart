import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardMonthProvider =
    NotifierProvider<DashboardMonthController, DateTime>(
      DashboardMonthController.new,
    );

class DashboardMonthController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void select(DateTime date) {
    state = DateTime(date.year, date.month);
  }

  void moveBy(int months) {
    state = DateTime(state.year, state.month + months);
  }
}
