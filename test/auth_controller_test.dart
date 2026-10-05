import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/auth/auth_backend.dart';
import 'package:app/core/auth/auth_controller.dart';

import 'fakes/fake_auth_backend.dart';

const _asha = AppUser(uid: 'a', name: 'Asha Verma', email: 'asha@gmail.com');
const _ravi = AppUser(uid: 'b', name: 'Ravi', email: 'ravi@gmail.com');

void main() {
  test('starts as "checking" and becomes unavailable when Firebase is not configured', () async {
    final c = AuthController.ready(FakeAuthBackend(configured: false));
    expect(c.status, AuthStatus.checking);
    await c.init();
    expect(c.status, AuthStatus.unavailable);
    expect(c.isAvailable, isFalse);
    expect(await c.signIn(), isFalse);
  });

  test('a backend that fails to start also means unavailable (never throws)', () async {
    final c = AuthController(() async => throw StateError('no firebase'));
    await c.init();
    expect(c.status, AuthStatus.unavailable);
  });

  test('signed out at start, then signs in', () async {
    final backend = FakeAuthBackend();
    final c = AuthController.ready(backend);
    await c.init();
    expect(c.status, AuthStatus.signedOut);
    expect(c.isSignedIn, isFalse);

    expect(await c.signIn(), isTrue);
    expect(c.status, AuthStatus.signedIn);
    expect(c.user?.email, 'asha@gmail.com');
  });

  test('an already signed-in person is restored at start', () async {
    final c = AuthController.ready(FakeAuthBackend(start: _asha));
    await c.init();
    expect(c.status, AuthStatus.signedIn);
    expect(c.user?.uid, 'a');
  });

  test('cancelling sign-in keeps the previous state and reports "cancelled"', () async {
    final backend = FakeAuthBackend()..nextResult = const AuthCancelledException();
    final c = AuthController.ready(backend);
    await c.init();
    expect(await c.signIn(), isFalse);
    expect(c.status, AuthStatus.signedOut);
    expect(c.message, AuthMessage.cancelled);
    c.clearMessage();
    expect(c.message, AuthMessage.none);
  });

  test('a failure reports "failed" and does not sign in', () async {
    final backend = FakeAuthBackend()..nextResult = const AuthFailedException('network');
    final c = AuthController.ready(backend);
    await c.init();
    expect(await c.signIn(), isFalse);
    expect(c.status, AuthStatus.signedOut);
    expect(c.message, AuthMessage.failed);
  });

  test('switching account: cancelling keeps the current account', () async {
    final backend = FakeAuthBackend(start: _asha);
    final c = AuthController.ready(backend);
    await c.init();

    backend.nextResult = const AuthCancelledException();
    expect(await c.signIn(), isFalse);
    expect(c.status, AuthStatus.signedIn);
    expect(c.user?.uid, 'a');
  });

  test('switching account: choosing another account changes the user', () async {
    final backend = FakeAuthBackend(start: _asha);
    final c = AuthController.ready(backend);
    await c.init();

    backend.nextResult = _ravi;
    expect(await c.signIn(), isTrue);
    expect(c.user?.uid, 'b');
    expect(c.user?.uid, isNot('a'));
  });

  test('sign out clears the user', () async {
    final backend = FakeAuthBackend(start: _asha);
    final c = AuthController.ready(backend);
    await c.init();
    await c.signOut();
    expect(c.status, AuthStatus.signedOut);
    expect(c.user, isNull);
    expect(backend.signOutCalls, 1);
  });

  test('listeners are told about every change', () async {
    final c = AuthController.ready(FakeAuthBackend());
    var calls = 0;
    c.addListener(() => calls++);
    await c.init();
    await c.signIn();
    await c.signOut();
    expect(calls, greaterThanOrEqualTo(4));
  });

  test('init can be called twice safely', () async {
    final backend = FakeAuthBackend(start: _asha);
    final c = AuthController.ready(backend);
    await c.init();
    await c.init();
    expect(c.status, AuthStatus.signedIn);
  });

  test('per-account storage keys never collide', () {
    expect(scopedKey('a', 'notes'), isNot(scopedKey('b', 'notes')));
    expect(scopedKey('a', 'notes'), 'u.a.notes');
  });

  test('avatar initial', () {
    expect(_asha.initial, 'A');
    expect(const AppUser(uid: 'x', name: '', email: 'zed@x.com').initial, 'Z');
    expect(const AppUser(uid: 'x', name: '', email: '').initial, '?');
  });
}
