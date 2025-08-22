import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/errors.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import 'order_create.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getOrders();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(); // Replace with your base URL
});

class AdminOrdersList extends ConsumerWidget {
  const AdminOrdersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consignes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderCreateScreen()),
              );
              if (created == true) {
                ref.invalidate(ordersProvider);
              }
            },
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ordersProvider);
          },
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              return Card(
                child: ListTile(
                  title: Text('${o.customerName ?? 'Unknown'} (${o.customerPhone})'),
                  subtitle: Text('${o.items.length} items - ${o.amount} XAF\nStatus: ${o.status.name}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to detail/assignment screen
                  },
                ),
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack){
          if(err is ApiError)
            () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${err.detail}')));
            };
        }
      ),
    );
  }
}
