import 'dart:async';
import 'dart:math';

import 'package:unical_task/config/enum.dart';
import 'package:unical_task/domain/service/seat_manager.dart';

class BackgroundSimulator {
  final SeatManager _seatManager;
  Timer? _schedulerTimer;
  final List<Timer> _pendingConfirmTimers = [];
  final Random _random = Random();

  static const String botUserId = 'bot_user';

  BackgroundSimulator(this._seatManager);

  void start() {
    _scheduleNext();
  }

  void _scheduleNext() {
    final delay = Duration(seconds: 3 + _random.nextInt(3));
    _schedulerTimer = Timer(delay, () {
      _act();
      _scheduleNext();
    });
  }

  void _act() {
    final availableSeats =
        _seatManager.seats
            .where((s) => s.status == SeatStatus.available)
            .toList();

    if (availableSeats.isEmpty) return;

    final seat = availableSeats[_random.nextInt(availableSeats.length)];
    final result = _seatManager.lockSeat(seat.id, botUserId);

    if (result == SeatResult.success) {
      if (_random.nextBool()) {
        final confirmTimer = Timer(
          Duration(seconds: 1 + _random.nextInt(3)),
          () => _seatManager.confirmSeat(seat.id, botUserId),
        );
        _pendingConfirmTimers.add(confirmTimer);
      }
    }
  }

  void stop() {
    _schedulerTimer?.cancel();
    for (final timer in _pendingConfirmTimers) {
      timer.cancel();
    }
    _pendingConfirmTimers.clear();
  }
}
