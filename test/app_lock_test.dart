import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notevia_mobile_app/services/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('closing the app from the lock screen keeps it locked next time', () async {
    SharedPreferences.setMockInitialValues({'lock_preference': 'immediately'});
    final lock = AppLockService();
    await lock.loadCachedPreference();

    // Signed in and unlocked; then the app is closed
    await lock.startSession('', locked: false);
    lock.handleAppLifecycleChange(AppLifecycleState.paused);
    expect(lock.isLocked, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Android kills it; next launch
    expect(await lock.shouldLockOnStartup(), isTrue);
    await lock.startSession('', locked: true);

    // Closed again from the lock screen, killed, opened again
    lock.handleAppLifecycleChange(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await lock.shouldLockOnStartup(), isTrue);

    // Unlocking with the PIN clears it
    lock.unlockAfterPinVerification();
    await lock.startSession('', locked: false);
    expect(await lock.shouldLockOnStartup(), isFalse);
  });

  test('signing out clears the lock', () async {
    SharedPreferences.setMockInitialValues({'lock_preference': 'immediately'});
    final lock = AppLockService();
    await lock.startSession('', locked: true);
    await lock.endSession();
    expect(await lock.shouldLockOnStartup(), isFalse);
  });
}
