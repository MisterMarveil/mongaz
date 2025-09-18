import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:latlong2/latlong.dart';
import 'package:toast/toast.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../core/contants.dart';
import '../core/map_selection_screen.dart';

// Provider for existing order items
final existingOrderItemsProvider = FutureProvider.autoDispose<List<OrderItem>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return [];
});

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
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  String _phoneNumber = "";
  bool _isPhoneValid = false;

  final List<OrderItem> _items = [];
  bool _loading = false;
  String? _selectedExistingItem;

  // Focus node for address field
  //final FocusNode _addressFocusNode = FocusNode();
  //bool _showMap = false;

  @override
  void initState() {
    super.initState();
    //_addressFocusNode.addListener(_onAddressFocusChange);
  }

  @override
  void dispose() {
   // _addressFocusNode.removeListener(_onAddressFocusChange);
   // _addressFocusNode.dispose();
    super.dispose();
  }

  /*void _onAddressFocusChange() {
    if (_addressFocusNode.hasFocus) {
      setState(() {
        _showMap = true;
      });
    }
  }*/

  @override
  Widget build(BuildContext context) {
    ToastContext().init(context);
    final api = ref.watch(apiServiceProvider);
    final existingItemsAsync = ref.watch(existingOrderItemsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text('Créer Consigne', style: kPrimaryBarStyle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              InternationalPhoneNumberInput(
                hintText: "Numéro Client",
                errorMessage: "Numéro invalide",
                initialValue: PhoneNumber(isoCode: 'CM'),
                onInputChanged: (PhoneNumber number) {
                  _phoneNumber = number.phoneNumber ?? "";
                },
                onInputValidated: (bool value) {
                  _isPhoneValid = value;
                },
                validator: (v) => v == null || v.isEmpty || !_isPhoneValid ? (v == null || v.isEmpty ? 'Numero du client requis' : 'Numero valide requis') : null,
                selectorConfig: SelectorConfig(
                  selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                  useBottomSheetSafeArea: true,
                ),
                ignoreBlank: true,
                autoValidateMode: AutovalidateMode.always,
                selectorTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Sora',
                  color: Colors.black54,
                ),
                textFieldController: _phoneController,
                formatInput: true,
                keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
                onSaved: (PhoneNumber number) {},
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom Client'),
              ),

              // Address Search Field with Mapbox
              _buildAddressSearchField(),

              // Show map when address field is focused
              /*if (_showMap)
                Container(
                  height: 500,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: MapBoxPlaceSearchWidget(
                    context: context,
                    hint: 'Rechercher une adresse',
                    onSelected: (place, _selectedLocation) {
                      setState(() {
                        _addressController.text = place.text!;
                        _latController.text = place.geometry?.coordinates.lat.toString() ?? '';
                        _lonController.text = place.geometry?.coordinates.long.toString() ?? '';
                        _showMap = false; // Hide map after selection
                        _addressFocusNode.unfocus(); // Remove focus
                      });
                    },
                    onSuggestionTap: (place) {
                      // Show a snackbar with the selected suggestion
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Adresse sélectionnée: ${place.text}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    limit: 5, // Reduced limit to minimize API calls
                    country: 'CM',
                    showMap: true, // Ensure map is shown
                    moveMarker: true, // Enable marker movement
                  ),
                ),*/

              // Latitude and Longitude Display
              if (_latController.text.isNotEmpty && _lonController.text.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Coordonnées:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            decoration: const InputDecoration(labelText: 'Latitude'),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lonController,
                            decoration: const InputDecoration(labelText: 'Longitude'),
                            readOnly: true,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearCoordinates,
                          tooltip: 'Effacer les coordonnées',
                        ),
                      ],
                    ),
                  ],
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
                  if (!_isPhoneValid){
                    Toast.show("Prière d'insérer un numero de téléphone valide", duration: Toast.lengthShort, gravity: Toast.top);
                    return;
                  }
                  if(_items.length == 0){
                    Toast.show("Prière d'insérer au moins un article à livrer",  duration: Toast.lengthShort, gravity: Toast.top);
                    return;
                  }
                  if(_latController.text.isEmpty || _lonController.text.isEmpty){
                    Toast.show("Veuillez sélectionner une adresse valide sur la carte", duration: Toast.lengthShort, gravity: Toast.top);
                    return;
                  }

                  setState(() => _loading = true);
                  try {
                    final payload = {
                      'customerPhone': _phoneNumber,
                      'customerName': _nameController.text.trim(),
                      'address': _addressController.text.trim(),
                      'amount': _amountController.text,
                      'items': _items.map((i) => i.toJson()).toList(),
                      'lat': _latController.text,
                      'lon': _lonController.text,
                    };

                    await api.createOrder(Order.fromJson(payload));

                    Toast.show("Consigne ajoutée", duration: Toast.lengthShort, gravity: Toast.top);
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

  Widget _buildAddressSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _addressController,
          readOnly: true, // Make it read-only since selection happens on the map screen
          decoration: InputDecoration(
            labelText: 'Adresse Client',
            suffixIcon: IconButton(
              icon: const Icon(Icons.map),
              onPressed: _openMapSelection,
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Addresse requise' : null,
        ),
      ],
    );
  }

  void _openMapSelection() async {
    LatLng? initialLocation;
    try {
      if (_latController.text.isNotEmpty && _lonController.text.isNotEmpty) {
        initialLocation = LatLng(
          double.parse(_latController.text),
          double.parse(_lonController.text),
        );
      }
    } catch (e) {
      // If coordinates are invalid, just proceed without initial location
      print('Error parsing coordinates: $e');
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(
          initialLocation: initialLocation,
          initialAddress: _addressController.text.isEmpty ? null : _addressController.text,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _addressController.text = result['address']?.toString() ?? 'Adresse non spécifiée';
        _latController.text = result['lat']?.toString() ?? '';
        _lonController.text = result['lon']?.toString() ?? '';
      });
    }
  }

  void _clearCoordinates() {
    setState(() {
      _addressController.clear();
      _latController.clear();
      _lonController.clear();
    });
  }

  Future<OrderItem?> _showAddItemDialog(BuildContext context) async {
    final brandCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    return showDialog<OrderItem>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter Article'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Marque')),
            TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Capacité')),
            TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantité'),
                keyboardType: TextInputType.number
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              Navigator.pop(context, OrderItem(
                id: "",
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