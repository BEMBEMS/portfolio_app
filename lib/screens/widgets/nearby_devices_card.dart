import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/peer_device.dart';
import '../../providers/mesh_provider.dart';
import '../../providers/theme_provider.dart';
import 'status_badge.dart';

class NearbyDevicesCard extends StatelessWidget {
  const NearbyDevicesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshProvider>();
    final theme = Provider.of<ThemeProvider>(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.12),
            theme.textColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nearby Devices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ),
                StatusBadge(connected: mesh.isConnected),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _VisibilityButton(
                    isAdvertising: mesh.isAdvertising,
                    onPressed: mesh.toggleVisibility,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScanButton(
                    isScanning: mesh.isDiscovering,
                    onPressed: mesh.findNearbyDevices,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${mesh.connectedCount}/${MeshProvider.maxDevices} Devices Connected',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ),
                _DisconnectAllButton(
                  enabled: mesh.isConnected && !mesh.isBusy,
                  onPressed: mesh.disconnectAll,
                ),
              ],
            ),
            if (mesh.connectedDevices.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final device in mesh.connectedDevices)
                    _ConnectedChip(
                      device: device,
                      isActive: device.id == mesh.activePeer?.id,
                      onTap: () => mesh.selectPeer(device.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'AVAILABLE NEARBY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: theme.mutedTextColor,
                    ),
                  ),
                ),
                if (mesh.isDiscovering)
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Scanning…',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.accentColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _DeviceList(mesh: mesh, theme: theme),
            if (mesh.lastError != null) ...[
              const SizedBox(height: 10),
              _ErrorRow(message: mesh.lastError!, onClear: mesh.clearError),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({required this.isAdvertising, required this.onPressed});

  final bool isAdvertising;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: isAdvertising
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Visible'),
            )
          : FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                foregroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.visibility_off_rounded, size: 18),
              label: const Text('Visible'),
            ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.isScanning, required this.onPressed});

  final bool isScanning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.deepPurpleAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.deepPurpleAccent.withValues(
            alpha: 0.7,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isScanning)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.travel_explore_rounded, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isScanning ? 'Stop Scan' : 'Find Nearby Devices',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisconnectAllButton extends StatelessWidget {
  const _DisconnectAllButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE53935),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.link_off_rounded, size: 16),
      label: const Text(
        'Disconnect All',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ConnectedChip extends StatelessWidget {
  const _ConnectedChip({
    required this.device,
    required this.isActive,
    required this.onTap,
  });

  final PeerDevice device;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.deepPurpleAccent
              : theme.textColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive
                ? Colors.deepPurpleAccent
                : theme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              device.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.mesh, required this.theme});

  final MeshProvider mesh;
  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    final devices = mesh.discoveredDevices;

    if (devices.isEmpty) {
      return Container(
        height: 92,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mesh.isDiscovering
                  ? Icons.radar_rounded
                  : Icons.devices_other_rounded,
              size: 26,
              color: theme.mutedTextColor,
            ),
            const SizedBox(height: 6),
            Text(
              mesh.isDiscovering
                  ? 'Looking for devices around you…'
                  : 'Tap “Find Nearby Devices” to scan.',
              style: TextStyle(fontSize: 12, color: theme.mutedTextColor),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 168),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: devices.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor),
        itemBuilder: (context, index) {
          final device = devices[index];
          final isConnecting = device.status == PeerStatus.connecting;
          final full = mesh.connectedCount >= MeshProvider.maxDevices;
          final canConnect = !isConnecting && !full && !mesh.isBusy;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 2),
            onTap: canConnect ? () => mesh.connectToDevice(device) : null,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.phone_android_rounded,
                color: Colors.deepPurpleAccent,
                size: 20,
              ),
            ),
            title: Text(
              device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
            subtitle: Text(
              isConnecting ? 'Connecting…' : 'Tap to connect',
              style: TextStyle(
                fontSize: 11.5,
                color: isConnecting ? theme.accentColor : theme.mutedTextColor,
                fontWeight: isConnecting ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            trailing: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                foregroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: canConnect ? () => mesh.connectToDevice(device) : null,
              icon: isConnecting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(isConnecting ? 'Wait' : 'Connect'),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onClear});

  final String message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Color(0xFFE53935),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFE53935),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}
