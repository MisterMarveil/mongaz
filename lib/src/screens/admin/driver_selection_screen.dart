// driver_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../models/users.dart';
import '../../models/order.dart';
import '../../models/point_of_sale.dart';
import '../../services/api_service.dart';
import '../../services/mercure_service.dart';
import '../auth/login_screen.dart' hide apiServiceProvider;

// Provider for fetching drivers
final driversProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    final userCollection = (await api.getUsers(role: 'ROLE_DRIVER'));
    return userCollection.member;
  } catch (e) {
    debugPrint('Error fetching drivers: $e');
    return [];
  }
});

// Provider for fetching points of sale
final pointsOfSaleProvider = FutureProvider.autoDispose<List<PointOfSale>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    final pointOfSale = await api.getPointsOfSales();
    return Future.any(pointOfSale.member as Iterable<Future<List<PointOfSale>>>);
  } catch (e) {
    debugPrint('Error fetching points of sale: $e');
    return [];
  }
});

// Add to the top of the file
final driverLocationsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final mercureService = ref.watch(mercureServiceProvider);
  return mercureService.getTopicStream('drivers/locations');
});

void _subscribeToDriverLocations() {
  final driverLocationsStream = ref.watch(driverLocationsProvider);

  driverLocationsStream.when(
    data: (data) {
      try {
        final driverId = data['driverId'];
        final lat = data['lat'];
        final lng = data['lng'];

        if (driverId != null && lat != null && lng != null) {
          ref.read(driverLocationsProvider.notifier).updateLocation(
            driverId,
            latlong.LatLng(lat, lng),
          );
        }
      } catch (e) {
        debugPrint('Error parsing driver location: $e');
      }
    },
    loading: () {},
    error: (error, stack) => debugPrint('Error in driver locations stream: $error'),
  );
}


class DriverLocationsNotifier extends StateNotifier<Map<String, latlong.LatLng>> {
  DriverLocationsNotifier() : super({});

  void updateLocation(String driverId, latlong.LatLng location) {
    state = {...state, driverId: location};
  }

  void removeDriver(String driverId) {
    final newState = {...state};
    newState.remove(driverId);
    state = newState;
  }
}

class DriverSelectionScreen extends ConsumerStatefulWidget {
  final Order order;
  final latlong.LatLng? customerLocation;
  final List<String>? initiallySelectedDrivers;

  const DriverSelectionScreen({
    super.key,
    required this.order,
    this.customerLocation,
    this.initiallySelectedDrivers,
  });

  @override
  ConsumerState<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends ConsumerState<DriverSelectionScreen> {
  late final MapboxMap? mapController;
  final Set<String> _selectedDrivers = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showMapView = true;
  PointOfSale? _selectedPointOfSale;
  double _maxDistance = 10.0; // Default 10 km radius
  List<User> _recommendedDrivers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initiallySelectedDrivers != null) {
      _selectedDrivers.addAll(widget.initiallySelectedDrivers!);
    }

