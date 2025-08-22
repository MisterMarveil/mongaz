import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../core/contants.dart';
import 'orders_list.dart';

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();

  final List<OrderItem> _items = [];

  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiServiceProvider);

    return Scaffold(
      appBar: AppBar(
      backgroundColor: Colors.indigo,
      title:  Text('Créer Consigne', style: kPrimaryBarStyle),
    ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Numero Client'),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Numero du client requis' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom Client'),
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adresse Client'),
                validator: (v) => v == null || v.isEmpty ? 'Addresse requise' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Montant à percevoir (XAF)'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Le Montant est requis ' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajout Article'),
                onPressed: () async {
                  final item = await _showAddItemDialog(context);
                  if (item != null) {
                    setState(() => _items.add(item));
                  }
                },
              ),
              if (_items.isNotEmpty)
                Column(
                  children: _items.map((e) => ListTile(
                    title: Text('${e.brand} - ${e.capacity}'),
                    subtitle: Text('Qty: ${e.quantity}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _items.remove(e)),
                    ),
                  )).toList(),
                ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _loading = true);
                  try {
                    final payload = {
                      'customerPhone': _phoneController.text.trim(),
                      'customerName': _nameController.text.trim(),
                      'address': _addressController.text.trim(),
                      'amount': double.tryParse(_amountController.text) ?? 0,
                      'items': _items.map((i) => i.toJson()).toList(),
                    };

                    await api.createOrder(Order.fromJson(payload));
                    if (mounted) Navigator.pop(context, true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: const Text('Soumettre'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<OrderItem?> _showAddItemDialog(BuildContext context) async {
    final brandCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    return showDialog<OrderItem>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter Article'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Marque')),
            TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Capacité')),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantité'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              Navigator.pop(context, OrderItem(
                id: "", // ID will be generated by the server
                brand: brandCtrl.text.trim(),
                capacity: capCtrl.text.trim(),
                quantity: qty,
              ));
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
