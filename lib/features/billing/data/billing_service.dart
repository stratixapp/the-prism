// lib/features/billing/data/billing_service.dart
// Phase 22 — Google Play Billing v6

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/constants/app_constants.dart';

const _kProductIds = {
  AppConstants.playProductPro,
  AppConstants.playProductTeam,
};

class BillingResult {
  final bool success;
  final String? error;
  final String? plan;
  const BillingResult({required this.success, this.error, this.plan});
  factory BillingResult.ok(String plan) =>
      BillingResult(success: true, plan: plan);
  factory BillingResult.fail(String error) =>
      BillingResult(success: false, error: error);
}

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _results = StreamController<BillingResult>.broadcast();
  Stream<BillingResult> get results => _results.stream;

  Future<void> init() async {
    if (!await _iap.isAvailable()) return;
    _sub = _iap.purchaseStream.listen(_onPurchases);
  }

  Future<List<ProductDetails>> loadProducts() async {
    if (!await _iap.isAvailable()) return [];
    final r = await _iap.queryProductDetails(_kProductIds);
    return r.productDetails;
  }

  Future<void> purchase(ProductDetails product) async {
    await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restore() async => _iap.restorePurchases();

  Future<void> _onPurchases(
      List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        final valid = await _validate(p);
        if (valid) {
          final plan = p.productID == AppConstants.playProductTeam
              ? AppConstants.planTeam
              : AppConstants.planPro;
          await _savePlan(plan);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _results.add(BillingResult.ok(plan));
        } else {
          _results.add(BillingResult.fail('Receipt validation failed'));
        }
      } else if (p.status == PurchaseStatus.error) {
        _results.add(BillingResult.fail(
            p.error?.message ?? 'Purchase error'));
      } else if (p.status == PurchaseStatus.canceled) {
        _results.add(BillingResult.fail('Cancelled'));
      }
    }
  }

  Future<bool> _validate(PurchaseDetails p) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(true);
      if (token == null) return false;

      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/billing/validate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': p.productID,
          'purchaseToken':
              p.verificationData.serverVerificationData,
          'platform': defaultTargetPlatform.name,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map)['valid'] == true;
      }
      return false;
    } catch (_) {
      return kDebugMode; // fail closed in prod, pass in debug
    }
  }

  Future<void> _savePlan(String plan) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection(AppConstants.colUsers).doc(uid).update({
      AppConstants.fieldPlan: plan,
      AppConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
    });
  }

  void dispose() {
    _sub?.cancel();
    _results.close();
  }
}
