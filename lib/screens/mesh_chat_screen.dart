import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/mesh_provider.dart';
import '../providers/theme_provider.dart';
import '../services/permission_service.dart';
import '../widgets/gradient_background.dart';
import 'widgets/chat_panel.dart';
import 'widgets/nearby_devices_card.dart';

class MeshChatScreen extends StatefulWidget {
  const MeshChatScreen({super.key});

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeshProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshProvider>();
    final theme = Provider.of<ThemeProvider>(context);
    final chatHeight =
        (MediaQuery.sizeOf(context).height * 0.44).clamp(260.0, 460.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Local Mesh Chat',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!mesh.permissionsGranted) ...[
                  const _PermissionBanner(),
                  const SizedBox(height: 12),
                ],
                const NearbyDevicesCard(),
                const SizedBox(height: 14),
                SizedBox(height: chatHeight, child: const ChatPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nearby, Bluetooth and location permissions are required to '
              'find and chat with devices around you.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(
            onPressed: mesh.requestPermissions,
            child: const Text(
              'Grant',
              style: TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'App settings',
            onPressed: PermissionService.openSettings,
            icon: const Icon(Icons.settings, size: 18, color: Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }
}