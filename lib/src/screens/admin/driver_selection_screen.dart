// driver_selection_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_map/flutter_map.dart';
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
    final userCollection = await api.getUsers(role: 'ROLE_DRIVER');
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
    final pointOfSaleCollection = await api.getPointsOfSales();
    return pointOfSaleCollection.member;
  } catch (e) {
    debugPrint('Error fetching points of sale: $e');
    return [];
  }
});

// Provider for driver locations
final driverLocationsProvider = StateNotifierProvider<DriverLocationsNotifier, Map<String, latlong.LatLng>>((ref) {
  return DriverLocationsNotifier();
});

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
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  final Set<String> _selectedDrivers = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showMapView = true;
  PointOfSale? _selectedPointOfSale;
  double _maxDistance = 10.0; // Default 10 km radius
  List<User> _recommendedDrivers = [];
  StreamSubscription<SSEModel>? _locationSubscription;
  final Map<String, PointAnnotation> _driverAnnotations = {};
  PointAnnotation? _pointOfSaleAnnotation;
  Uint8List? _driverMoveMarkerImage;
  Uint8List? _driverMoveCheckedMarkerImage;
  Uint8List? _driverStopMarkerImage;
  Uint8List? _driverStopCheckedMarkerImage;
  Uint8List? _posMarkerImage;
  Uint8List? _posMarkerCheckedImage;


  @override
  void initState() {
    super.initState();
    if (widget.initiallySelectedDrivers != null) {
      _selectedDrivers.addAll(widget.initiallySelectedDrivers!);
    }

    // Load marker images
    _loadMarkerImages();

    // Subscribe to driver location updates
    _subscribeToDriverLocations();
  }

  Future<void> _loadMarkerImages() async {
    try {
      // Load driver marker image
      final driverMoveBytes = await rootBundle.load('assets/images/driver-marker-move.png');
      _driverMoveMarkerImage = driverMoveBytes.buffer.asUint8List();

      final driverMoveCheckedBytes = await rootBundle.load('assets/images/driver-marker-move-checked.png');
      _driverMoveCheckedMarkerImage = driverMoveCheckedBytes.buffer.asUint8List();

      final driverStopBytes = await rootBundle.load('assets/images/driver-marker-stop.png');
      _driverStopMarkerImage = driverStopBytes.buffer.asUint8List();

      final driverStopCheckedBytes = await rootBundle.load('assets/images/driver-marker-stop-checked.png');
      _driverStopCheckedMarkerImage = driverStopCheckedBytes.buffer.asUint8List();

      final posBytes = await rootBundle.load('assets/images/pos-marker.png');
      _posMarkerImage = driverMoveCheckedBytes.buffer.asUint8List();

      final posCheckedBytes = await rootBundle.load('assets/images/pos-marker-checked.png');
      _posMarkerCheckedImage = posCheckedBytes.buffer.asUint8List();

    } catch (e) {
      debugPrint('Error loading marker images: $e');
    }
  }

  void _subscribeToDriverLocations() {
    final mercureService = ref.read(mercureServiceProvider);

    // Subscribe to driver location updates
    mercureService.addTopics(['drivers/locations']);

    // Listen to driver location stream
    final locationStream = mercureService.getTopicStream('drivers/locations');
    _locationSubscription = locationStream.listen((event) {
      try {
        final data = json.decode(event.data!);
        final driverId = data['driverId'] as String?;
        final lat = data['lat'] as double?;
        final lng = data['lng'] as double?;

        if (driverId != null && lat != null && lng != null) {
          final location = latlong.LatLng(lat, lng);
          ref.read(driverLocationsProvider.notifier).updateLocation(driverId, location);

          // Update map marker if map is active
          if (mapboxMap != null && pointAnnotationManager != null) {
            _updateDriverMarker(driverId, location);
          }
        }
      } catch (e) {
        debugPrint('Error parsing driver location: $e');
      }
    });
  }

  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    // Create the PointAnnotationManager
    pointAnnotationManager = await mapboxMap?.annotations.createPointAnnotationManager();

    // If we have a selected point of sale, update the map
    if (_selectedPointOfSale != null) {
      final driversAsync = ref.read(driversProvider);
      final driverLocations = ref.read(driverLocationsProvider);

      driversAsync.whenData((drivers) {
        _findDriversNearPointOfSale(
          drivers,
          driverLocations,
          _selectedPointOfSale!,
          _maxDistance,
        );
      });
    }
  }

  Future<void> _updateDriverMarker(String driverId, latlong.LatLng location) async {
    final annotation = _driverAnnotations[driverId];
    if (annotation != null && pointAnnotationManager != null) {
      // To update the annotation position:
      annotation.geometry = Point(
        coordinates: Position(location.longitude, location.latitude),
      );
      annotation.image = _driverStopMarkerImage;

      // Then update it through the manager
      await pointAnnotationManager!.update(annotation);
    } else {
      // Create new annotation
      _createDriverMarker(driverId, location);
    }
  }

  void _createDriverMarker(String driverId, latlong.LatLng location) {
    if (pointAnnotationManager == null || _driverStopMarkerImage == null) return;

    final isSelected = _selectedDrivers.contains(driverId);
    final imageName = isSelected ? 'selected-driver-marker' : 'driver-marker';

    final options = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(location.longitude, location.latitude),
      ),
      iconImage: imageName,
      iconSize: 1.5,
      textField: driverId.substring(0, 3), // Show first 3 chars of driver ID
      textOffset: [0, 1.5],
    );

    pointAnnotationManager!.create(options).then((annotation) {
      _driverAnnotations[driverId] = annotation;
    });
  }

  void _createPointOfSaleMarker(PointOfSale pointOfSale) {
    if (pointAnnotationManager == null || _posMarkerImage == null) return;

    // Remove existing point of sale annotation if any
    if (_pointOfSaleAnnotation != null) {
      pointAnnotationManager!.delete(_pointOfSaleAnnotation!);
    }

    final options = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(pointOfSale.lon as num, pointOfSale.lat as num),
      ),
      iconImage: 'pos-marker',
      iconSize: 2.0,
      textField: pointOfSale.name,
      textOffset: [0, 2.5],
    );

    pointAnnotationManager!.create(options).then((annotation) {
      _pointOfSaleAnnotation = annotation;
    });
  }

  void _fitToBounds(List<latlong.LatLng> points) {
    if (points.isEmpty || mapboxMap == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    /*
    final bounds = LatLngBounds(latlong.LatLng(minLat, minLng), latlong.LatLng(maxLat, maxLng));

    mapboxMap?.cameraOptions=  !.camera.easeTo(
      CameraOptions(bounds: bounds, padding: const EdgeInsets.all(50)),
    );*/
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(latlong.LatLng pos1, latlong.LatLng pos2) {
    const latlong.Distance distance = latlong.Distance();
    return distance.as(latlong.LengthUnit.Kilometer, pos1, pos2);
  }

  // Find drivers within radius of point of sale
  void _findDriversNearPointOfSale(
      List<User> drivers,
      Map<String, latlong.LatLng> driverLocations,
      PointOfSale pointOfSale,
      double maxDistance,
      ) {
    final posLocation = latlong.LatLng(
      pointOfSale.lat as double,
      pointOfSale.lon as double,
    );

    final nearbyDrivers = drivers.where((driver) {
      final driverLocation = driverLocations[driver.id];
      if (driverLocation == null) return false;

      final distance = _calculateDistance(posLocation, driverLocation);
      return distance <= maxDistance;
    }).toList();

    setState(() {
      _recommendedDrivers = nearbyDrivers;
    });

    // Update map view
    if (mapboxMap != null && pointAnnotationManager != null) {
      _updateMapWithDrivers(nearbyDrivers, driverLocations, pointOfSale);
    }
  }

  void _updateMapWithDrivers(
      List<User> drivers,
      Map<String, latlong.LatLng> driverLocations,
      PointOfSale pointOfSale,
      ) {
    // Clear existing annotations
    pointAnnotationManager?.deleteAll();
    _driverAnnotations.clear();
    _pointOfSaleAnnotation = null;

    // Add point of sale marker
    _createPointOfSaleMarker(pointOfSale);

    // Add driver markers
    for (final driver in drivers) {
      final location = driverLocations[driver.id];
      if (location != null) {
        _createDriverMarker(driver.id!, location);
      }
    }

    // Fit map to show all markers
    final allPoints = [
      latlong.LatLng(pointOfSale.lat as double, pointOfSale.lon as double),
      ...driverLocations.values,
    ];
    _fitToBounds(allPoints);
  }

  // Auto-select drivers based on proximity
  void _autoSelectDrivers(List<User> drivers, int count) {
    setState(() {
      _selectedDrivers.clear();
      for (int i = 0; i < count && i < drivers.length; i++) {
        _selectedDrivers.add(drivers[i].id!);
      }

      // Update markers to show selection state
      _updateMarkerSelectionStates();
    });
  }

  void _updateMarkerSelectionStates() {
    if (pointAnnotationManager == null) return;

    for (final entry in _driverAnnotations.entries) {
      final driverId = entry.key;
      final annotation = entry.value;
      final isSelected = _selectedDrivers.contains(driverId);
      final imageName = isSelected ? 'selected-driver-marker' : 'driver-marker';

      annotation.image = isSelected ? _driverStopCheckedMarkerImage : _driverStopMarkerImage;
      pointAnnotationManager!.update(annotation);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationSubscription?.cancel();

    // Unsubscribe from driver locations topic
    final mercureService = ref.read(mercureServiceProvider);
    mercureService.removeTopics(['drivers/locations']);

    // Clean up annotation manager
    pointAnnotationManager?.deleteAll();

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
            padding: const EdgeInsets.all(0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
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
                //const SizedBox(width: 2),
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

  Widget _buildMapView(List<User> drivers, Map<String, latlong.LatLng> driverLocations) {
    final camera = CameraOptions(
        center: Point(coordinates: Position(-98.0, 39.5)),
        zoom: 2,
        bearing: 0,
        pitch: 0);
    return MapWidget(
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
      cameraOptions: camera,
    );
  }

  Widget _buildListView(List<User> drivers, Map<String, latlong.LatLng> driverLocations) {
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
                    _selectedDrivers.add(driver.id!);
                  } else {
                    _selectedDrivers.remove(driver.id!);
                  }
                  _updateMarkerSelectionStates();
                });
              },
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedDrivers.remove(driver.id);
                } else {
                  _selectedDrivers.add(driver.id!);
                }
                _updateMarkerSelectionStates();
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildDistanceInfo(latlong.LatLng driverLocation, PointOfSale pointOfSale) {
    final posLatLng = latlong.LatLng(pointOfSale.lat as double, pointOfSale.lon as double);
    final distance = _calculateDistance(driverLocation, posLatLng);

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
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _selectedDrivers.isEmpty
                ? null
                : () {
              // Notify selected drivers
              _notifyDrivers();
              Navigator.pop(context, _selectedDrivers.toList());
            },
            child: Text('Attribuer à ${_selectedDrivers.length} Livreurs'),
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
        message: 'Nouvelle Consigne disponible',
      );
    }
  }
}