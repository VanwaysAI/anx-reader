import 'dart:async';
import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/wireless_transfer_server.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';

class WirelessTransferPage extends ConsumerStatefulWidget {
  const WirelessTransferPage({super.key});

  @override
  ConsumerState<WirelessTransferPage> createState() =>
      _WirelessTransferPageState();
}

class _WirelessTransferPageState extends ConsumerState<WirelessTransferPage> {
  bool _isRunning = false;
  String _ipAddress = '';
  int _port = 0;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _getLocalIp();
    _updateStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _updateStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _updateStatus() {
    final server = WirelessTransferServer();
    setState(() {
      _isRunning = server.isRunning;
      _port = server.port;
    });
  }

  Future<void> _getLocalIp() async {
    String ip = '127.0.0.1';
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127')) {
            ip = addr.address;
            break;
          }
        }
        if (ip != '127.0.0.1') break;
      }
    } catch (e) {
      // ignore
    }
    if (mounted) {
      setState(() => _ipAddress = ip);
    }
  }

  Future<void> _toggleServer(bool value) async {
    final server = WirelessTransferServer();
    if (value) {
      final success = await server.start();
      if (success && mounted) {
        setState(() => _isRunning = true);
        _updateStatus();
        await _getLocalIp();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).commonFailed)),
        );
      }
    } else {
      await server.stop();
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _copyAddress() async {
    final address = 'http://$_ipAddress:$_port';
    await Clipboard.setData(ClipboardData(text: address));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final address = 'http://$_ipAddress:$_port';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsWirelessTransfer),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server toggle card
            FilledContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _isRunning
                                ? Colors.green.withValues(alpha: 0.14)
                                : theme.colorScheme.secondary
                                    .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.wifi_tethering,
                            size: 18,
                            color: _isRunning
                                ? Colors.green
                                : theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsWirelessTransferStatus,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _isRunning
                                  ? l10n.settingsWirelessTransferRunning
                                  : l10n.settingsWirelessTransferStopped,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _isRunning
                                    ? Colors.green
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isRunning,
                      onChanged: _toggleServer,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Address display
            if (_isRunning) ...[
              FilledContainer(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            l10n.settingsWirelessTransferAddress,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _copyAddress,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  address,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(Icons.copy,
                                  size: 18,
                                  color: theme.colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.settingsWirelessTransferStartTip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Auto shutdown setting
            FilledContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          l10n.settingsWirelessTransferAutoShutdown,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: Prefs().wirelessTransferAutoShutdown,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 300,
                          child:
                              Text(l10n.settingsWirelessTransferShutdown5Min),
                        ),
                        DropdownMenuItem(
                          value: 600,
                          child: Text(
                              l10n.settingsWirelessTransferShutdown10Min),
                        ),
                        DropdownMenuItem(
                          value: 1800,
                          child: Text(
                              l10n.settingsWirelessTransferShutdown30Min),
                        ),
                        DropdownMenuItem(
                          value: 0,
                          child:
                              Text(l10n.settingsWirelessTransferShutdownNever),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          Prefs().wirelessTransferAutoShutdown = value;
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.settingsWirelessTransferShutdownTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