    // Subscribe to driver location updates
    _subscribeToDriverLocations();
  }

  void _subscribeToDriverLocations() {
    final mercureService = ref.read(mercureServiceProvider);

    // Subscribe to driver location updates topic
    mercureService.subscribe(['drivers/locations'], (event) {
      try {
        final data = json.decode(event.data!);
        final driverId = data['driverId'];
        final lat = data['lat'];
        final lng = data['lng'];

        if (driverId != null && lat != null && lng != null) {
          ref.read(driverLocationsProvider.notifier).updateLocation(
            driverId,
            LatLng(lat: lat, lng: lng),
          );
        }
      } catch (e) {
        debugPrint('Error parsing driver location: $e');
      }
    });
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(latlong.LatLng pos1, latlong.LatLng pos2) {
    final Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, pos1, pos2);
  }

  // Find drivers within radius of point of sale
  void _findDriversNearPointOfSale(
      List<User> drivers,
      Map<String, LatLng> driverLocations,
      PointOfSale pointOfSale,
      double maxDistance,
      ) {
    final posLocation = latlong.LatLng(
      pointOfSale.latitude,
      pointOfSale.longitude,
    );

    final nearbyDrivers = drivers.where((driver) {
      final driverLocation = driverLocations[driver.id];
      if (driverLocation == null) return false;

      final driverLatLng = latlong.LatLng(
        driverLocation.lat,
        driverLocation.lng,
      );

      final distance = _calculateDistance(posLocation, driverLatLng);
      return distance <= maxDistance;
    }).toList();

    setState(() {
      _recommendedDrivers = nearbyDrivers;
    });
  }

  // Auto-select drivers based on proximity
  void _autoSelectDrivers(List<User> drivers, int count) {
    setState(() {
      _selectedDrivers.clear();
      for (int i = 0; i < count && i < drivers.length; i++) {
        _selectedDrivers.add(drivers[i].id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversProvider);
    final pointsOfSaleAsync = ref.watch(pointsOfSaleProvider);
    final driverLocations = ref.watch(driverLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Drivers'),
        actions: [
          IconButton(
            icon: Icon(_showMapView ? Icons.list : Icons.map),
            onPressed: () {
              setState(() => _showMapView = !_showMapView);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Point of Sale selection and distance filter
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: pointsOfSaleAsync.when(
                    data: (pointsOfSale) => DropdownButtonFormField<PointOfSale>(
                      value: _selectedPointOfSale,
                      hint: const Text('Select Point of Sale'),
                      items: pointsOfSale.map((pos) {
                        return DropdownMenuItem<PointOfSale>(
                          value: pos,
                          child: Text(pos.name),
                        );
                      }).toList(),
                      onChanged: (PointOfSale? newValue) {
                        setState(() {
                          _selectedPointOfSale = newValue;
                          if (newValue != null) {
                            driversAsync.whenData((drivers) {
                              _findDriversNearPointOfSale(
                                drivers,
                                driverLocations,
                                newValue,
                                _maxDistance,
                              );
                            });
                          }
                        });
                      },
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => const Text('Error loading POS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Max Distance (km)'),
                      Slider(
                        value: _maxDistance,
                        min: 1.0,
                        max: 50.0,
                        divisions: 49,
                        label: _maxDistance.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            _maxDistance = value;
                            if (_selectedPointOfSale != null) {
                              driversAsync.whenData((drivers) {
                                _findDriversNearPointOfSale(
                                  drivers,
                                  driverLocations,
                                  _selectedPointOfSale!,
                                  _maxDistance,
                                );
                              });
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search drivers',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Auto-select button
          if (_recommendedDrivers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Text('Auto-select:'),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: 3,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 driver')),
                      DropdownMenuItem(value: 3, child: Text('3 drivers')),
                      DropdownMenuItem(value: 5, child: Text('5 drivers')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _autoSelectDrivers(_recommendedDrivers, value);
                      }
                    },
                  ),
                ],
              ),
            ),

          Expanded(
            child: driversAsync.when(
              data: (drivers) {
                // Filter drivers based on search query
                final filteredDrivers = drivers.where((driver) {
                  final name = driver.name?.toLowerCase() ?? '';
                  final phone = driver.phone.toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query) || phone.contains(query);
                }).toList();

                // If we have recommended drivers, sort them to the top
                final sortedDrivers = _recommendedDrivers.isNotEmpty
                    ? [
                  ..._recommendedDrivers,
                  ...filteredDrivers
                      .where((d) => !_recommendedDrivers.contains(d))
                      .toList()
                ]
                    : filteredDrivers;

                return _showMapView
                    ? _buildMapView(sortedDrivers, driverLocations)
                    : _buildListView(sortedDrivers, driverLocations);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading drivers: $error'),
              ),
            ),
          ),
          _buildSelectionActions(),
        ],
      ),
    );
  }

  Widget _buildMapView(List<User> drivers, Map<String, LatLng> driverLocations) {
    // This would be the Mapbox map implementation with markers for:
    // 1. Selected point of sale (if any)
    // 2. Driver locations
    // 3. Customer location (if available)

    return Stack(
      children: [
        // Mapbox map would go here
        Container(
          color: Colors.grey[200],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Map View', style: TextStyle(fontSize: 18)),
                if (_selectedPointOfSale != null)
                  Text('Point of Sale: ${_selectedPointOfSale!.name}'),
                Text('${drivers.length} drivers available'),
                if (_recommendedDrivers.isNotEmpty)
                  Text('${_recommendedDrivers.length} drivers within $_maxDistance km'),
              ],
            ),
          ),
        ),
        // Driver markers would be added here based on driverLocations
      ],
    );
  }

  Widget _buildListView(List<User> drivers, Map<String, LatLng> driverLocations) {
    return ListView.builder(
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        final driverLocation = driverLocations[driver.id];
        final isSelected = _selectedDrivers.contains(driver.id);
        final isRecommended = _recommendedDrivers.contains(driver);

        return Container(
          color: isRecommended ? Colors.blue[50] : null,
          child: ListTile(
            leading: CircleAvatar(
              child: Text(driver.name?.substring(0, 1) ?? 'D'),
            ),
            title: Text(driver.name ?? 'Unknown Driver'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.phone),
                if (driverLocation != null && _selectedPointOfSale != null)
                  _buildDistanceInfo(driverLocation, _selectedPointOfSale!),
                if (isRecommended)
                  const Text('Within range', style: TextStyle(color: Colors.green)),
              ],
            ),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedDrivers.add(driver.id);
                  } else {
                    _selectedDrivers.remove(driver.id);
                  }
                });
              },
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedDrivers.remove(driver.id);
                } else {
                  _selectedDrivers.add(driver.id);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildDistanceInfo(LatLng driverLocation, PointOfSale pointOfSale) {
    final driverLatLng = latlong.LatLng(driverLocation.lat, driverLocation.lng);
    final posLatLng = latlong.LatLng(pointOfSale.latitude, pointOfSale.longitude);
    final distance = _calculateDistance(driverLatLng, posLatLng);

    return Text('Distance: ${distance.toStringAsFixed(1)} km from ${pointOfSale.name}');
  }

  Widget _buildSelectionActions() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _selectedDrivers.isEmpty
                ? null
                : () {
              // Notify selected drivers
              _notifyDrivers();
              Navigator.pop(context, _selectedDrivers.toList());
            },
            child: Text('Assign to ${_selectedDrivers.length} Drivers'),
          ),
        ],
      ),
    );
  }

  void _notifyDrivers() {
    final mercureService = ref.read(mercureServiceProvider);

    for (final driverId in _selectedDrivers) {
      mercureService.notifyOrderAssignment(
        orderId: widget.order.id,
        driverIds: [driverId],
        message: 'New order assigned to you',
      );
    }
  }
}

