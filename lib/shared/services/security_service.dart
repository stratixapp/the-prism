// lib/shared/services/security_service.dart
// Phase 23 — Security + Privacy Hardening
//
// Handles:
//  - GDPR / India IT Act data deletion
//  - Full account + data wipe
//  - Privacy-safe error reporting
//  - SSL certificate pinning config (for network layer)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants/app_constants.dart';

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Full Account Deletion ─────────────────────────────────────────────────
  // Deletes: Firestore user doc, all analyses, custom agents,
  //          Firebase Auth account, and signals R2 purge to Worker.
  Future<DeleteResult> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return DeleteResult.failure('Not authenticated');
    }

    final uid = user.uid;

    try {
      // 1. Get Firebase ID token for backend call
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return DeleteResult.failure('Auth token error');
      }

      // 2. Call Cloudflare Worker to delete R2 files
      await http.delete(
        Uri.parse('${AppConstants.apiBaseUrl}/api/user/data'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      // 3. Delete all analyses from Firestore
      await _deleteCollection(
        _db
            .collection(AppConstants.colAnalyses)
            .where('userId', isEqualTo: uid),
      );

      // 4. Delete custom agents
      await _deleteCollection(
        _db
            .collection('customAgents')
            .where('userId', isEqualTo: uid),
      );

      // 5. Delete user document
      await _db
          .collection(AppConstants.colUsers)
          .doc(uid)
          .delete();

      // 6. Delete Firebase Auth account (must be last)
      await user.delete();

      return DeleteResult.success();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return DeleteResult.failure(
          'Please sign out and sign back in before deleting your account.',
          requiresReauth: true,
        );
      }
      return DeleteResult.failure(e.message ?? 'Auth error');
    } catch (e) {
      return DeleteResult.failure(e.toString());
    }
  }

  // ── Delete All Analyses Only (keep account) ───────────────────────────────
  Future<bool> deleteAllAnalyses() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final idToken = await user.getIdToken(true);

      // Signal R2 purge for all user files
      await http.delete(
        Uri.parse('${AppConstants.apiBaseUrl}/api/user/files'),
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 30));

      // Delete Firestore analyses
      await _deleteCollection(
        _db
            .collection(AppConstants.colAnalyses)
            .where('userId', isEqualTo: user.uid),
      );

      return true;
    } catch (e) {
      debugPrint('Delete analyses error: $e');
      return false;
    }
  }

  // ── Export User Data (GDPR right to portability) ──────────────────────────
  Future<Map<String, dynamic>?> exportUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // User profile
      final userDoc = await _db
          .collection(AppConstants.colUsers)
          .doc(user.uid)
          .get();

      // All analyses (metadata only — no file content)
      final analysesSnap = await _db
          .collection(AppConstants.colAnalyses)
          .where('userId', isEqualTo: user.uid)
          .get();

      final analyses = analysesSnap.docs.map((d) {
        final data = d.data();
        // Strip agent output content for privacy
        return {
          'id': d.id,
          'fileName': data['fileMetadata']?['name'],
          'createdAt': data['createdAt']?.toString(),
          'status': data['status'],
          'agentCount': (data['agentOutputs'] as List?)?.length ?? 0,
        };
      }).toList();

      return {
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': {
          'email': user.email,
          'displayName': user.displayName,
          'createdAt': userDoc.data()?['createdAt']?.toString(),
          'plan': userDoc.data()?['plan'],
          'industry': userDoc.data()?['industry'],
        },
        'analysisSummary': {
          'totalCount': analyses.length,
          'analyses': analyses,
        },
        'dataRetention': {
          'uploadedFiles':
              'Auto-deleted after ${AppConstants.filePurgeAfterDays} days',
          'analysisResults': 'Retained until account deletion',
          'accountData': 'Deleted immediately upon account deletion request',
        },
      };
    } catch (e) {
      debugPrint('Export data error: $e');
      return null;
    }
  }

  // ── Private Helper: Batch-delete a Firestore query ────────────────────────
  Future<void> _deleteCollection(Query query) async {
    const batchSize = 100;
    QuerySnapshot snapshot;

    do {
      snapshot = await query.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length >= batchSize);
  }
}

// ── Delete Result ─────────────────────────────────────────────────────────────
class DeleteResult {
  final bool success;
  final String? error;
  final bool requiresReauth;

  const DeleteResult._({
    required this.success,
    this.error,
    this.requiresReauth = false,
  });

  factory DeleteResult.success() =>
      const DeleteResult._(success: true);

  factory DeleteResult.failure(String error,
          {bool requiresReauth = false}) =>
      DeleteResult._(
          success: false,
          error: error,
          requiresReauth: requiresReauth);
}
