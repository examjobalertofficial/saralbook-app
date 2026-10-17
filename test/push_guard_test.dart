import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/notify/push_backend.dart';
import 'package:app/core/notify/push_controller.dart';

const _id = '12345678-1234-1234-1234-123456789abc';

Future<SharedPreferences> _prefs(Map<String, Object> start) async {
  SharedPreferences.setMockInitialValues(start);
  return SharedPreferences.getInstance();
}

void main() {
  test('a normal start works and leaves no guard behind', () async {
    final prefs = await _prefs({});
    final backend = MemoryPushBackend();
    final push = PushController(prefs, backend: backend);
    await push.configure(_id);
    expect(push.available, isTrue);
    expect(backend.startedWith, _id);
    expect(prefs.containsKey(PushController.guardKey), isFalse);
  });

  test('if the last start never finished, push is paused and the app is left alone', () async {
    final prefs = await _prefs({PushController.guardKey: 1});
    final backend = MemoryPushBackend();
    final push = PushController(prefs, backend: backend);
    await push.configure(_id);
    expect(push.available, isFalse);
    expect(backend.startCalls, 0);
    expect(prefs.containsKey(PushController.guardKey), isFalse);
    expect(prefs.getInt(PushController.pausedUntilKey), greaterThan(DateTime.now().millisecondsSinceEpoch));

    // still paused on the next launch
    final again = PushController(prefs, backend: backend);
    await again.configure(_id);
    expect(backend.startCalls, 0);
  });

  test('after the pause it tries again', () async {
    final prefs = await _prefs({PushController.pausedUntilKey: 1});
    final backend = MemoryPushBackend();
    final push = PushController(prefs, backend: backend);
    await push.configure(_id);
    expect(push.available, isTrue);
  });

  test('a start that throws clears the guard', () async {
    final prefs = await _prefs({});
    final backend = MemoryPushBackend()..failing = true;
    final push = PushController(prefs, backend: backend);
    await push.configure(_id);
    expect(push.available, isFalse);
    expect(prefs.containsKey(PushController.guardKey), isFalse);
  });
}
