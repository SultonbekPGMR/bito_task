import 'package:unical_task/data/local/seat_local_storage.dart';

class FakeSeatLocalStorage implements SeatLocalStorage {
  List<String> savedIds = [];

  @override
  Future<void> init() async {}

  @override
  Set<String> getReservedSeatIds() => Set<String>.from(savedIds);

  @override
  Future<void> saveReservedSeatIds(List<String> ids) async {
    savedIds = List<String>.from(ids);
  }
}
