// widgets/network_status_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/network_service.dart';

class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final networkService = Provider.of<NetworkService>(context);

    if (networkService.isConnected) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.red,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pas de connexion Internet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Open settings or try to reconnect
                networkService.checkConnection();
              },
              child: Text(
                'RÉESSAYER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}