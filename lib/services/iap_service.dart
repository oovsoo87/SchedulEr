import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:scheduler/providers/plan_provider.dart';

// The Product ID you will set up in the Google Play Console.
const String _proUpgradeId = 'scheduler_pro_upgrade';

// Provider for our IAP Service
final iapServiceProvider = Provider((ref) => IAPService(ref));

class IAPService {
  final Ref _ref;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  IAPService(this._ref) {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Handle errors here.
    });
  }

  Future<void> init() async {
    await _inAppPurchase.isAvailable();
  }

  Future<void> buyProUpgrade() async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_proUpgradeId});
    if (response.notFoundIDs.isNotEmpty) {
      // Handle the error if the product is not found in the Play Store.
      print('Product not found: ${_proUpgradeId}');
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    // Use buyNonConsumable for a one-time upgrade.
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        _handleSuccessfulPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print("Purchase Error: ${purchaseDetails.error!}");
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.productID == _proUpgradeId) {
      // 1. Upgrade the user's plan by calling our provider.
      await _ref.read(planProvider.notifier).upgradeToPro();

      // 2. Mark the purchase as complete with the Play Store.
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}