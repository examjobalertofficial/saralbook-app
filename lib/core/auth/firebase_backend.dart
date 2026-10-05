import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_backend.dart';

/// Optional: pass `--dart-define=GOOGLE_WEB_CLIENT_ID=...` if google-services.json
/// has no web client. Normally not needed.
const String _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// Real sign-in: Google account -> Firebase Authentication.
class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend._(this._auth) : isConfigured = _auth != null;

  final FirebaseAuth? _auth;

  @override
  final bool isConfigured;

  /// Never throws. If Firebase is not configured in this build the result
  /// reports `isConfigured == false` and the app hides sign-in gracefully.
  static Future<FirebaseAuthBackend> create() async {
    try {
      await Firebase.initializeApp();
      await GoogleSignIn.instance.initialize(
        serverClientId: _webClientId.isEmpty ? null : _webClientId,
      );
      return FirebaseAuthBackend._(FirebaseAuth.instance);
    } catch (_) {
      return FirebaseAuthBackend._(null);
    }
  }

  static AppUser? _map(User? u) => u == null
      ? null
      : AppUser(
          uid: u.uid,
          name: u.displayName ?? '',
          email: u.email ?? '',
          photoUrl: u.photoURL,
        );

  @override
  AppUser? get currentUser => _map(_auth?.currentUser);

  @override
  Stream<AppUser?> get userChanges =>
      _auth?.authStateChanges().map(_map) ?? Stream<AppUser?>.empty();

  @override
  Future<AppUser> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) throw const AuthFailedException('not-configured');
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthFailedException('no-id-token');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await auth.signInWithCredential(credential);
      final user = _map(result.user);
      if (user == null) throw const AuthFailedException('no-user');
      return user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthFailedException(e.code.name);
    } on FirebaseAuthException catch (e) {
      throw AuthFailedException(e.code);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {/* still sign out of Firebase below */}
    await _auth?.signOut();
  }
}
