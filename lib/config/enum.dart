// Created by Sultonbek Tulanov on 12-February 2026

enum SeatStatus { available, locked, reserved }

enum SeatResult {
  success,
  alreadyReserved,
  lockedByOther,
  alreadyLockedByYou,
  notLocked,
  expired,
  noLockedSeats;

  String get message {
    switch (this) {
      case SeatResult.success:
        return 'Success';
      case SeatResult.alreadyReserved:
        return 'Seat is already reserved';
      case SeatResult.lockedByOther:
        return 'Seat is locked by another user';
      case SeatResult.alreadyLockedByYou:
        return 'Seat is already locked by you';
      case SeatResult.notLocked:
        return 'Seat is not locked';
      case SeatResult.expired:
        return 'Lock has expired';
      case SeatResult.noLockedSeats:
        return 'No locked seats to confirm';
    }
  }
}
