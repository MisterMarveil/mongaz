import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/mercure_service.dart';

class MercureConnectionIndicator extends ConsumerWidget {
  const MercureConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(mercureConnectionStateProvider);

    return connectionState.when(
      data: (state) {
        switch (state) {
          case MercureConnectionState.connected:
            return const Icon(Icons.wifi, color: Colors.green);
          case MercureConnectionState.connecting:
            return const Icon(Icons.wifi_find, color: Colors.orange);
          case MercureConnectionState.error:
            return const Icon(Icons.wifi_off, color: Colors.red);
          case MercureConnectionState.disconnected:
            return const Icon(Icons.wifi_off, color: Colors.grey);
        }
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const Icon(Icons.error, color: Colors.red),
    );
  }
}
