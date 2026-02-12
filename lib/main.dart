import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:unical_task/app.dart';
import 'package:unical_task/data/local/seat_local_storage.dart';
import 'package:unical_task/domain/service/seat_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final storage = SeatLocalStorage();
  await storage.init();

  final seatManager = SeatManager(storage: storage);
  await seatManager.init();

  runApp(App(seatManager: seatManager));
}
