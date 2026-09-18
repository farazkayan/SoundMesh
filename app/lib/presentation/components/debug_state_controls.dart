import 'package:flutter/material.dart';

/// DEV-ONLY / SCAFFOLDING widget — DISABLED in Phase 4+.
///
/// This widget was used during Phase 3 to manually drive state transitions
/// via [FakeCoreStateSource.transitionTo()]/[resetToIdle()].
///
/// In Phase 4, the real [CoreApiAdapter] drives state through genuine
/// Core API operations (createRoom, joinRoom, leaveRoom, startCapture, etc.).
/// The adapter's [transitionTo()]/[resetToIdle()] intentionally throw
/// (they are dev-only stubs), so this widget would crash on tap.
///
/// This widget is slated to return in **Phase 21 (UI Mocking and Contract
/// Validation)** with a proper mock/production separation — a mock
/// [CoreStateSource] that implements the full interface without throwing.
///
/// Do not delete this file; keep it as a placeholder for Phase 21.
class DebugStateControls extends StatelessWidget {
  const DebugStateControls({super.key});

  @override
  Widget build(BuildContext context) {
    // Completely inert — does not render, does not crash.
    // In Phase 21, this will be re-enabled with a mock CoreStateSource.
    return const SizedBox.shrink();
  }
}
