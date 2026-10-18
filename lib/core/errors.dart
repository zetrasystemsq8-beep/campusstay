import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every failure the app knows how to explain. Each kind has its own wording.
/// Anything we cannot classify becomes [AppErrorKind.unknown] and keeps its
/// technical detail, so it is never hidden behind a vague message.
enum AppErrorKind {
  offline,
  timeout,
  signInRequired,
  invalidLogin,
  emailTaken,
  emailNotConfirmed,
  weakPassword,
  tooManyRequests,
  forbidden,
  suspended,
  notFound,
  duplicate,
  invalid,
  notAvailable,
  ownListing,
  blocked,
  fileTooLarge,
  codeInvalid,
  voiceUnavailable,
  locationOff,
  locationDenied,
  locationDeniedForever,
  locationUnavailable,
  unsupportedFile,
  notSubmittable,
  server,
  unknown,
}

class AppException implements Exception {
  final AppErrorKind kind;
  final String? detail;
  final Object? cause;
  const AppException(this.kind, {this.detail, this.cause});

  /// Short support reference, stable for the same underlying problem.
  String get reference => 'E-${((detail ?? kind.name).hashCode & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}';

  @override
  String toString() => 'AppException(${kind.name}${detail == null ? '' : ': $detail'})';
}

class ErrorInfo {
  final String title, message;
  final bool retryable;
  final String? reference;
  final String? technical;
  const ErrorInfo(this.title, this.message, {this.retryable = false, this.reference, this.technical});
}

AppException classify(Object e) {
  if (e is AppException) return e;
  if (e is TimeoutException) return AppException(AppErrorKind.timeout, cause: e);
  if (e is SocketException) return AppException(AppErrorKind.offline, cause: e);
  if (e is AuthException) return _auth(e);
  if (e is PostgrestException) return _postgrest(e);
  if (e is StorageException) return _storage(e);
  final text = e.toString();
  // package:http wraps socket failures in its own ClientException.
  if (e.runtimeType.toString() == 'ClientException') {
    final t = text.toLowerCase();
    if (t.contains('socketexception') || t.contains('failed host lookup') || t.contains('connection')) {
      return AppException(AppErrorKind.offline, cause: e);
    }
  }
  if (e is HandshakeException) {
    return AppException(AppErrorKind.offline, detail: 'secure connection failed: check the phone date and time', cause: e);
  }
  return AppException(AppErrorKind.unknown, detail: '${e.runtimeType}: $text', cause: e);
}

AppException _auth(AuthException e) {
  final m = e.message.toLowerCase();
  final s = e.statusCode ?? '';
  if (m.contains('invalid login')) return AppException(AppErrorKind.invalidLogin, cause: e);
  if (m.contains('token') && (m.contains('expired') || m.contains('invalid'))) return AppException(AppErrorKind.codeInvalid, cause: e);
  if (m.contains('already registered') || m.contains('already been registered')) return AppException(AppErrorKind.emailTaken, cause: e);
  if (m.contains('email not confirmed')) return AppException(AppErrorKind.emailNotConfirmed, cause: e);
  if (m.contains('password should') || m.contains('weak password')) return AppException(AppErrorKind.weakPassword, cause: e);
  if (s == '429' || m.contains('rate limit') || m.contains('too many')) return AppException(AppErrorKind.tooManyRequests, cause: e);
  if (s == '401' || m.contains('jwt') || m.contains('sign in') || m.contains('session')) return AppException(AppErrorKind.signInRequired, cause: e);
  return AppException(AppErrorKind.unknown, detail: 'AuthException($s): ${e.message}', cause: e);
}

AppException _postgrest(PostgrestException e) {
  final m = e.message.toLowerCase();
  final c = e.code ?? '';
  if (c == '23505') return AppException(AppErrorKind.duplicate, cause: e);
  if (c == '42501' || m.contains('row-level security') || m.contains('permission denied')) return AppException(AppErrorKind.forbidden, cause: e);
  if (c == 'PGRST116') return AppException(AppErrorKind.notFound, cause: e);
  if (c == '23514' || c == '22P02' || c == '23502') return AppException(AppErrorKind.invalid, cause: e);
  if (c == 'PGRST301' || m.contains('jwt')) return AppException(AppErrorKind.signInRequired, cause: e);
  if (m.contains('sign in required')) return AppException(AppErrorKind.signInRequired, cause: e);
  if (m.contains('account suspended')) return AppException(AppErrorKind.suspended, cause: e);
  if (m.contains('rate limit')) return AppException(AppErrorKind.tooManyRequests, cause: e);
  if (m.contains('listing not available')) return AppException(AppErrorKind.notAvailable, cause: e);
  if (m.contains('your own listing')) return AppException(AppErrorKind.ownListing, cause: e);
  if (m.contains('invalid rating comment')) return AppException(AppErrorKind.invalid, detail: 'Keep your review under 1000 characters.', cause: e);
  if (m.contains('invalid rating')) return AppException(AppErrorKind.invalid, detail: 'Choose 1 to 5 stars.', cause: e);
  if (m.contains('invalid message')) return AppException(AppErrorKind.invalid, detail: 'Messages must be 1 to 2000 characters.', cause: e);
  if (m.contains('unavailable')) return AppException(AppErrorKind.blocked, cause: e);
  if (m.contains('not allowed') || m.contains('forbidden')) return AppException(AppErrorKind.forbidden, cause: e);
  final http = int.tryParse(c);
  if (http != null && http >= 500) return AppException(AppErrorKind.server, cause: e);
  return AppException(AppErrorKind.unknown, detail: 'PostgrestException($c): ${e.message}', cause: e);
}

