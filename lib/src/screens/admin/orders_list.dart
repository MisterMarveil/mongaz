import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/errors.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/mercure_service.dart';
import '../core/contants.dart';
import '../core/network_aware_wrapper.dart';
import 'driver_selection_screen.dart';
import 'order_create.dart';
import 'users_management.dart';
import '../core/reports_screen.dart';
import '../core/settings_screen.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getOrders();
});

final existingOrderItemsProvider = FutureProvider.autoDispose<List<OrderItem>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    return await api.getOrderItems();
  } catch (e) {
    debugPrint('Error fetching order items: $e');
    return [];
  }
});

class AdminOrdersList extends ConsumerStatefulWidget {
  const AdminOrdersList({super.key});

  @override
  ConsumerState<AdminOrdersList> createState() => _AdminOrdersListState();
}

class _AdminOrdersListState extends ConsumerState<AdminOrdersList> {
  int _currentIndex = 0;

  final List<Widget> _adminScreens = [
    const OrdersListContent(), // Original orders list
    const UsersManagementScreen(), // Users management
    const ReportsScreen(isAdmin: true), // Reports
    const SettingsScreen(isAdmin: true), // Settings
  ];

  @override
  Widget build(BuildContext context) {
    final mercureService = ref.watch(mercureServiceProvider);
    final connectionState = ref.watch(mercureConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title:  Text('Admin Panel', style: kPrimaryBarStyle),
        actions: [
          IconButton(
            icon: connectionState.when(
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
              ),
            onPressed: () {
              // Show connection status details
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Mercure Connection Status'),
                  content: connectionState.when(
                    data: (state) => Text('Status: ${state.toString().split('.').last}'),
                    loading: () => const Text('Checking status...'),
                    error: (error, stack) => Text('Error: $error'),
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: _adminScreens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kPrimaryBarBackgroundColor,
        selectedItemColor: kSelectedMenuItemColor,
        unselectedItemColor: kUnselectedMenuItemColor,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            backgroundColor: kMenuItemBackgroundColor,
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            backgroundColor: kMenuItemBackgroundColor,
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            backgroundColor: kMenuItemBackgroundColor,
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            backgroundColor: kMenuItemBackgroundColor,
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Extract the original orders list content to a separate widget
class OrdersListContent extends ConsumerWidget {
  const OrdersListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Consignes', style: kSecondaryBarStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_sharp, color: Colors.indigoAccent),
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
      body: NetworkAwareWrapper(
        showFullScreenMessage: true,
        child: ordersAsync.when(
          data: (orders) => orders.length == 0 ?
              const Center(child: Text('Pas de consigne disponible'))
              : RefreshIndicator(
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
                      _showOrderActionDialog(context, o, ref);
                    },
                  ),
                );
              },
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) {
            if (err is ApiError) {
             debugPrint('Error: ${err.detail}');
             //ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${err.detail}')));
            }
            return const Center(child: Text('Oops! erreur lors du chargement des consignes'));
          },
        ),
      ),
    );
  }

  // Add this method to _AdminOrdersListState
  void _showOrderActionDialog(BuildContext context, Order order, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Order #${order.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${order.customerName}'),
              Text('Phone: ${order.customerPhone}'),
              Text('Status: ${order.status.name}'),
              const SizedBox(height: 16),
              const Text('Select action:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _assignOrderToDrivers(context, order, ref),
              child: const Text('Assign to Drivers'),
            ),
          ],
        );
      },
    );
  }

  void _assignOrderToDrivers(BuildContext context, Order order, WidgetRef ref) async {
    // Navigate to driver selection screen
    final selectedDrivers = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverSelectionScreen(order: order,),
      ),
    );

    if (selectedDrivers != null && selectedDrivers is List<String>) {
      final mercureService = ref.read(mercureServiceProvider);
      await mercureService.notifyOrderAssignment(
        orderId: order.id,
        driverIds: selectedDrivers,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order assigned to ${selectedDrivers.length} drivers')),
      );
    }
  }
}