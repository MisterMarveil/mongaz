import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import 'map_tracking.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Home'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('No assigned deliveries'))
          : ListView.builder(
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
    );
  }
}
