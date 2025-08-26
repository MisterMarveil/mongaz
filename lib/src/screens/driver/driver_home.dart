// driver_home.dart (updated)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../core/network_aware_wrapper.dart';
import 'map_tracking.dart';
// Add these new imports
import '../core/reports_screen.dart';
import '../core/settings_screen.dart';
import 'earnings_screen.dart'; // Additional screen for driver

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(); // Replace with your base URL
});

class DriverHome extends ConsumerStatefulWidget {
  const DriverHome({super.key});

  @override
  ConsumerState<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends ConsumerState<DriverHome> {
  StreamSubscription? _assignmentSub;
  List<Order> _orders = [];
  bool _loading = false;
  int _currentIndex = 0;

  final List<Widget> _driverScreens = [
    const DriverHomeContent(), // Original driver home
    const ReportsScreen(isAdmin: false), // Reports
    const EarningsScreen(), // Additional screen for driver (earnings)
    const SettingsScreen(isAdmin: false), // Settings
  ];

  @override
  void initState() {
    super.initState();
    if (_currentIndex == 0) {
      _loadOrders();
      _subscribeToAssignments();
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final list = await api.getOrders(status: OrderStatus.ASSIGNED); // only assigned to this driver (filter server-side)
      setState(() => _orders = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading orders: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _subscribeToAssignments() async {
    final api = ref.read(apiServiceProvider);
    final jwt = ''; // TODO: retrieve from secure storage
    const hubUrl = 'https://your-mercure-hub/.well-known/mercure';
    final driverId = 'current-driver-id'; // TODO: load from logged in user

    // Subscribe to assignment topic
    final stream = await api.subscribeToTopic(hubUrl, 'order_assignment_$driverId', jwt);
    stream.listen(
          (event) async {
        print(
            'Id: ${event.id ?? ""} \n Event: ${event.toString() ?? ""} \n Data: ${event.data}'
        );

        if (event.data != null && event.data!.isNotEmpty) {
          try {
            //TODO: execute something connexion established and event received
            try {
              final data = jsonDecode(event.data ?? '{}');
              final order = Order.fromJson(data);
              _showAssignmentDialog(order);
            } catch (err) {
              debugPrint('Error parsing assignment: $err');
            }
          } catch (e) {
            debugPrint('USSD execution failed ${e.toString()}');
          }
        }
      },
      onError: (error) {
        debugPrint('SSE connection error: ${error.toString()}');
        //_handleReconnect();
      },
      onDone: () {
        print('SSE connection closed by server');
        //_handleReconnect();
      },
    );
  }

  void _showAssignmentDialog(Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        int secondsLeft = 300;
        Timer? countdown;

        countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (secondsLeft <= 0) {
            timer.cancel();
            Navigator.of(context).pop();
          } else {
            secondsLeft--;
          }
        });

        return AlertDialog(
          title: const Text('New Delivery Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${order.customerName ?? ''} (${order.customerPhone})'),
              Text('Address: ${order.address}'),
              Text('Amount: ${order.amount} XAF'),
              const SizedBox(height: 8),
              Text('Accept within $secondsLeft seconds'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                countdown?.cancel();
                Navigator.pop(context);
              },
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () async {
                countdown?.cancel();
                Navigator.pop(context);
                await _acceptOrder(order.id);
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.acceptOrder(orderId);
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error accepting order: $e')));
    }
  }


  @override
  void dispose() {
    _assignmentSub?.cancel();
    super.dispose();
  }

  // ... (keep all the existing methods: _loadOrders, _subscribeToAssignments, 
  // _showAssignmentDialog, _acceptOrder)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Driver Panel'),
      ),
      body: _driverScreens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.indigo,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Earnings', // Additional option for driver
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Extract the original driver home content to a separate widget
class DriverHomeContent extends ConsumerStatefulWidget {
  const DriverHomeContent({super.key});

  @override
  ConsumerState<DriverHomeContent> createState() => _DriverHomeContentState();
}

class _DriverHomeContentState extends ConsumerState<DriverHomeContent> {
  List<Order> _orders = [];
  bool _loading = false;
  StreamSubscription? _assignmentSub;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _subscribeToAssignments();
  }

  @override
  void dispose() {
    _assignmentSub?.cancel();
    super.dispose();
  }

  // Copy all the original methods from _DriverHomeState here:
  // _loadOrders, _subscribeToAssignments, _showAssignmentDialog, _acceptOrder

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final list = await api.getOrders(status: OrderStatus.ASSIGNED);
      setState(() => _orders = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading orders: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _subscribeToAssignments() async {
    final api = ref.read(apiServiceProvider);
    final jwt = ''; // TODO: retrieve from secure storage
    const hubUrl = 'https://your-mercure-hub/.well-known/mercure';
    final driverId = 'current-driver-id'; // TODO: load from logged in user

    // Subscribe to assignment topic
    final stream = await api.subscribeToTopic(hubUrl, 'order_assignment_$driverId', jwt);
    _assignmentSub = stream.listen(
          (event) async {
        print('Id: ${event.id ?? ""} \n Event: ${event.toString() ?? ""} \n Data: ${event.data}');

        if (event.data != null && event.data!.isNotEmpty) {
          try {
            try {
              final data = jsonDecode(event.data ?? '{}');
              final order = Order.fromJson(data);
              _showAssignmentDialog(order);
            } catch (err) {
              debugPrint('Error parsing assignment: $err');
            }
          } catch (e) {
            debugPrint('USSD execution failed ${e.toString()}');
          }
        }
      },
      onError: (error) {
        debugPrint('SSE connection error: ${error.toString()}');
      },
      onDone: () {
        print('SSE connection closed by server');
      },
    );
  }

  void _showAssignmentDialog(Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        int secondsLeft = 300;
        Timer? countdown;

        countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (secondsLeft <= 0) {
            timer.cancel();
            Navigator.of(context).pop();
          } else {
            secondsLeft--;
          }
        });

        return AlertDialog(
          title: const Text('New Delivery Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${order.customerName ?? ''} (${order.customerPhone})'),
              Text('Address: ${order.address}'),
              Text('Amount: ${order.amount} XAF'),
              const SizedBox(height: 8),
              Text('Accept within $secondsLeft seconds'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                countdown?.cancel();
                Navigator.pop(context);
              },
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () async {
                countdown?.cancel();
                Navigator.pop(context);
                await _acceptOrder(order.id);
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.acceptOrder(orderId);
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error accepting order: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Driver Home'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('Aucune Consigne Assignée'))
          : NetworkAwareWrapper(
        showFullScreenMessage: true,
            child: ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
            final o = _orders[index];
            return Card(
              child: ListTile(
                title: Text(o.customerName ?? 'Unknown'),
                subtitle: Text('${o.address}\nAmount: ${o.amount} XAF'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DriverMapTracking(order: o)),
                  );
                },
              ),
            );
                    },
                  ),
          ),
    );
  }
}