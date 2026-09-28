import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:soundmesh/application/purchases/purchase_service.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/index.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerInfoAsync = ref.watch(initialCustomerInfoProvider);
    final customerInfoStream = ref.watch(customerInfoStreamProvider);

    return Scaffold(
      backgroundColor: TSXColors.background,
      body: customerInfoAsync.when(
        data: (initialInfo) => _SupportContent(
          initialCustomerInfo: initialInfo,
          customerInfoStream: customerInfoStream,
        ),
        loading: () => Center(
          child: SMLoadingIndicator.tsx(size: 48),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Failed to load: $error',
            style: TSXTypography.bodyMedium.copyWith(
              color: TSXColors.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportContent extends ConsumerStatefulWidget {
  const _SupportContent({
    required this.initialCustomerInfo,
    required this.customerInfoStream,
  });

  final CustomerInfo initialCustomerInfo;
  final AsyncValue<CustomerInfo> customerInfoStream;

  @override
  ConsumerState<_SupportContent> createState() =>
      _SupportContentState();
}

class _SupportContentState extends ConsumerState<_SupportContent> {
  late CustomerInfo _customerInfo;

  bool _isLoading = false;
  bool _tipFeedbackVisible = false;

  String _restoreState = 'idle';

  @override
  void initState() {
    super.initState();
    _customerInfo = widget.initialCustomerInfo;
  }

  @override
  void didUpdateWidget(covariant _SupportContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final streamValue = widget.customerInfoStream;

    if (streamValue is AsyncData<CustomerInfo>) {
      _customerInfo = streamValue.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TSXColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const RadialGradientBackdrop(),
            LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 420 : double.infinity,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : TSXSpacing.xl,
                          vertical: TSXSpacing.xl,
                        ),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final purchaseService = ref.read(purchaseServiceProvider);
    final isPro = purchaseService.isProActive(_customerInfo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with back button
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.home,
                  (route) => false,
                ),
                borderRadius: BorderRadius.circular(TSXRadius.full),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TSXColors.surface,
                    borderRadius: BorderRadius.circular(TSXRadius.full),
                    border: Border.all(
                      color: TSXColors.surfaceBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: TSXColors.primaryText,
                  ),
                ),
              ),
            ),
            SizedBox(width: TSXSpacing.sm),
            Text(
              'Support',
              style: TSXTypography.headlineMedium,
            ),
          ],
        ),

        SizedBox(height: TSXSpacing.xl),

        // Card 1: Support SoundMesh
        SMCard.tsx(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SUPPORT SOUNDMESH',
                style: TSXTypography.metadata,
              ),

              SizedBox(height: TSXSpacing.lg),

              Text(
                'SoundMesh is free and always will be. If you find it useful, consider a tip to support independent development.',
                style: TSXTypography.bodyMedium,
              ),

              SizedBox(height: TSXSpacing.xl),

              if (isPro) ...[
                _buildSupporterBadge(),

                SizedBox(height: TSXSpacing.lg),

                Text(
                  'Thank you for supporting SoundMesh!',
                  style: TSXTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: TSXSpacing.lg),
              ] else ...[
                SMButton(
                  text: 'Support SoundMesh',
                  icon: Icons.favorite_outline,
                  variant: SMButtonVariant.tsxPrimary,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleTip,
                ),

                SizedBox(height: TSXSpacing.md),
              ],

              // Restore Purchases
              TextButton(
                onPressed: _isLoading ? null : _handleRestore,
                child: Text(
                  _restoreState == 'syncing'
                      ? 'Syncing Mesh...'
                      : 'Restore Purchases',
                  style: TSXTypography.labelMedium.copyWith(
                    color: _isLoading
                        ? TSXColors.mutedText
                        : TSXColors.secondaryText,
                  ),
                ),
              ),

              if (_tipFeedbackVisible) ...[
                SizedBox(height: TSXSpacing.md),

                Container(
                  padding: EdgeInsets.all(TSXSpacing.md),
                  decoration: BoxDecoration(
                    color: TSXColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(TSXRadius.md),
                    border: Border.all(
                      color: TSXColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: TSXColors.success,
                          ),
                          SizedBox(width: TSXSpacing.sm),
                          Text(
                            'Mesh channel linked • Thank you!',
                            style: TSXTypography.metadata.copyWith(
                              color: TSXColors.success,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'NODE#8092',
                        style: TSXTypography.metadata.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: TSXSpacing.xl),

        // Card 2: About
        SMCard.tsx(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ABOUT',
                style: TSXTypography.metadata,
              ),

              SizedBox(height: TSXSpacing.lg),

              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: TSXColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(
                        TSXRadius.md,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.graphic_eq,
                        size: 24,
                        color: TSXColors.accent,
                      ),
                    ),
                  ),

                  SizedBox(width: TSXSpacing.md),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SoundMesh',
                          style: TSXTypography.headlineLarge.copyWith(
                            fontSize: 24,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Version 1.0.0',
                          style: TSXTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: TSXSpacing.md),

              Text(
                'Make your phones one speaker.',
                style: TSXTypography.bodyMedium,
              ),

              SizedBox(height: TSXSpacing.lg),

              Divider(
                color: TSXColors.surfaceBorder,
                height: 1,
              ),

              SizedBox(height: TSXSpacing.lg),

              Text(
                'SoundMesh synchronizes audio playback across nearby devices using local networking. No cloud, no accounts, no tracking.',
                style: TSXTypography.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupporterBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: TSXSpacing.xl,
        vertical: TSXSpacing.md,
      ),
      decoration: BoxDecoration(
        color: TSXColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(TSXRadius.full),
        border: Border.all(
          color: TSXColors.accent.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            color: TSXColors.accent,
            size: TSXSpacing.xl,
          ),
          SizedBox(width: TSXSpacing.sm),
          Text(
            'Supporter',
            style: TSXTypography.headlineMedium.copyWith(
              color: TSXColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Direct RevenueCat purchase.
  ///
  /// No tip/amount picker.
  /// Only the explicitly configured `support_soundmesh`
  /// product can be purchased.
  Future<void> _handleTip() async {
    setState(() {
      _isLoading = true;
      _tipFeedbackVisible = false;
    });

    try {
      final purchaseService = ref.read(purchaseServiceProvider);

      final offerings = await purchaseService.getOfferings();

      if (offerings == null || offerings.current == null) {
        throw StateError(
          'No RevenueCat offering is currently available.',
        );
      }

      final currentOffering = offerings.current!;

      final matchingPackages =
          currentOffering.availablePackages.where(
        (package) =>
            package.storeProduct.identifier ==
            'support_soundmesh',
      );

      if (matchingPackages.isEmpty) {
        throw StateError(
          'The RevenueCat product "support_soundmesh" '
          'is not available in the current offering.',
        );
      }

      final package = matchingPackages.first;

      final customerInfo =
          await purchaseService.purchasePackage(package);

      if (!mounted) return;

      final isPro =
          purchaseService.isProActive(customerInfo);

      setState(() {
        _customerInfo = customerInfo;
        _isLoading = false;
        _tipFeedbackVisible = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro
                ? 'Thank you for supporting SoundMesh!'
                : 'Thank you for supporting SoundMesh!',
          ),
          backgroundColor: TSXColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _tipFeedbackVisible = false;
          });
        }
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      final errorCode =
          PurchasesErrorHelper.getErrorCode(e);

      setState(() {
        _isLoading = false;
      });

      if (errorCode ==
          PurchasesErrorCode.purchaseCancelledError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Purchase was cancelled.',
            ),
            backgroundColor: TSXColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _tipFeedbackVisible = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase failed: ${e.message ?? 'Unknown error'}',
          ),
          backgroundColor: TSXColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _tipFeedbackVisible = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to complete support purchase: $e',
          ),
          backgroundColor: TSXColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _restoreState = 'syncing';
    });

    try {
      final purchaseService =
          ref.read(purchaseServiceProvider);

      final customerInfo =
          await purchaseService.restorePurchases();

      if (!mounted) return;

      setState(() {
        _customerInfo = customerInfo;
        _isLoading = false;
        _restoreState = 'done';
      });

      final isPro =
          purchaseService.isProActive(customerInfo);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro
                ? 'Purchases restored. Thank you for your support!'
                : 'No purchases to restore.',
          ),
          backgroundColor: TSXColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _restoreState = 'idle';
          });
        }
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _restoreState = 'idle';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restore failed: ${e.message ?? 'Unknown error'}',
          ),
          backgroundColor: TSXColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _restoreState = 'idle';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred: $e',
          ),
          backgroundColor: TSXColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}