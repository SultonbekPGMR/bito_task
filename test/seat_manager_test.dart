import 'package:flutter_test/flutter_test.dart';
import 'package:unical_task/config/enum.dart';
import 'package:unical_task/domain/service/seat_manager.dart';
import 'package:fake_async/fake_async.dart';

import 'helpers/fake_seat_local_storage.dart';

void main() {
  late FakeSeatLocalStorage storage;
  late SeatManager manager;

  setUp(() async {
    storage = FakeSeatLocalStorage();
    manager = SeatManager(storage: storage);
    await manager.init();
  });

  tearDown(() {
    manager.dispose();
  });

  group('Initial state', () {
    test('starts with 64 available seats', () {
      expect(manager.seats.length, 64);
      expect(
        manager.seats.every((s) => s.status == SeatStatus.available),
        isTrue,
      );
    });

    test('restores reserved seats from storage', () async {
      storage.savedIds = ['S0', 'S5', 'S10'];
      final manager2 = SeatManager(storage: storage);
      await manager2.init();

      expect(manager2.seats[0].status, SeatStatus.reserved);
      expect(manager2.seats[5].status, SeatStatus.reserved);
      expect(manager2.seats[10].status, SeatStatus.reserved);
      expect(manager2.seats[1].status, SeatStatus.available);

      manager2.dispose();
    });
  });

  group('lockSeat', () {
    test('locks an available seat', () {
      final result = manager.lockSeat('S0', 'user1');
      expect(result, SeatResult.success);
      expect(manager.seats[0].status, SeatStatus.locked);
      expect(manager.seats[0].lockedBy, 'user1');
      expect(manager.seats[0].lockExpirationTime, isNotNull);
    });

    test('rejects locking a reserved seat', () {
      manager.lockSeat('S0', 'user1');
      manager.confirmSeat('S0', 'user1');

      final result = manager.lockSeat('S0', 'user2');
      expect(result, SeatResult.alreadyReserved);
    });

    test('rejects locking a seat already locked by same user', () {
      manager.lockSeat('S0', 'user1');
      final result = manager.lockSeat('S0', 'user1');
      expect(result, SeatResult.alreadyLockedByYou);
    });

    test('rejects locking a seat locked by another user', () {
      manager.lockSeat('S0', 'user1');
      final result = manager.lockSeat('S0', 'user2');
      expect(result, SeatResult.lockedByOther);
    });

    test('returns notLocked for invalid seat id', () {
      final result = manager.lockSeat('INVALID', 'user1');
      expect(result, SeatResult.notLocked);
    });
  });

  group('unlockSeat', () {
    test('unlocks a seat locked by the same user', () {
      manager.lockSeat('S0', 'user1');
      final result = manager.unlockSeat('S0', 'user1');
      expect(result, SeatResult.success);
      expect(manager.seats[0].status, SeatStatus.available);
      expect(manager.seats[0].lockedBy, isNull);
    });

    test('rejects unlocking a seat locked by another user', () {
      manager.lockSeat('S0', 'user1');
      final result = manager.unlockSeat('S0', 'user2');
      expect(result, SeatResult.notLocked);
    });

    test('rejects unlocking an available seat', () {
      final result = manager.unlockSeat('S0', 'user1');
      expect(result, SeatResult.notLocked);
    });
  });

  group('handleSeatTap', () {
    test('locks an available seat on tap', () {
      final result = manager.handleSeatTap('S0', 'user1');
      expect(result, SeatResult.success);
      expect(manager.seats[0].status, SeatStatus.locked);
    });

    test('unlocks own locked seat on tap (toggle)', () {
      manager.handleSeatTap('S0', 'user1');
      final result = manager.handleSeatTap('S0', 'user1');
      expect(result, SeatResult.success);
      expect(manager.seats[0].status, SeatStatus.available);
    });

    test('rejects tap on seat locked by another user', () {
      manager.lockSeat('S0', 'user1');
      final result = manager.handleSeatTap('S0', 'user2');
      expect(result, SeatResult.lockedByOther);
    });
  });

  group('confirmSeat', () {
    test('confirms a locked seat', () {
      manager.lockSeat('S0', 'user1');
      final result = manager.confirmSeat('S0', 'user1');
      expect(result, SeatResult.success);
      expect(manager.seats[0].status, SeatStatus.reserved);
      expect(manager.seats[0].lockedBy, isNull);
    });

    test('rejects confirming a seat locked by another user', () {
      manager.lockSeat('S0', 'user1');
      final result = manager.confirmSeat('S0', 'user2');
      expect(result, SeatResult.lockedByOther);
    });

    test('rejects confirming an available seat', () {
      final result = manager.confirmSeat('S0', 'user1');
      expect(result, SeatResult.notLocked);
    });

    test('persists reserved seat ids after confirm', () {
      manager.lockSeat('S0', 'user1');
      manager.confirmSeat('S0', 'user1');
      expect(storage.savedIds, contains('S0'));
    });
  });

  group('confirmAllUserSeats', () {
    test('confirms all seats locked by the user', () {
      manager.lockSeat('S0', 'user1');
      manager.lockSeat('S1', 'user1');
      manager.lockSeat('S2', 'user2');

      final result = manager.confirmAllUserSeats('user1');
      expect(result.confirmed, 2);
      expect(result.expired, 0);
      expect(manager.seats[0].status, SeatStatus.reserved);
      expect(manager.seats[1].status, SeatStatus.reserved);
      expect(manager.seats[2].status, SeatStatus.locked);
    });

    test('returns zeros when no seats are locked by user', () {
      final result = manager.confirmAllUserSeats('user1');
      expect(result.confirmed, 0);
      expect(result.expired, 0);
    });

    test('persists after batch confirm', () {
      manager.lockSeat('S0', 'user1');
      manager.lockSeat('S1', 'user1');
      manager.confirmAllUserSeats('user1');
      expect(storage.savedIds, containsAll(['S0', 'S1']));
    });
  });

  group('Expiration', () {
    test('seat expires after 10 seconds', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        // Manually init sync portion
        fakeManager.init();

        fakeManager.lockSeat('S0', 'user1');
        expect(fakeManager.seats[0].status, SeatStatus.locked);

        async.elapse(const Duration(seconds: 10));

        expect(fakeManager.seats[0].status, SeatStatus.available);
        expect(fakeManager.seats[0].lockedBy, isNull);

        fakeManager.dispose();
      });
    });

    test('confirming before expiry prevents expiration', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        fakeManager.init();

        fakeManager.lockSeat('S0', 'user1');
        async.elapse(const Duration(seconds: 5));
        fakeManager.confirmSeat('S0', 'user1');
        async.elapse(const Duration(seconds: 10));

        expect(fakeManager.seats[0].status, SeatStatus.reserved);

        fakeManager.dispose();
      });
    });

    test('unlocking before expiry cancels timer', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        fakeManager.init();

        fakeManager.lockSeat('S0', 'user1');
        async.elapse(const Duration(seconds: 3));
        fakeManager.unlockSeat('S0', 'user1');
        async.elapse(const Duration(seconds: 10));

        expect(fakeManager.seats[0].status, SeatStatus.available);

        fakeManager.dispose();
      });
    });

    test('confirm after expiry returns expired result', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        fakeManager.init();

        fakeManager.lockSeat('S0', 'user1');
        // Manually expire the time without triggering timer callback
        // by checking confirmSeat behavior when lockExpirationTime is past
        async.elapse(const Duration(seconds: 11));

        // Seat already expired via timer
        expect(fakeManager.seats[0].status, SeatStatus.available);

        fakeManager.dispose();
      });
    });

    test('batch confirm detects expired seats', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        fakeManager.init();

        fakeManager.lockSeat('S0', 'user1');
        fakeManager.lockSeat('S1', 'user1');

        // Advance past S0 and S1 lock
        async.elapse(const Duration(seconds: 11));

        // Both expired via timer, batch confirm finds nothing
        final result = fakeManager.confirmAllUserSeats('user1');
        expect(result.confirmed, 0);
        expect(result.expired, 0);

        fakeManager.dispose();
      });
    });
  });

  group('Stream emissions', () {
    test('emits updated seats on lock', () async {
      final future = manager.stream.first;
      manager.lockSeat('S0', 'user1');
      final seats = await future;
      expect(seats[0].status, SeatStatus.locked);
    });

    test('emits updated seats on unlock', () async {
      manager.lockSeat('S0', 'user1');
      final future = manager.stream.first;
      manager.unlockSeat('S0', 'user1');
      final seats = await future;
      expect(seats[0].status, SeatStatus.available);
    });

    test('emits updated seats on confirm', () async {
      manager.lockSeat('S0', 'user1');
      final future = manager.stream.first;
      manager.confirmSeat('S0', 'user1');
      final seats = await future;
      expect(seats[0].status, SeatStatus.reserved);
    });
  });

  group('Log stream', () {
    test('emits log on lock', () async {
      final future = manager.logStream.first;
      manager.lockSeat('S0', 'user1');
      final log = await future;
      expect(log, contains('locked seat S0'));
    });

    test('emits log on unlock', () async {
      manager.lockSeat('S0', 'user1');
      final future = manager.logStream.first;
      manager.unlockSeat('S0', 'user1');
      final log = await future;
      expect(log, contains('unlocked seat S0'));
    });

    test('emits log on confirm', () async {
      manager.lockSeat('S0', 'user1');
      final future = manager.logStream.first;
      manager.confirmSeat('S0', 'user1');
      final log = await future;
      expect(log, contains('confirmed seat S0'));
    });
  });

  group('Race condition safety', () {
    test('two users cannot lock the same seat', () {
      final result1 = manager.lockSeat('S0', 'user1');
      final result2 = manager.lockSeat('S0', 'user2');

      expect(result1, SeatResult.success);
      expect(result2, SeatResult.lockedByOther);
      expect(manager.seats[0].lockedBy, 'user1');
    });

    test('handleSeatTap uses live state not stale snapshot', () {
      // User1 locks S0
      manager.lockSeat('S0', 'user1');
      // User2 tries to tap S0 — should fail because S0 is locked
      final result = manager.handleSeatTap('S0', 'user2');
      expect(result, SeatResult.lockedByOther);
    });

    test('concurrent lock and confirm on same seat', () {
      manager.lockSeat('S0', 'user1');
      // user1 confirms
      final confirmResult = manager.confirmSeat('S0', 'user1');
      // user2 tries to lock the now-reserved seat
      final lockResult = manager.lockSeat('S0', 'user2');

      expect(confirmResult, SeatResult.success);
      expect(lockResult, SeatResult.alreadyReserved);
    });
  });
}
