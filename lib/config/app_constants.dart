// Created by Sultonbek Tulanov on 12-February 2026
import '../domain/model/seat/seat_model.dart';
import 'enum.dart';

class AppConstants {
  static const String appName = 'Flutter Demo';

  static final List<SeatModel> defaultSeats = List.generate(
    64,
    (index) => SeatModel(
      id: 'S$index',
      status: SeatStatus.available,
      lockedBy: null,
      lockExpirationTime: null,
    ),
  );
}
