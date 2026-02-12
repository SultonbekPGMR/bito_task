import 'dart:async';
import 'dart:math';

import 'package:unical_task/config/enum.dart';
import 'package:unical_task/domain/service/seat_manager.dart';

class BackgroundSimulator {
  final SeatManager _seatManager;
  final List<Timer> _schedulerTimers = [];
  final List<Timer> _pendingTimers = [];
  final Random _random = Random();

  static const List<String> botUserIds = [
    'bot_alice',
    'bot_bob',
    'bot_charlie',
  ];

  BackgroundSimulator(this._seatManager);

  void start() {
    for (final botId in botUserIds) {
      _scheduleNext(botId);
    }
  }

  void _scheduleNext(String botId) {
    // 1-3 second intervals — fast enough to collide with user
    final delay = Duration(milliseconds: 800 + _random.nextInt(2200));
    final timer = Timer(delay, () {
      _act(botId);
      _scheduleNext(botId);
    });
    _schedulerTimers.add(timer);
  }

  void _act(String botId) {
    final seats = _seatManager.seats;

    // 30% chance: try to grab a random seat (even if locked/reserved)
    // This creates real contention — bot slams into user's locked seats
    if (_random.nextDouble() < 0.3) {
      final seat = seats[_random.nextInt(seats.length)];
      _seatManager.lockSeat(seat.id, botId);
      return;
    }

    // 70% chance: pick an available seat
    final available =
        seats.where((s) => s.status == SeatStatus.available).toList();
    if (available.isEmpty) return;

    final seat = available[_random.nextInt(available.length)];
    final result = _seatManager.lockSeat(seat.id, botId);

    if (result != SeatResult.success) return;

    // 60% confirm quickly (0.5-2s), 40% let it expire
    if (_random.nextDouble() < 0.6) {
      final confirmTimer = Timer(
        Duration(milliseconds: 500 + _random.nextInt(1500)),
        () => _seatManager.confirmSeat(seat.id, botId),
      );
      _pendingTimers.add(confirmTimer);
    }
    // else: timeout — lock expires naturally after 10s
  }

  void stop() {
    for (final timer in _schedulerTimers) {
      timer.cancel();
    }
    _schedulerTimers.clear();
    for (final timer in _pendingTimers) {
      timer.cancel();
    }
    _pendingTimers.clear();
  }
}
