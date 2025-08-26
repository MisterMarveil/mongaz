// widgets/network_aware_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/network_service.dart';
import 'network_status_banner.dart';
import 'offline_message_screen.dart';

class NetworkAwareWrapper extends StatelessWidget {
  final Widget child;
  final bool showFullScreenMessage;

  const NetworkAwareWrapper({
    super.key,
    required this.child,
    this.showFullScreenMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    final networkService = Provider.of<NetworkService>(context);

    if (showFullScreenMessage && !networkService.isConnected) {
      return const OfflineMessageScreen();
    }

    return Column(
      children: [
        const NetworkStatusBanner(),
        Expanded(child: child),
      ],
    );
  }
}