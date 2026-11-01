import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import '../data/secret_store.dart';
import '../util/redact.dart';
import 'google_desktop_auth.dart';

/// Google sign-in could not be completed.
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message, {this.needsSignIn = false});

  final String message;

  /// True when the answer is "sign in again" rather than "something is broken"
  /// — a revoked grant, or an account that was never authorised for this scope.
  final bool needsSignIn;

  @override
  String toString() => message;
}

/// A Google account and a token for it.
typedef GoogleCredential = ({String email, String token, String? name});

/// Signing in with Google.
///
/// Gmail still speaks IMAP and SMTP, but it stopped accepting app passwords in
/// 2022. The protocols are authenticated with an OAuth access token instead, by
/// SASL XOAUTH2 — which is the whole reason this exists: without it, Gmail is a
/// provider this app cannot offer at all.
///
/// Tokens are cached per address in the platform keychain for a short
/// reconnect window. Passwords and refresh tokens are never stored on mobile.
/// Consent is Google's screen, and the grant can be revoked from the account
/// page.
/// The scope is the full-access one because that is what XOAUTH2 needs: Google
/// offers no narrower grant that lets a client read *and* send mail over IMAP
/// and SMTP. It is a restricted scope, so the consent screen has to list it and
/// the account has to be a test user until the app is verified.
/// What a read found: a value, or a keychain that would not answer.
///
/// Three answers, not two. "There is no token" and "the keychain would not
/// answer" used to be the same null, which is how a locked or unavailable
/// credential store became a sign-in prompt — the app could not tell a person
/// who had never signed in from a device that could not remember.
typedef _Read = ({String? value, bool unavailable});