// Add these methods to ApiService
Future<List<PointOfSale>> getPointsOfSale() async {
  try {
    final response = await _dio.get('/api/point_of_sales');

    // Handle both collection response and simple array response
    if (response.data is Map && response.data.containsKey('member')) {
      final collection = PointOfSaleCollection.fromJson(response.data);
      return collection.member;
    } else if (response.data is List) {
      return (response.data as List).map((e) => PointOfSale.fromJson(e)).toList();
    }

    return [];
  } on DioException catch (e) {
    if (e.error is ApiError) {
      throw e.error as ApiError;
    }
    rethrow;
  }
}

Future<List<User>> getUsers({String? role}) async {
  try {
    final response = await _dio.get('/api/users', queryParameters: {
      if (role != null) 'role': role,
    });

    // Handle both collection response and simple array response
    if (response.data is Map && response.data.containsKey('member')) {
      final collection = UserCollection.fromJson(response.data);
      return collection.member;
    } else if (response.data is List) {
      return (response.data as List).map((e) => User.fromJson(e)).toList();
    }

    return [];
  } on DioException catch (e) {
    if (e.error is ApiError) {
      throw e.error as ApiError;
    }
    rethrow;
  }
}

// Add PointOfSaleCollection model
class PointOfSaleCollection {
  final List<PointOfSale> member;

  PointOfSaleCollection({required this.member});

  factory PointOfSaleCollection.fromJson(Map<String, dynamic> json) {
    return PointOfSaleCollection(
      member: (json['member'] as List).map((e) => PointOfSale.fromJson(e)).toList(),
    );
  }
}

// Add UserCollection model
class UserCollection {
  final List<User> member;

  UserCollection({required this.member});

  factory UserCollection.fromJson(Map<String, dynamic> json) {
    return UserCollection(
      member: (json['member'] as List).map((e) => User.fromJson(e)).toList(),
    );
  }
}

// Enhance PointOfSale model to include coordinates
class PointOfSale {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  PointOfSale({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PointOfSale.fromJson(Map<String, dynamic> json) {
    // You'll need to parse the coordinates from your API response
    // This is a placeholder implementation
    return PointOfSale(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
    );
  }
}