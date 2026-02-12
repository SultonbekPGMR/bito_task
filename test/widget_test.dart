import 'package:flutter_test/flutter_test.dart';
import 'package:unical_task/app.dart';
import 'package:unical_task/data/local/seat_local_storage.dart';
import 'package:unical_task/domain/service/seat_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  testWidgets('App renders seat reservation screen', (
    WidgetTester tester,
  ) async {
    await Hive.initFlutter();
    final storage = SeatLocalStorage();
    await storage.init();
    final seatManager = SeatManager(storage: storage);
    await seatManager.init();

    await tester.pumpWidget(App(seatManager: seatManager));
    await tester.pumpAndSettle();

    expect(find.text('Seat Reservation'), findsOneWidget);
    expect(find.text('Confirm Reservation'), findsOneWidget);

    seatManager.dispose();
  });
}
