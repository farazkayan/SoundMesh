import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/presentation/components/index.dart';

class RoomCreatedScreen extends ConsumerWidget {
  const RoomCreatedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createState = ref.watch(createRoomFlowProvider);
    final roomName = createState.roomName.isNotEmpty
        ? createState.roomName.toUpperCase()
        : 'LIVING ROOM HUB';
    final joinCode = createState.joinCode ?? '256 - 093';

    return Scaffold(
      backgroundColor: TSXColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar - h-14 (56px)
            _buildHeader(),

            // Main Viewport Container - flex-1, px-5 py-5, justify-between
            Expanded(
              child: Stack(
                children: [
                  const RadialGradientBackdrop(),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Center(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: 384, // max-w-md
                              minHeight: constraints.maxHeight,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20, // px-5
                              vertical: 20,   // py-5
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Hero & Room Code Card
                                _buildTopSection(context, roomName, joinCode),

                                const Spacer(),

                                // Bottom Action Buttons & Footer
                                _buildBottomActions(context, roomName, joinCode, ref),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56, // h-14
      width: double.infinity,
      decoration: const BoxDecoration(
        color: TSXColors.background,
        border: Border(
          bottom: BorderSide(
            color: TSXColors.surfaceBorder,
            width: 1.0,
          ),
        ),
      ),
      child: const Center(
        child: Text(
          'Room Created',
          style: TextStyle(
            fontFamily: TSXTypography.fontFamily,
            fontSize: 18, // text-lg
            fontWeight: FontWeight.w600,
            color: TSXColors.primaryText,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(
    BuildContext context,
    String roomName,
    String roomCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8), // pt-2

        // Hero Status Section
        const TSXPulsingEmblem(size: 52, iconSize: 24), // w-13 h-13 (52px), icon w-6 (24px)
        const SizedBox(height: 12), // mb-3

        const Text(
          'Room is Ready',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TSXTypography.fontFamily,
            fontSize: 24, // text-2xl
            fontWeight: FontWeight.bold,
            color: TSXColors.primaryText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6), // mt-1.5
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280), // max-w-[280px]
          child: const Text(
            'Share the 6-digit code or scan QR to connect nearby devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TSXTypography.fontFamily,
              fontSize: 13,
              height: 1.4,
              color: TSXColors.secondaryText,
            ),
          ),
        ),

        const SizedBox(height: 16), // my-4 top

        // Main Room Code Card - p-4 (16px), space-y-2.5 (10px)
        SMCard.tsx(
          padding: const EdgeInsets.all(16), // p-4
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row - px-0.5 (2px), justify-between
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ROOM NAME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2, // tracking-wider
                        color: TSXColors.secondaryText,
                      ),
                    ),
                    Text(
                      roomName,
                      style: const TextStyle(
                        fontSize: 12, // text-xs
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5, // tracking-wide
                        color: TSXColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10), // space-y-2.5

              // Code Display Box - h-13 (52px), px-3.5 (14px)
              CodeDisplayCard(
                code: roomCode,
                label: '', // Label is in header row
                onCopy: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(
                    ClipboardData(
                      text: roomCode.replaceAll(RegExp(r'\D'), ''),
                    ),
                  );
                },
                helperText: null, // Handled below
                compact: false,
              ),

              const SizedBox(height: 2), // mt-0.5

              // Helper Label
              const Text(
                'Tap code box to copy link',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TSXTypography.fontFamily,
                  fontSize: 11, // text-[11px] sm:text-xs
                  color: TSXColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    String roomName,
    String roomCode,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8), // pt-6 pb-safe handled by SafeArea
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Secondary Tile: Show QR Code - h-12 (48px)
          SizedBox(
            height: 48,
            child: SMButton(
              text: 'Show QR Code',
              icon: Icons.qr_code,
              variant: SMButtonVariant.tsxSecondary,
              onPressed: () => _showQrModal(context, roomName, roomCode, ref),
            ),
          ),
          const SizedBox(height: 12), // mt-3

          // Primary Action Button: Enter Room - h-13 (52px)
          SizedBox(
            height: 52,
            child: SMButton(
              text: 'Enter Room',
              icon: Icons.arrow_forward,
              variant: SMButtonVariant.tsxPrimary,
              onPressed: () => Navigator.pushReplacementNamed(
                context,
                AppRouter.roomDashboard,
              ),
            ),
          ),
          const SizedBox(height: 20), // mt-5

          // Footer Readout
          const Text(
            'LOCAL P2P MESH • HOST NODE ACTIVE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1.5, // tracking-widest
              color: Color(0x9987999A), // text-[#87999A]/60
            ),
          ),
        ],
      ),
    );
  }

  void _showQrModal(
    BuildContext context,
    String roomName,
    String roomCode,
    WidgetRef ref,
  ) {
    final createState = ref.read(createRoomFlowProvider);
    final roomId = createState.roomId;
    final hostIp = createState.localIpAddress;
    final port = createState.port ?? 8765;
    final joinCode = createState.joinCode;

    if (roomId == null || hostIp == null || joinCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room information not ready yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final payload = JoinPayload(
      roomId: roomId,
      hostAddress: hostIp,
      hostPort: port,
      protocolVersion: currentProtocolVersion,
      code: joinCode,
    );

    final uriString = payload.toJoinUri();

    showQrModal(
      context: context,
      title: 'Scan to Join',
      code: roomCode,
      roomName: roomName,
      uriString: uriString,
      onCopy: () {
        Clipboard.setData(ClipboardData(text: uriString));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code URI copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }
}