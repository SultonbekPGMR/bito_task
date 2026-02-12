import 'package:hive_flutter/hive_flutter.dart';

class SeatLocalStorage {
  static const String _boxName = 'reserved_seats';
  static const String _key = 'ids';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Set<String> getReservedSeatIds() {
    final box = Hive.box(_boxName);
    final ids = box.get(_key);
    if (ids == null) return {};
    return Set<String>.from(ids as List);
  }

  Future<void> saveReservedSeatIds(List<String> ids) async {
    final box = Hive.box(_boxName);
    await box.put(_key, ids);
  }
}
