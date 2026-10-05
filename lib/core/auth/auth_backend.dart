/// The signed-in person, as the app needs to know them.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  /// First letter for the avatar when there is no photo.
  String get initial {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    return source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
  }

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

class AuthFailedException implements Exception {
  final String code;
  const AuthFailedException(this.code);
  @override
  String toString() => 'AuthFailedException($code)';
}

/// What the app needs from a sign-in system. Firebase implements it for real;
/// tests use a fake. Keeps the rest of the app independent of Firebase.
abstract class AuthBackend {
  /// false when Firebase is not set up in this build (no google-services.json).
  bool get isConfigured;
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;
  Future<AppUser> signInWithGoogle();
  Future<void> signOut();
}

/// Keys for anything stored on the phone for one account only.
/// Example: `scopedKey(uid, 'notes')` -> `u.<uid>.notes`.
String scopedKey(String uid, String key) => 'u.$uid.$key';
