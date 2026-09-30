import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:soundmesh/application/purchases/purchase_service.dart';

void main() {
  group('PurchaseService', () {
    late PurchaseService purchaseService;

    setUp(() {
      purchaseService = PurchaseService();
    });

    group('isProActive', () {
      test('returns true when pro entitlement is active', () {
        final customerInfo = _createCustomerInfo(isPro: true);
        expect(purchaseService.isProActive(customerInfo), isTrue);
      });

      test('returns false when pro entitlement is not active', () {
        final customerInfo = _createCustomerInfo(isPro: false);
        expect(purchaseService.isProActive(customerInfo), isFalse);
      });

      test('returns false when entitlements map is empty', () {
        final customerInfo = _createCustomerInfo(isPro: false);
        expect(purchaseService.isProActive(customerInfo), isFalse);
      });

      test('returns false when pro entitlement exists but is not active', () {
        final customerInfo = _createCustomerInfoWithInactivePro();
        expect(purchaseService.isProActive(customerInfo), isFalse);
      });
    });
  });
}

CustomerInfo _createCustomerInfo({required bool isPro}) {
  final activeEntitlements = <String, EntitlementInfo>{};
  final allEntitlements = <String, EntitlementInfo>{};
  
  final now = DateTime.now().toIso8601String();
  final proEntitlement = EntitlementInfo(
    'pro',
    isPro,
    false,
    now,
    now,
    'support_soundmesh',
    true,
    ownershipType: OwnershipType.purchased,
    store: Store.playStore,
    periodType: PeriodType.normal,
    expirationDate: null,
    unsubscribeDetectedAt: null,
    billingIssueDetectedAt: null,
    productPlanIdentifier: null,
    verification: VerificationResult.notRequested,
  );
  
  allEntitlements['pro'] = proEntitlement;
  if (isPro) {
    activeEntitlements['pro'] = proEntitlement;
  }

  return CustomerInfo(
    EntitlementInfos(allEntitlements, activeEntitlements),
    {},
    [],
    [],
    [],
    now,
    'test_user',
    {},
    now,
    latestExpirationDate: null,
    originalPurchaseDate: now,
    originalApplicationVersion: '1.0.0',
    managementURL: null,
    subscriptionsByProductIdentifier: {},
  );
}

CustomerInfo _createCustomerInfoWithInactivePro() {
  final now = DateTime.now().toIso8601String();
  final past = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
  final proEntitlement = EntitlementInfo(
    'pro',
    false,
    false,
    now,
    now,
    'support_soundmesh',
    true,
    ownershipType: OwnershipType.purchased,
    store: Store.playStore,
    periodType: PeriodType.normal,
    expirationDate: past,
    unsubscribeDetectedAt: null,
    billingIssueDetectedAt: null,
    productPlanIdentifier: null,
    verification: VerificationResult.notRequested,
  );
  
  return CustomerInfo(
    EntitlementInfos({'pro': proEntitlement}, {}),
    {},
    [],
    [],
    [],
    now,
    'test_user',
    {},
    now,
    latestExpirationDate: past,
    originalPurchaseDate: now,
    originalApplicationVersion: '1.0.0',
    managementURL: null,
    subscriptionsByProductIdentifier: {},
  );
}