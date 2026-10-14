import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:campusstay/core/errors.dart';

void main() {
  test('network failures are classified specifically', () {
    expect(classify(const SocketException('Failed host lookup')).kind, AppErrorKind.offline);
    expect(classify(TimeoutException('slow')).kind, AppErrorKind.timeout);
  });

  test('auth errors map to their own kinds', () {
    expect(classify(const AuthException('Invalid login credentials')).kind, AppErrorKind.invalidLogin);
    expect(classify(const AuthException('User already registered')).kind, AppErrorKind.emailTaken);
    expect(classify(const AuthException('Email not confirmed')).kind, AppErrorKind.emailNotConfirmed);
    expect(classify(const AuthException('slow down', statusCode: '429')).kind, AppErrorKind.tooManyRequests);
  });

  test('database errors map to their own kinds', () {
    expect(classify(const PostgrestException(message: 'dup', code: '23505')).kind, AppErrorKind.duplicate);
    expect(classify(const PostgrestException(message: 'new row violates row-level security policy', code: '42501')).kind, AppErrorKind.forbidden);
    expect(classify(const PostgrestException(message: 'rate limit: too many messages', code: 'P0001')).kind, AppErrorKind.tooManyRequests);
    expect(classify(const PostgrestException(message: 'listing not available', code: 'P0001')).kind, AppErrorKind.notAvailable);
    expect(classify(const PostgrestException(message: 'account suspended', code: 'P0001')).kind, AppErrorKind.suspended);
  });

  test('unknown errors keep their detail and a reference', () {
    final e = classify(StateError('weird'));
    expect(e.kind, AppErrorKind.unknown);
    expect(e.detail, contains('weird'));
    final i = describe(e);
    expect(i.reference, startsWith('E-'));
    expect(i.technical, contains('weird'));
  });

  test('Net.run times out and returns typed errors', () async {
    await expectLater(Net.run(() => Future<void>.delayed(const Duration(seconds: 2)), timeout: const Duration(milliseconds: 50)),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.timeout)));
    await expectLater(Net.run<void>(() async => throw const SocketException('x')),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.offline)));
  });
}
