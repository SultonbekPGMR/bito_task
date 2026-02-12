import 'dart:async';

import 'package:unical_task/config/app_constants.dart';
import 'package:unical_task/config/enum.dart';
import 'package:unical_task/data/local/seat_local_storage.dart';
import 'package:unical_task/domain/model/seat/seat_model.dart';

class SeatManager {
  final SeatLocalStorage _storage;

  List<SeatModel> _seats = [];
  final _controller = StreamController<List<SeatModel>>.broadcast();
  final _logController = StreamController<String>.broadcast();
  final Map<String, Timer> _expirationTimers = {};

  Stream<String> get logStream => _logController.stream;

  SeatManager({required SeatLocalStorage storage}) : _storage = storage;

  Stream<List<SeatModel>> get stream => _controller.stream;

  List<SeatModel> get seats => List.unmodifiable(_seats);

  Future<void> init() async {
    final reservedIds = _storage.getReservedSeatIds();
    _seats = AppConstants.defaultSeats.map((seat) {
      if (reservedIds.contains(seat.id)) {
        return seat.copyWith(status: SeatStatus.reserved);
      }
      return seat;
    }).toList();
    _emit();
  }

  SeatResult handleSeatTap(String seatId, String userId) {
    final index = _seats.indexWhere((s) => s.id == seatId);
    if (index == -1) return SeatResult.notLocked;

    final seat = _seats[index];

    if (seat.status == SeatStatus.locked && seat.lockedBy == userId) {
      return unlockSeat(seatId, userId);
    }

    return lockSeat(seatId, userId);
  }

  ({int confirmed, int expired}) confirmAllUserSeats(String userId) {
    int confirmed = 0;
    int expired = 0;

    for (int i = 0; i < _seats.length; i++) {
      final seat = _seats[i];
      if (seat.status != SeatStatus.locked || seat.lockedBy != userId) continue;

      _expirationTimers[seat.id]?.cancel();
      _expirationTimers.remove(seat.id);

      if (seat.lockExpirationTime != null &&
          seat.lockExpirationTime!.isBefore(DateTime.now())) {
        _seats[i] = seat.copyWith(
          status: SeatStatus.available,
          lockedBy: null,
          lockExpirationTime: null,
        );
        expired++;
      } else {
        _seats[i] = seat.copyWith(
          status: SeatStatus.reserved,
          lockedBy: null,
          lockExpirationTime: null,
        );
        confirmed++;
      }
    }

    if (confirmed > 0) _persistReservedSeats();
    if (confirmed > 0 || expired > 0) {
      _log('[$userId] batch confirm: $confirmed reserved, $expired expired');
    }
    _emit();
    return (confirmed: confirmed, expired: expired);
  }

  SeatResult lockSeat(String seatId, String userId) {
    final index = _seats.indexWhere((s) => s.id == seatId);
    if (index == -1) return SeatResult.notLocked;

    final seat = _seats[index];

    if (seat.status == SeatStatus.reserved) return SeatResult.alreadyReserved;
    if (seat.status == SeatStatus.locked) {
      if (seat.lockedBy == userId) return SeatResult.alreadyLockedByYou;
      return SeatResult.lockedByOther;
    }

    _seats[index] = seat.copyWith(
      status: SeatStatus.locked,
      lockedBy: userId,
      lockExpirationTime: DateTime.now().add(const Duration(seconds: 10)),
    );
    _startExpirationTimer(seatId);
    _log('[$userId] locked seat $seatId');
    _emit();
    return SeatResult.success;
  }

  SeatResult unlockSeat(String seatId, String userId) {
    final index = _seats.indexWhere((s) => s.id == seatId);
    if (index == -1) return SeatResult.notLocked;

    final seat = _seats[index];
    if (seat.status != SeatStatus.locked || seat.lockedBy != userId) {
      return SeatResult.notLocked;
    }

    _expirationTimers[seatId]?.cancel();
    _expirationTimers.remove(seatId);
    _seats[index] = seat.copyWith(
      status: SeatStatus.available,
      lockedBy: null,
      lockExpirationTime: null,
    );
    _log('[$userId] unlocked seat $seatId');
    _emit();
    return SeatResult.success;
  }

  SeatResult confirmSeat(String seatId, String userId) {
    final index = _seats.indexWhere((s) => s.id == seatId);
    if (index == -1) return SeatResult.notLocked;

    final seat = _seats[index];

    if (seat.status != SeatStatus.locked) return SeatResult.notLocked;
    if (seat.lockedBy != userId) return SeatResult.lockedByOther;

    if (seat.lockExpirationTime != null &&
        seat.lockExpirationTime!.isBefore(DateTime.now())) {
      _seats[index] = seat.copyWith(
        status: SeatStatus.available,
        lockedBy: null,
        lockExpirationTime: null,
      );
      _expirationTimers[seatId]?.cancel();
      _expirationTimers.remove(seatId);
      _log('[$userId] confirm failed — seat $seatId expired');
      _emit();
      return SeatResult.expired;
    }

    _expirationTimers[seatId]?.cancel();
    _expirationTimers.remove(seatId);

    _seats[index] = seat.copyWith(
      status: SeatStatus.reserved,
      lockedBy: null,
      lockExpirationTime: null,
    );
    _log('[$userId] confirmed seat $seatId → reserved');
    _emit();

    _persistReservedSeats();
    return SeatResult.success;
  }

  void _startExpirationTimer(String seatId) {
    _expirationTimers[seatId]?.cancel();
    _expirationTimers[seatId] = Timer(const Duration(seconds: 10), () {
      _expireSeat(seatId);
    });
  }

  void _expireSeat(String seatId) {
    final index = _seats.indexWhere((s) => s.id == seatId);
    if (index == -1) return;

    final seat = _seats[index];
    if (seat.status != SeatStatus.locked) return;

    _seats[index] = seat.copyWith(
      status: SeatStatus.available,
      lockedBy: null,
      lockExpirationTime: null,
    );
    _expirationTimers.remove(seatId);
    _log('[${seat.lockedBy}] seat $seatId lock expired');
    _emit();
  }

  void _persistReservedSeats() {
    final reservedIds = _seats
        .where((s) => s.status == SeatStatus.reserved)
        .map((s) => s.id)
        .toList();
    _storage.saveReservedSeatIds(reservedIds);
  }

  void _log(String message) {
    if (!_logController.isClosed) {
      _logController.add(message);
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_seats));
    }
  }

  void dispose() {
    for (final timer in _expirationTimers.values) {
      timer.cancel();
    }
    _expirationTimers.clear();
    _controller.close();
    _logController.close();
  }
}
