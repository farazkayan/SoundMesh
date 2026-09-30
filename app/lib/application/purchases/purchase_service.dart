import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Exception thrown when RevenueCat Purchases SDK is not configured.
class PurchasesNotConfiguredException implements Exception {
  final String message;
  const PurchasesNotConfiguredException(this.message);

  @override
  String toString() => 'PurchasesNotConfiguredException: $message';
}

/// Exception thrown when restore purchases operation fails.
class RestorePurchasesException implements Exception {
  final String message;
  final PurchasesErrorCode? errorCode;
  final dynamic originalError;

  const RestorePurchasesException(
    this.message, {
    this.errorCode,
    this.originalError,
  });

  @override
  String toString() =>
      'RestorePurchasesException: $message${errorCode != null ? ' (code: $errorCode)' : ''}';
}

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

  /// Restores the user's previous purchases.
  ///
  /// Returns the updated [CustomerInfo] on success.
  /// Throws [PurchasesNotConfiguredException] if RevenueCat is not configured.
  /// Throws [RestorePurchasesException] if the restore operation fails.
  Future<CustomerInfo> restorePurchases() async {
    final isConfigured = await Purchases.isConfigured;
    if (!isConfigured) {
      throw const PurchasesNotConfiguredException(
        'RevenueCat Purchases SDK is not configured. '
        'Please wait for initialization to complete.',
      );
    }

    try {
      return await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      throw RestorePurchasesException(
        e.message ?? 'Unknown restore error',
        errorCode: errorCode,
        originalError: e,
      );
    } catch (e) {
      throw RestorePurchasesException(
        'An unexpected error occurred during restore: $e',
        originalError: e,
      );
    }
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