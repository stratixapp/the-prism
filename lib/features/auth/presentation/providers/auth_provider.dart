import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_errors.dart';
import '../../../../shared/models/user_model.dart';

part 'auth_provider.g.dart';

// ── Firebase instances ────────────────────────────────────────────────────────
@riverpod
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) => FirebaseAuth.instance;

@riverpod
FirebaseFirestore firestore(FirestoreRef ref) => FirebaseFirestore.instance;

// ── Auth State Stream ─────────────────────────────────────────────────────────
@riverpod
Stream<User?> authState(AuthStateRef ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}

// ── Current User Model ────────────────────────────────────────────────────────
@riverpod
Future<PrismUser?> currentUser(CurrentUserRef ref) async {
  final firebaseUser = ref.watch(authStateProvider).valueOrNull;
  if (firebaseUser == null) return null;

  final doc = await ref
      .watch(firestoreProvider)
      .collection(AppConstants.colUsers)
      .doc(firebaseUser.uid)
      .get();

  if (!doc.exists) return null;
  return PrismUser.fromFirestore(doc);
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  FirebaseFirestore get _db => ref.read(firestoreProvider);

  // ── Sign Up with Email ────────────────────────────────────────────────
  Future<Either<Failure, void>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String industry,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;

      // Update display name
      await user.updateDisplayName(displayName);

      // Send verification email
      await user.sendEmailVerification();

      // Create Firestore user document
      await _createUserDocument(
        uid: user.uid,
        email: email,
        displayName: displayName,
        industry: industry,
      );

      state = const AsyncValue.data(null);
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      final failure = (e.code).toAuthFailure();
      state = AsyncValue.error(failure, StackTrace.current);
      return Left(failure);
    } catch (e) {
      final failure = UnknownFailure(message: e.toString());
      state = AsyncValue.error(failure, StackTrace.current);
      return Left(failure);
    }
  }

  // ── Sign In with Email ────────────────────────────────────────────────
  Future<Either<Failure, void>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      final failure = (e.code).toAuthFailure();
      state = AsyncValue.error(failure, StackTrace.current);
      return Left(failure);
    } catch (e) {
      final failure = UnknownFailure(message: e.toString());
      state = AsyncValue.error(failure, StackTrace.current);
      return Left(failure);
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────────
  Future<Either<Failure, bool>> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final googleProvider = GoogleAuthProvider();
      final credential =
          await _auth.signInWithProvider(googleProvider);

      final user = credential.user!;
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        await _createUserDocument(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Prism User',
          industry: 'general',
        );
      }

      state = const AsyncValue.data(null);
      return Right(isNewUser);
    } on FirebaseAuthException catch (e) {
      final failure = (e.code).toAuthFailure();
      state = AsyncValue.error(failure, StackTrace.current);
      return Left(failure);
    } catch (e) {
      state = const AsyncValue.data(null);
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Send Email Verification ───────────────────────────────────────────
  Future<Either<Failure, void>> sendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────
  Future<Either<Failure, void>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(e.code.toAuthFailure());
    }
  }

  // ── Private: Create Firestore user doc ───────────────────────────────
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String displayName,
    required String industry,
  }) async {
    await _db.collection(AppConstants.colUsers).doc(uid).set({
      AppConstants.fieldUid: uid,
      AppConstants.fieldEmail: email,
      AppConstants.fieldDisplayName: displayName,
      AppConstants.fieldPlan: AppConstants.planFree,
      AppConstants.fieldAnalysisCount: 0,
      AppConstants.fieldAnalysisCountResetAt: Timestamp.now(),
      AppConstants.fieldIndustry: industry,
      AppConstants.fieldPreferredAiProvider: AppConstants.aiProviderClaude,
      AppConstants.fieldCreatedAt: FieldValue.serverTimestamp(),
      AppConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
    });
  }
}
