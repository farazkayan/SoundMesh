import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:soundmesh/application/purchases/purchase_service.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/surface.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerInfoAsync = ref.watch(initialCustomerInfoProvider);
    final customerInfoStream = ref.watch(customerInfoStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: customerInfoAsync.when(
        data: (initialInfo) {
          return _SettingsContent(
            initialCustomerInfo: initialInfo,
            customerInfoStream: customerInfoStream,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Failed to load settings: $error',
            style: SMTypography.body.copyWith(color: SMColors.error),
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends ConsumerStatefulWidget {
  const _SettingsContent({
    required this.initialCustomerInfo,
    required this.customerInfoStream,
  });

  final CustomerInfo initialCustomerInfo;
  final AsyncValue<CustomerInfo> customerInfoStream;

  @override
  ConsumerState<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  late CustomerInfo _customerInfo;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _customerInfo = widget.initialCustomerInfo;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(SMSpacing.xl),
      children: [
        _buildSupportSection(),
        SizedBox(height: SMSpacing.xxl),
        _buildAboutSection(),
      ],
    );
  }

  Widget _buildSupportSection() {
    final isPro = ref.read(purchaseServiceProvider).isProActive(_customerInfo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support SoundMesh',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'SoundMesh is free and always will be. If you find it useful, consider a one-time tip to support development.',
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xl),
        SMCard(
          elevated: true,
          child: Column(
            children: [
              if (isPro) ...[
                _buildSupporterBadge(),
                SizedBox(height: SMSpacing.lg),
                Text(
                  'Thank you for supporting SoundMesh!',
                  style: SMTypography.body.copyWith(color: SMColors.primaryText),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: SMSpacing.lg),
              ] else ...[
                _buildPurchaseButton(),
                SizedBox(height: SMSpacing.md),
              ],
              _buildRestoreButton(),
              if (_errorMessage != null) ...[
                SizedBox(height: SMSpacing.md),
                Text(
                  _errorMessage!,
                  style: SMTypography.caption.copyWith(color: SMColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupporterBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SMSpacing.xl,
        vertical: SMSpacing.md,
      ),
      decoration: BoxDecoration(
        color: SMColors.soundmeshBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SMRadius.full),
        border: Border.all(
          color: SMColors.soundmeshBlue.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            color: SMColors.soundmeshBlue,
            size: SMSpacing.xl,
          ),
          SizedBox(width: SMSpacing.sm),
          Text(
            'Supporter',
            style: SMTypography.heading.copyWith(
              color: SMColors.soundmeshBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return SMButton(
      text: 'Support SoundMesh',
      icon: Icons.favorite_outline,
      variant: SMButtonVariant.secondary,
      isLoading: _isLoading,
      onPressed: _isLoading ? null : _handlePurchase,
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: _isLoading ? null : _handleRestore,
      child: Text(
        'Restore Purchases',
        style: SMTypography.button.copyWith(
          color: _isLoading ? SMColors.disabledText : SMColors.secondaryText,
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      final offerings = await purchaseService.getOfferings();

      if (offerings == null || offerings.current == null) {
        throw Exception('No offerings available. Please check your connection.');
      }

      final package = offerings.current!.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == 'support_soundmesh',
        orElse: () => offerings.current!.availablePackages.first,
      );

      final customerInfo = await purchaseService.purchasePackage(package);

      if (mounted) {
        setState(() {
          _customerInfo = customerInfo;
          _isLoading = false;
        });

        final isPro = purchaseService.isProActive(customerInfo);
        if (isPro) {
          _showSnackBar('Thank you for supporting SoundMesh!');
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final errorCode = PurchasesErrorHelper.getErrorCode(e);
          if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
            _errorMessage = 'Purchase was cancelled.';
          } else {
            _errorMessage = 'Purchase failed: ${e.message}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      final customerInfo = await purchaseService.restorePurchases();

      if (mounted) {
        setState(() {
          _customerInfo = customerInfo;
          _isLoading = false;
        });

        final isPro = purchaseService.isProActive(customerInfo);
        if (isPro) {
          _showSnackBar('Purchases restored. Thank you for your support!');
        } else {
          _showSnackBar('No purchases to restore.');
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Restore failed: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SMColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SoundMesh',
                style: SMTypography.title.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.xs),
              Text(
                'Version 1.0.0',
                style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Make your phones one speaker.',
                style: SMTypography.body.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.lg),
              Divider(color: SMColors.outlineVariant.withValues(alpha: 0.3)),
              SizedBox(height: SMSpacing.md),
              Text(
                'SoundMesh synchronizes audio playback across nearby devices using local networking. No cloud, no accounts, no tracking.',
                style: SMTypography.caption.copyWith(color: SMColors.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}