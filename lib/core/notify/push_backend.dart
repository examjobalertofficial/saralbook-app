import 'package:onesignal_flutter/onesignal_flutter.dart';

/// The part that talks to the phone's push service (OneSignal).
/// Kept small so the rest of the app, and the tests, never touch the real thing.
abstract class PushBackend {
  /// Starts the service. Safe to call once per app start.
  Future<void> start(String appId);

  /// Receive notifications on this phone (asks Android for permission if needed).
  Future<void> optIn();

  /// Stop receiving notifications on this phone.
  Future<void> optOut();
}

class OneSignalPushBackend implements PushBackend {
  const OneSignalPushBackend();

  @override
  Future<void> start(String appId) async {
    await OneSignal.initialize(appId);
  }

  @override
  Future<void> optIn() async {
    // On Android 13+ this shows the "Allow notifications?" box; the user may refuse.
    await OneSignal.Notifications.requestPermission(false);
    await OneSignal.User.pushSubscription.optIn();
  }

  @override
  Future<void> optOut() => OneSignal.User.pushSubscription.optOut();
}

/// For tests.
class MemoryPushBackend implements PushBackend {
  String? startedWith;
  int startCalls = 0;
  int optInCalls = 0;
  int optOutCalls = 0;
  bool failing = false;

  @override
  Future<void> start(String appId) async {
    startCalls++;
    if (failing) throw StateError('no push service');
    startedWith = appId;
  }

  @override
  Future<void> optIn() async {
    optInCalls++;
    if (failing) throw StateError('no push service');
  }

  @override
  Future<void> optOut() async {
    optOutCalls++;
    if (failing) throw StateError('no push service');
  }
}
