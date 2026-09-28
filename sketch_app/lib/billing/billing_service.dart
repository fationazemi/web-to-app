import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../settings/app_settings.dart';

/// Store billing for Sketch Pro, built on `in_app_purchase` (App Store and
/// Google Play).
///
/// Products must exist in App Store Connect / Google Play Console with the
/// ids below. Purchases are verified locally; add a server-side receipt
/// check before relying on this for revenue.
class BillingService extends ChangeNotifier {
  BillingService(this._settings, {InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

  static const String monthlyId = 'sketch_pro_monthly';
  static const String lifetimeId = 'sketch_pro_lifetime';
  static const Set<String> productIds = {monthlyId, lifetimeId};

  final AppSettings _settings;
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available = false;
  bool _busy = false;
  String? _error;
  List<ProductDetails> _products = const [];

  /// Whether the device store answered and offers our products.
  bool get available => _available && _products.isNotEmpty;
  bool get busy => _busy;
  String? get error => _error;
  List<ProductDetails> get products => _products;

  ProductDetails? product(String id) => _products.where((p) => p.id == id).firstOrNull;

  Future<void> init() async {
    try {
      _available = await _store.isAvailable();
      if (!_available) {
        notifyListeners();
        return;
      }
      _subscription ??= _store.purchaseStream.listen(_onPurchases, onError: (Object e) {
        _error = e.toString();
        notifyListeners();
      });
      final response = await _store.queryProductDetails(productIds);
      _products = response.productDetails
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      if (response.error != null) _error = response.error!.message;
    } catch (e) {
      _available = false;
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> buy(ProductDetails product) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _store.restorePurchases();
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (productIds.contains(purchase.productID)) _settings.setPro(true);
          _busy = false;
        case PurchaseStatus.error:
          _error = purchase.error?.message ?? 'Purchase failed';
          _busy = false;
        case PurchaseStatus.canceled:
          _busy = false;
        case PurchaseStatus.pending:
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