abstract final class GoogleAuth {
  /// The OAuth client this build is registered under.
  ///
  /// From the build rather than from the source, like the desktop client
  /// already was: one configuration story for both platforms, and a fork can
  /// point at its own Cloud project without editing a Dart file. The default is
  /// this project's **web** client ID, which is what Android's Credential
  /// Manager wants as `serverClientId` when the app is not configured through a
  /// `google-services.json`. The Android client that matches this app is
  /// registered against the package name and the signing certificate instead —
  /// see the README.
  static const String clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '919591212641-7m696qr165fh1ir4uo6d761jn7nnk4kg.apps.googleusercontent.com',
  );

  /// IMAP and SMTP, read and send.
  static const List<String> scopes = <String>['https://mail.google.com/'];

  static Future<void>? _prepareFuture;

  /// Linux and Windows have no `google_sign_in` implementation, so there the
  /// sign-in happens in the browser instead. Same answers, different road.
  static bool get _desktop =>
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// Prepares the plugin. Once, before anything else touches it.
  static Future<void> _prepare() => _prepareFuture ??= _initialize();

  static Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(serverClientId: clientId);
      // Restore the accounts the device already knows about, before anything
      // asks for a token.
      //
      // Without this the map below is empty on every cold start — it is memory,
      // and memory does not survive the app being killed. The only thing left to
      // try is the stored token, and a token lives an hour, so reopening the app
      // later found nothing usable and asked again. That is the whole bug.
      await _restoreAccounts();
    } catch (_) {
      // A failed initialization is not a successful one. Clear the cached
      // future so a transient platform failure does not poison every retry.
      _prepareFuture = null;
      rethrow;
    }
  }

  /// Puts the device's already-signed-in accounts back into [_remembered].
  ///
  /// A silent attempt: it can only return an account that is already granted,
  /// and never shows anything. Null is the normal answer on a device with none,
  /// and every route after it — the stored token, the sign-in screen — still
  /// works, so a failure here is nothing to report.
  static Future<void> _restoreAccounts() async {
    try {
      final GoogleSignInAccount? restored =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (restored != null) {
        _remembered[restored.email.toLowerCase()] = restored;
      }
    } catch (_) {
      // Nothing to restore. Not an error.
    }
  }

  /// Where the signed-in account's address and name are kept.
  ///
  /// The desktop path has always cached these; the mobile path asked the plugin
  /// every time, and that call can **prompt**. `attemptLightweightAuthentication`
  /// is documented as minimal-interaction, but its implementation falls through
  /// to a second attempt with `autoSelectEnabled: false` when nothing can be
  /// auto-selected — which shows the Credential Manager picker. So a lookup that
  /// is supposed to be silent could put a sheet on screen when the app opened,
  /// before anybody had touched anything.
  ///
  /// A cached answer cannot prompt, and it is the only answer needed: the
  /// greeting wants the name of the account that is signed in, and if none is,
  /// there is no name to want.
  static const String _keyEmail = 'ace.google.email';
  static const String _keyToken = 'ace.google.token';
  static const String _keyTokenAt = 'ace.google.tokenAt';
  static const String _keyName = 'ace.google.name';

  static String _tokenKey(String email, {bool issuedAt = false}) =>
      '${issuedAt ? _keyTokenAt : _keyToken}.${email.trim().toLowerCase()}';

  /// Clears process state between isolated tests. Production sign-out uses
  /// [forget], which also clears persisted credentials.
  @visibleForTesting
  static void resetForTesting() {
    _remembered.clear();
    _prepareFuture = null;
    storage = const KeychainSecretStore();
  }

  /// Accounts restored by the plugin, keyed by normalized email so one
  /// account can refresh without prompting or replacing another account.
  static final Map<String, GoogleSignInAccount> _remembered =
      <String, GoogleSignInAccount>{};

  /// The access token, and when it was issued.
  ///
  /// Google's live an hour. This is what a fresh launch uses, because the
  /// alternative is asking the plugin for the account — and that call tries
  /// quietly and then *prompts* when nothing can be auto-selected, which on a
  /// device with two Google accounts is every time. A sheet that appears while
  /// somebody is opening a folder is a sheet they did not ask for.
  static const Duration _tokenLife = Duration(minutes: 50);

  /// The keychain. Swappable so a test can make it fail on purpose — the paths
  /// that matter most here are the ones where storage does not work, and they
  /// cannot be reached through the real one.
  @visibleForTesting
  static SecretStore storage = const KeychainSecretStore();

  static Future<_Read> _read(String key) async {
    try {
      final String? value = await storage.read(key);
      return (
        value: (value == null || value.isEmpty) ? null : value,
        unavailable: false,
      );
    } catch (error) {
      debugPrint('Ace Mail: could not read $key (${Redact.safe(error)})');
      return (value: null, unavailable: true);
    }
  }

  /// Writes, and says whether it worked.
  ///
  /// It used to swallow the failure, which made a cache that never persisted
  /// look exactly like one that did — until the next launch, when it looked
  /// like a sign-in nobody had asked for. The caller decides what a failure
  /// means; this only reports it.
  static Future<bool> _write(String key, String value) async {
    try {
      await storage.write(key, value);
      return true;
    } catch (error) {
      debugPrint('Ace Mail: could not persist $key (${Redact.safe(error)})');
      return false;
    }
  }

  static Future<void> _delete(String key) async {
    try {
      await storage.delete(key);
    } catch (error) {
      debugPrint('Ace Mail: could not clear $key (${Redact.safe(error)})');
    }
  }

  /// The name Google has for the signed-in account, if there is one.
  ///
  /// Free — it comes back with the lightweight sign-in — and it is the only
  /// provider here that can say what to call somebody without being asked.
  static Future<String?> knownName() async {
    if (_desktop) return GoogleDesktopAuth.knownName();
    return (await _read(_keyName)).value;
  }

  /// Asks the user to choose an account and consent, and returns a token.
  ///
  /// **This is the sheet people recognise**: Credential Manager's bottom sheet
  /// with "Sign in with Google" on it. Underneath it is
  /// `GetSignInWithGoogleOption`, which the plugin sends when `useButtonFlow`
  /// is true — and `authenticate` is the method that sends it.
  ///
  /// It was briefly preceded by `attemptLightweightAuthentication`, on the
  /// theory that the passkey picker was the modern one. That call sends
  /// `useButtonFlow: false` and gets `GetGoogleIdOption` instead: the generic
  /// credential chooser, which lists whatever credentials the device happens to
  /// hold and is not the Google sign-in experience at all. Asking for it first
  /// meant the wrong sheet appeared, and then the right one on top of it.
  ///
  /// One sheet, and it is Google's.
  static Future<GoogleCredential> signIn() async {
    if (_desktop) return GoogleDesktopAuth.signIn();
    try {
      await _prepare();

      // No scopeHint here, deliberately.
      //
      // authenticate() is Credential Manager's *button* flow
      // (GetSignInWithGoogleOption), and that flow answers one question: who
      // are you. Handing it `https://mail.google.com/` — a restricted Gmail
      // scope — makes the consent request it sends invalid, and the sheet
      // closes with `canceled`. The app then reported "Sign-in was cancelled"
      // for a sign-in nobody had cancelled, which is what the banner on the
      // mailbox was.
      //
      // The mail scope is asked for separately, by
      // authorizationClient.authorizeScopes inside _tokenFor, which is the call
      // that is actually allowed to request it.
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();
      // Kept, so the greeting and the account row never have to ask the plugin
      // anything — asking is what can prompt.
      _remembered[account.email.toLowerCase()] = account;
      await _write(_keyEmail, account.email);
      final String? display = account.displayName?.trim();
      if (display != null && display.isNotEmpty) {
        await _write(_keyName, display);
      }
      // Signed in as somebody, but the mail scope is a second, separate
      // consent. If it is refused the account is still known — the greeting can
      // use the name — but there is no token, and saying which of the two steps
      // failed is the difference between "try again" and "the app is broken".
      final String token;
      try {
        token = await _tokenFor(account, allowPrompt: true);
      } on GoogleAuthException catch (error) {
        throw GoogleAuthException(
          '${error.message} Ace Mail needs permission to read your mail — '
          'tick the Gmail box on the consent screen.',
          needsSignIn: true,
        );
      }
      // Kept per address, so a restart inside the hour does not have to ask
      // anybody — and so signing into a second account does not throw this one
      // away.
      // Reported, not assumed. If the keychain will not take the cache the
      // sign-in still stands — the plugin can mint another token — but nothing
      // here claims a cache that is not there.
      final bool cached = await _write(_tokenKey(account.email), token) &
          await _write(_tokenKey(account.email, issuedAt: true), DateTime.now().toIso8601String());
      if (!cached) {
        debugPrint('Ace Mail: the Google token cache was not saved.');
      }
      final String? name = account.displayName?.trim();
      return (
        email: account.email,
        token: token,
        name: (name == null || name.isEmpty) ? null : name,
      );
    } on GoogleSignInException catch (error) {
      // The code, the description and nothing else. Not a credential, not an
      // address — this is the one line that makes "it does not work" into
      // something that can be looked up.
      debugPrint(
        'Ace Mail: Google sign-in failed — code=${error.code.name} '
        'description=${error.description ?? '(none)'}',
      );
      throw GoogleAuthException(describe(error));
    } on PlatformException catch (error) {
      debugPrint('Ace Mail: Google sign-in channel failed (${Redact.safe(error)}).');
      throw const GoogleAuthException('Google sign-in could not reach the platform service. Try again.');
    }
  }

  /// A fresh token for the account already signed in.
  ///
  /// Returns null when there is no signed-in account. Throws with
  /// [GoogleAuthException.needsSignIn] when there is one but the grant no
  /// longer covers the scope, so the screen can offer the sign-in again rather
  /// than an error nobody can act on.
  /// A token for the account already signed in, **without asking anybody**.
  ///
  /// This is the reconnect path — opening a folder, fetching a page — and it
  /// runs without a person watching it. Every route here is silent: the
  /// session's own account, the stored token, or nothing at all.
  ///
  /// It used to fall back to the plugin, on the reasoning that a device with an
  /// address on file must have an account to find. It does — but finding it
  /// *prompts* when more than one Google account is on the device, because the
  /// quiet attempt cannot choose between them. So opening the app put a
  /// "Signing you in" sheet on screen every time, which is exactly the thing
  /// this path is not allowed to do.
  ///
  /// Null means the app needs a sign-in it cannot perform by itself, and the
  /// caller says so. That is a worse sentence than a sheet, and a much better
  /// one than a sheet nobody asked for.
  ///
  /// [email] is required in practice — every caller has one, and the cache is
  /// keyed by address — so an address that is missing or blank answers null
  /// rather than guessing at whoever signed in last. That guess was the last
  /// remaining way to hand one account's token to another.
  static Future<String?> token(String email) async {
    if (_desktop) return GoogleDesktopAuth.token(email);
    final String want = email.trim().toLowerCase();
    if (want.isEmpty) return null;

    try {
      await _prepare();
    } catch (_) {
      // A plugin that will not initialise must not take the stored token with
      // it: the cache is the whole point of this path, and the SDK is only one
      // of the two ways to get a token.
    }

    final GoogleSignInAccount? known = _remembered[want];
    if (known != null) {
      try {
        return await _tokenFor(known, allowPrompt: false);
      } on GoogleAuthException {
        // The remembered account can no longer produce one. Fall through to
        // whatever is stored rather than giving up on the first refusal.
      }
    }

    // Stored per address. One key held one token, so signing into a second
    // account threw the first one's away — and the first then had to ask again.
    final _Read at = await _read(_tokenKey(want, issuedAt: true));
    final _Read stored = await _read(_tokenKey(want));
    if (stored.unavailable || at.unavailable) {
      // The device could not answer. That is a recoverable fault, not a
      // signed-out person: saying "sign in again" here is what turned a
      // keychain hiccup into a login prompt.
      throw const GoogleAuthException(
        'The credential store could not be read. Try again in a moment.',
      );
    }
    final DateTime? issued = DateTime.tryParse(at.value ?? '');
    if (stored.value == null || issued == null) return null;
    if (DateTime.now().difference(issued) > _tokenLife) return null;
    return stored.value;
  }

  /// Clears the cached access tokens.
  ///
  /// One account's, or every one's. Separate from [forget] because removing one
  /// mailbox must not disturb another: the cached tokens are keyed by address,
  /// and only the address being removed should go.
  ///
  /// This is cache cleanup, not sign-out. Nothing here refreshes a token, and
  /// nothing here touches Google's SDK.
  static Future<void> clearCachedTokens({String? email}) async {
    if (_desktop) {
      // Desktop keeps refresh tokens, per account; its own method knows which
      // keys those are.
      return GoogleDesktopAuth.forget(email: email);
    }

    final String? want = email?.trim().toLowerCase();
    if (want != null && want.isNotEmpty) {
      _remembered.remove(want);
      await _delete(_tokenKey(want));
      await _delete(_tokenKey(want, issuedAt: true));
      return;
    }

    _remembered.clear();
    try {
      // Enumerated rather than guessed: the last account's address is not the
      // only one with a cache, and a key nobody knows the name of is a token
      // nobody can delete.
      final Map<String, String> values = await storage.readAll();
      for (final String key in values.keys.toList()) {
        if (key.startsWith('$_keyToken.') || key.startsWith('$_keyTokenAt.')) {
          await _delete(key);
        }
      }
    } catch (error) {
      debugPrint(
        'Ace Mail: could not enumerate cached tokens (${Redact.safe(error)})',
      );
    }
  }

  /// Signs out, so the next connection asks for an account again.
  ///
  /// Every cached token goes with it — the per-address ones included. They used
  /// to survive, so signing out left an hour's worth of usable tokens on the
  /// device, and the next launch could still read mail with them.
  static Future<void> forget() async {
    if (_desktop) return GoogleDesktopAuth.forget();
    await clearCachedTokens();
    await _delete(_keyEmail);
    await _delete(_keyName);
    try {
      // Signed out of the SDK too, so the next sign-in is a choice rather than
      // a remembered account. A plugin that is not initialised throws here and
      // there is nothing to sign out of — deliberately not `_prepare()` first,
      // because preparing restores accounts, and a sign-out must not be the
      // thing that puts a chooser on screen.
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('Ace Mail: Google SDK sign-out skipped (${Redact.safe(error)})');
    }
  }


  /// A token for [account], from the cache if possible.
  ///
  /// [allowPrompt] is false on the reconnect path: a token that needs the user
  /// to look at a screen cannot be fetched from inside a connection, so that
  /// case is reported as needing a sign-in rather than silently opening a
  /// dialog nobody is looking at.
  static Future<String> _tokenFor(
    GoogleSignInAccount account, {
    required bool allowPrompt,
  }) async {
    final GoogleSignInAuthorizationClient client = account.authorizationClient;
    try {
      final GoogleSignInClientAuthorization? held =
          await client.authorizationForScopes(scopes);
      if (held != null) return held.accessToken;

      if (!allowPrompt) {
        throw const GoogleAuthException(
          'Google needs you to sign in again.',
          needsSignIn: true,
        );
      }

      final GoogleSignInClientAuthorization granted =
          await client.authorizeScopes(scopes);
      return granted.accessToken;
    } on GoogleSignInException catch (error) {
      throw GoogleAuthException(describe(error));
    } on PlatformException catch (error) {
      debugPrint('Ace Mail: Google authorization channel failed (${Redact.safe(error)}).');
      throw const GoogleAuthException('Google sign-in could not reach the platform service. Try again.');
    }
  }

  /// What to say about a failure.
  ///
  /// Pure, and separate from the call, so the wording can be tested without a
  /// Google account. The codes that mean "you cancelled" say so; the one that
  /// means the project is misconfigured says what to check, because that is the
  /// failure a developer will actually hit and the plugin's own message does
  /// not point at the cause.
  static String describe(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        // "Cancelled" is what this means when somebody dismissed the sheet —
        // and it is also what Credential Manager reports when it could not
        // produce a credential at all, which is a configuration fault, not a
        // cancellation. Google's own description is the only thing that tells
        // the two apart, so it is kept rather than swallowed.
        final String? detail = error.description?.trim();
        if (detail == null || detail.isEmpty) {
          return 'Sign-in was cancelled. If you did not cancel it, this build is '
              'not registered with Google for this account — the package name '
              'and signing certificate have to be registered in the same Cloud '
              'project as the web client ID.';
        }
        return 'Sign-in was cancelled. (Google said: $detail)';
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was interrupted. Try again.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in needs a screen, and there is not one available.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'This build is not registered with Google. The package name and '
            'the signing certificate have to be registered for this app in the '
            'Google Cloud project, and the client ID has to be a web one.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google refused the request: the project is missing something. '
            'Check that the Gmail API is enabled and that the consent screen '
            'lists the mail scope.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'That account is not the one this mailbox belongs to.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Google sign-in failed. ${error.description ?? ''}'.trim();
    }
  }
}
