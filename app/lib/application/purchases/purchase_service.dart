import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  PurchaseService();

  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  Future<Offerings?> getOfferings() async {
    return await Purchases.getOfferings();
  }

  Future<CustomerInfo> purchasePackage(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }

  bool isProActive(CustomerInfo customerInfo) {
    return customerInfo.entitlements.active['pro'] != null;
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService();
});

final customerInfoStreamProvider = StreamProvider<CustomerInfo>((ref) {
  final controller = StreamController<CustomerInfo>();

  Purchases.addCustomerInfoUpdateListener((customerInfo) {
    controller.add(customerInfo);
  });

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});

final initialCustomerInfoProvider = FutureProvider<CustomerInfo>((ref) async {
  return await Purchases.getCustomerInfo();
});