AppException _storage(StorageException e) {
  final m = e.message.toLowerCase();
  final s = e.statusCode ?? '';
  if (s == '413' || m.contains('exceeded') || m.contains('too large')) return AppException(AppErrorKind.fileTooLarge, cause: e);
  if (s == '415' || m.contains('mime')) return AppException(AppErrorKind.unsupportedFile, cause: e);
  if (s == '403' || m.contains('row-level security') || m.contains('unauthorized')) return AppException(AppErrorKind.forbidden, cause: e);
  if (s == '404') return AppException(AppErrorKind.notFound, cause: e);
  return AppException(AppErrorKind.unknown, detail: 'StorageException($s): ${e.message}', cause: e);
}

ErrorInfo describe(Object error) {
  final e = classify(error);
  switch (e.kind) {
    case AppErrorKind.offline:
      return const ErrorInfo("You're off the grid", "We couldn't reach the internet. Check your data or Wi-Fi, then try again.", retryable: true);
    case AppErrorKind.timeout:
      return const ErrorInfo("That's taking too long", 'The network is moving slowly. Nothing was lost. Give it another go.', retryable: true);
    case AppErrorKind.signInRequired:
      return const ErrorInfo('Please sign in', 'Your session has ended. Log in again to continue.');
    case AppErrorKind.invalidLogin:
      return const ErrorInfo("Hmm, that doesn't match", 'The email or password is incorrect. Check for typos and try again.');
    case AppErrorKind.emailTaken:
      return const ErrorInfo("You're already one of us", 'An account with this email already exists. Try logging in instead.');
    case AppErrorKind.emailNotConfirmed:
      return const ErrorInfo('Confirm your email first', 'We sent you a link. Open it, then log in.');
    case AppErrorKind.weakPassword:
      return const ErrorInfo("Let's make that password stronger", 'Use at least 8 characters, mixing letters and numbers.');
    case AppErrorKind.tooManyRequests:
      return const ErrorInfo('Easy there, speedster', "You're doing that a lot. Wait a few minutes, then try again.");
    case AppErrorKind.forbidden:
      return const ErrorInfo("That one's off limits", "Your account isn't allowed to do that.");
    case AppErrorKind.suspended:
      return const ErrorInfo('Account on hold', 'Your account is suspended. Contact support if you think this is a mistake.');
    case AppErrorKind.notFound:
      return const ErrorInfo("Couldn't find that", 'It may have been rented, removed, or never existed.');
    case AppErrorKind.duplicate:
      return const ErrorInfo('Déjà vu', 'You already have one just like this. A listing with the same title and area already exists.');
    case AppErrorKind.invalid:
      return ErrorInfo('Something needs fixing', e.detail ?? 'Check what you entered and try again.');
    case AppErrorKind.notAvailable:
      return const ErrorInfo('This listing has moved on', 'It was rented, paused or taken down.');
    case AppErrorKind.ownListing:
      return const ErrorInfo("That's your own place", "You can't message yourself about your own listing.");
    case AppErrorKind.blocked:
      return const ErrorInfo("Message can't be sent", "This conversation isn't available.");
    case AppErrorKind.fileTooLarge:
      return const ErrorInfo('That file is a heavyweight', 'Photos must be under 5 MB and documents under 10 MB.');
    case AppErrorKind.codeInvalid:
      return const ErrorInfo("That code didn't work", 'It may have expired or been typed wrong. Ask for a new code and try again.');
    case AppErrorKind.voiceUnavailable:
      return ErrorInfo("Voice typing isn't available", e.detail ?? "This phone can't listen right now. Use the microphone on your keyboard instead, or type it.");
    case AppErrorKind.locationOff:
      return const ErrorInfo('Location is switched off', 'Turn on location (GPS) in your phone settings, then try again.');
    case AppErrorKind.locationDenied:
      return const ErrorInfo('We need your permission', 'Allow CampusStay to use your location for this. You can also move the map by hand.');
    case AppErrorKind.locationDeniedForever:
      return const ErrorInfo('Location is blocked', 'Open your phone settings, allow location for CampusStay, then try again.');
    case AppErrorKind.locationUnavailable:
      return const ErrorInfo("Can't find you right now", 'Move to an open area and try again, or place the pin by hand.', retryable: true);
    case AppErrorKind.unsupportedFile:
      return const ErrorInfo("We can't use that file type", 'Use a JPG, PNG or WebP image.');
    case AppErrorKind.notSubmittable:
      return const ErrorInfo("Can't submit just yet", 'This listing is already under review or live.');
    case AppErrorKind.server:
      return const ErrorInfo('Our side hiccuped', 'Something went wrong on our server. Try again shortly.', retryable: true);
    case AppErrorKind.unknown:
      return ErrorInfo('Something unexpected happened', "This one is new to us. Try again, and if it keeps happening, tell support reference ${e.reference}.",
          retryable: true, reference: e.reference, technical: e.detail);
  }
}

class Net {
  static const normal = Duration(seconds: 15);
  static const upload = Duration(seconds: 60);

  /// Runs [op] with a timeout and turns every failure into a typed [AppException].
  /// Unknown failures are logged with their stack trace and keep their detail.
  static Future<T> run<T>(Future<T> Function() op, {Duration timeout = normal}) async {
    try {
      return await op().timeout(timeout);
    } catch (e, st) {
      final ex = classify(e);
      if (ex.kind == AppErrorKind.unknown) debugPrint('Unclassified error ${ex.reference}: ${ex.detail}\n$st');
      Error.throwWithStackTrace(ex, st);
    }
  }
}
