import 'package:equatable/equatable.dart';

/// Base failure class — all errors in The Prism extend this
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

// ── Auth Failures ─────────────────────────────────────────────────────────────
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure()
      : super(message: 'No account found with this email.');
}

class WrongPasswordFailure extends AuthFailure {
  const WrongPasswordFailure()
      : super(message: 'Incorrect password. Please try again.');
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
      : super(message: 'An account with this email already exists.');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure()
      : super(message: 'Password must be at least 8 characters.');
}

class EmailNotVerifiedFailure extends AuthFailure {
  const EmailNotVerifiedFailure()
      : super(message: 'Please verify your email before signing in.');
}

// ── Network Failures ──────────────────────────────────────────────────────────
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code,
  });
}

class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error. Please try again in a moment.',
    super.code,
  });
}

class TimeoutFailure extends Failure {
  const TimeoutFailure()
      : super(message: 'Request timed out. Please try again.');
}

// ── File Failures ─────────────────────────────────────────────────────────────
class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure()
      : super(message: 'File exceeds 50MB limit. Please upload a smaller file.');
}

class UnsupportedFileTypeFailure extends Failure {
  const UnsupportedFileTypeFailure({required String extension})
      : super(message: 'File type .$extension is not supported.');
}

class FileUploadFailure extends Failure {
  const FileUploadFailure({super.message = 'File upload failed. Please try again.'});
}

class FileParseFailure extends Failure {
  const FileParseFailure({super.message = 'Could not extract content from this file.'});
}

// ── Analysis Failures ─────────────────────────────────────────────────────────
class AnalysisFailure extends Failure {
  const AnalysisFailure({
    super.message = 'Analysis failed. Please try again.',
    super.code,
  });
}

class QuotaExceededFailure extends Failure {
  const QuotaExceededFailure()
      : super(
          message:
              'You\'ve used all 3 free analyses this month. Upgrade to Pro for unlimited access.',
          code: 'quota_exceeded',
        );
}

class AgentFailure extends Failure {
  final String agentId;
  const AgentFailure({required this.agentId, required super.message});

  @override
  List<Object?> get props => [agentId, message];
}

// ── Storage Failures ──────────────────────────────────────────────────────────
class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Local storage error.'});
}

// ── Unknown ───────────────────────────────────────────────────────────────────
class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'An unexpected error occurred.'});
}

// ── Extension to map Firebase error codes ────────────────────────────────────
extension FirebaseAuthErrorMapper on String {
  Failure toAuthFailure() {
    switch (this) {
      case 'user-not-found':
        return const UserNotFoundFailure();
      case 'wrong-password':
        return const WrongPasswordFailure();
      case 'email-already-in-use':
        return const EmailAlreadyInUseFailure();
      case 'weak-password':
        return const WeakPasswordFailure();
      case 'invalid-credential':
        return const AuthFailure(message: 'Invalid credentials. Please try again.');
      case 'too-many-requests':
        return const AuthFailure(message: 'Too many attempts. Please wait before trying again.');
      case 'network-request-failed':
        return const NetworkFailure();
      default:
        return AuthFailure(message: 'Authentication error: $this');
    }
  }
}
