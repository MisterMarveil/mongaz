// orders_list.dart (updated)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/errors.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../core/contants.dart';
import 'order_create.dart';
// Add these new imports
import 'users_management.dart';
import '../core/reports_screen.dart';
import '../core/settings_screen.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getOrders();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(); // Replace with your base URL
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title:  Text('Admin Panel', style: kPrimaryBarStyle),
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
        error: (err, stack) {
          if (err is ApiError) {
           debugPrint('Error: ${err.detail}');
           //ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${err.detail}')));
          }
          return const Center(child: Text('Oops! Consignes absentes'));
        },
      ),
    );
  }
}