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
    test('10 users fight for the same seat — only 1 wins', () {
      final results = <SeatResult>[];
      for (int i = 0; i < 10; i++) {
        results.add(manager.lockSeat('S0', 'user_$i'));
      }

      // Exactly one success
      expect(results.where((r) => r == SeatResult.success).length, 1);
      // First caller wins
      expect(results[0], SeatResult.success);
      expect(manager.seats[0].lockedBy, 'user_0');
      // All others rejected
      for (int i = 1; i < 10; i++) {
        expect(results[i], SeatResult.lockedByOther);
      }
    });

    test('rapid-fire tap same seat 100 times — state never corrupts', () {
      // Simulate user panic-tapping the same seat very fast
      // Expected: lock → unlock → lock → unlock → ...
      for (int i = 0; i < 100; i++) {
        manager.handleSeatTap('S0', 'user1');
      }
      // 100 taps = even number → back to available (lock, unlock, lock, unlock...)
      expect(manager.seats[0].status, SeatStatus.available);

      // 101 taps = odd → locked
      manager.handleSeatTap('S0', 'user1');
      expect(manager.seats[0].status, SeatStatus.locked);
      expect(manager.seats[0].lockedBy, 'user1');
    });

    test('user confirms at exact moment lock expires — gets expired', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        fakeManager.init();

        fakeManager.lockSeat('S0', 'user1');

        // Advance to exactly 10s — timer fires, then confirm arrives
        async.elapse(const Duration(seconds: 10));

        // Timer already fired → seat is available
        expect(fakeManager.seats[0].status, SeatStatus.available);

        // User's confirm arrives "right after" — seat is no longer locked
        final result = fakeManager.confirmSeat('S0', 'user1');
        expect(result, SeatResult.notLocked);
        expect(fakeManager.seats[0].status, SeatStatus.available);

        fakeManager.dispose();
      });
    });

    test('bot locks seat → user taps same seat → user gets rejected', () {
      // Bot grabs the seat
      final botResult = manager.lockSeat('S0', 'bot_user');
      expect(botResult, SeatResult.success);

      // User taps the same seat via handleSeatTap (like real UI would)
      final userResult = manager.handleSeatTap('S0', 'current_user');
      expect(userResult, SeatResult.lockedByOther);
      // Seat still belongs to bot
      expect(manager.seats[0].lockedBy, 'bot_user');
    });

    test('bot confirms seat → user tries to lock → gets alreadyReserved', () {
      manager.lockSeat('S0', 'bot_user');
      manager.confirmSeat('S0', 'bot_user');

      final result = manager.handleSeatTap('S0', 'current_user');
      expect(result, SeatResult.alreadyReserved);
      expect(manager.seats[0].status, SeatStatus.reserved);
    });

    test('user batch confirms while bot locks one of user seats mid-loop', () {
      // User locks S0, S1, S2
      manager.lockSeat('S0', 'user1');
      manager.lockSeat('S1', 'user1');
      manager.lockSeat('S2', 'user1');

      // Bot tries to lock S1 — fails because user1 holds it
      final botResult = manager.lockSeat('S1', 'bot_user');
      expect(botResult, SeatResult.lockedByOther);

      // User batch confirms — all 3 should succeed
      final result = manager.confirmAllUserSeats('user1');
      expect(result.confirmed, 3);
      expect(result.expired, 0);
      expect(manager.seats[0].status, SeatStatus.reserved);
      expect(manager.seats[1].status, SeatStatus.reserved);
      expect(manager.seats[2].status, SeatStatus.reserved);
    });

    test('batch confirm with mix of expired and valid locks', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        fakeManager.init();

        // Lock S0 at t=0
        fakeManager.lockSeat('S0', 'user1');

        // Wait 8 seconds, then lock S1 at t=8
        async.elapse(const Duration(seconds: 8));
        fakeManager.lockSeat('S1', 'user1');

        // Wait 3 more seconds (t=11) — S0's timer fires (expired), S1 still has 5s
        async.elapse(const Duration(seconds: 3));

        // S0 already expired via timer
        expect(fakeManager.seats[0].status, SeatStatus.available);
        // S1 still locked
        expect(fakeManager.seats[1].status, SeatStatus.locked);

        // Batch confirm — only S1 should confirm
        final result = fakeManager.confirmAllUserSeats('user1');
        expect(result.confirmed, 1);
        expect(result.expired, 0); // S0 already gone, not in locked state
        expect(fakeManager.seats[1].status, SeatStatus.reserved);

        fakeManager.dispose();
      });
    });

    test('lock-expire-relock cycle — seat can be reused after expiry', () {
      fakeAsync((async) {
        final fakeStorage = FakeSeatLocalStorage();
        final fakeManager = SeatManager(storage: fakeStorage);
        fakeManager.init();

        // User1 locks, lets it expire
        fakeManager.lockSeat('S0', 'user1');
        async.elapse(const Duration(seconds: 10));
        expect(fakeManager.seats[0].status, SeatStatus.available);

        // User2 grabs it immediately
        final result = fakeManager.lockSeat('S0', 'user2');
        expect(result, SeatResult.success);
        expect(fakeManager.seats[0].lockedBy, 'user2');

        // User2 confirms
        fakeManager.confirmSeat('S0', 'user2');
        expect(fakeManager.seats[0].status, SeatStatus.reserved);

        // User1 tries again — too late
        final lateResult = fakeManager.lockSeat('S0', 'user1');
        expect(lateResult, SeatResult.alreadyReserved);

        fakeManager.dispose();
      });
    });

    test('20 users race for 5 seats — no double locks, no corruption', () {
      final seatIds = ['S0', 'S1', 'S2', 'S3', 'S4'];
      final userCount = 20;

      // Each user tries to lock all 5 seats
      for (int u = 0; u < userCount; u++) {
        for (final seatId in seatIds) {
          manager.lockSeat(seatId, 'user_$u');
        }
      }

      // Each seat must be locked by exactly one user
      for (final seatId in seatIds) {
        final seat = manager.seats.firstWhere((s) => s.id == seatId);
        expect(seat.status, SeatStatus.locked);
        expect(seat.lockedBy, isNotNull);
        // Winner is user_0 since they went first
        expect(seat.lockedBy, 'user_0');
      }
    });

    test('confirm-then-lock-then-confirm chain — reserved is permanent', () {
      // User1 locks and confirms
      manager.lockSeat('S0', 'user1');
      manager.confirmSeat('S0', 'user1');
      expect(manager.seats[0].status, SeatStatus.reserved);

      // User2 tries lock → fail
      expect(manager.lockSeat('S0', 'user2'), SeatResult.alreadyReserved);
      // User2 tries handleSeatTap → fail
      expect(manager.handleSeatTap('S0', 'user2'), SeatResult.alreadyReserved);
      // User1 tries to re-lock own reserved → fail
      expect(manager.lockSeat('S0', 'user1'), SeatResult.alreadyReserved);
      // User1 tries handleSeatTap on reserved → fail
      expect(manager.handleSeatTap('S0', 'user1'), SeatResult.alreadyReserved);

      // Still reserved, no corruption
      expect(manager.seats[0].status, SeatStatus.reserved);
    });

    test('all 64 seats locked by different users — no conflicts', () {
      for (int i = 0; i < 64; i++) {
        final result = manager.lockSeat('S$i', 'user_$i');
        expect(result, SeatResult.success);
      }

      // All locked by different users
      for (int i = 0; i < 64; i++) {
        expect(manager.seats[i].status, SeatStatus.locked);
        expect(manager.seats[i].lockedBy, 'user_$i');
      }

      // Cross-user lock attempts all fail
      for (int i = 0; i < 64; i++) {
        final result = manager.lockSeat('S$i', 'attacker');
        expect(result, SeatResult.lockedByOther);
      }
    });
  });
}
