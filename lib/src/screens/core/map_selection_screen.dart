// map_selection_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_search/models/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension PuckPosition on StyleManager {
  Future<LatLng> getPuckPosition() async {
    Layer? layer;
    if (Platform.isAndroid) {
      layer = await getLayer("mapbox-location-indicator-layer");
    } else {
      layer = await getLayer("puck");
    }
    final location = (layer as LocationIndicatorLayer).location;
    return Future.value(LatLng(location![0]!, location[1]!));
  }
}

class MapSelectionScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;

  const MapSelectionScreen({super.key, this.initialLocation, this.initialAddress});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Suggestion> _searchResults = [];

  bool _isSearching = false;
  Point _defaultPoint = Point(coordinates: Position(11.520531, 3.86077));
  GeoCodingApi? _geoCodingService;
  SearchBoxAPI? _search;

  Map<String, List<Suggestion>> _placesCache = {};
  final Map<String, String> _reverseGeocodeCache = {};
  Timer? _debounce;
  bool _isLoading = true;
  LatLng _defaultLatLngPosteCentrale = LatLng(3.860837854464555, 11.520488067685594);
  String _currentStyle = MapboxStyles.SATELLITE_STREETS;
  bool _isReverseGeocoding = false;

  MapboxMap? _mapboxMap;
  LatLng? _selectedLocation;
  PointAnnotation? _marker;
  PointAnnotationManager? _pointAnnotationManager;
  String _selectedAddress = '';
  bool _markerImageRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initMapBox();
      setState(() {}); // Trigger a rebuild after initialization
    });

    _searchController.addListener(_onSearchChanged);

    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
    }
    if (widget.initialAddress != null) {
      _searchController.text = widget.initialAddress!;
      _selectedAddress = widget.initialAddress!;
    }
  }

  void _toggleStyle() {
    if (_mapboxMap == null) return;

    setState(() {
      _currentStyle = (_currentStyle == MapboxStyles.SATELLITE_STREETS)
          ? MapboxStyles.STANDARD
          : MapboxStyles.SATELLITE_STREETS;

      _mapboxMap!.style.setStyleURI(_currentStyle);
    });
  }

  Future<void> _initMapBox() async {
    _geoCodingService = GeoCodingApi(
      country: 'CM',
      limit: 5,
      types: [PlaceType.address, PlaceType.poi, ],
    );

    _search = SearchBoxAPI(
      country: 'CM',
      language: 'fr',
      limit: 5,
      types: [PlaceType.address, PlaceType.poi, PlaceType.neighborhood, PlaceType.locality, PlaceType.place],
    );

    _selectedLocation = await _getLocaleAddress();
    setState(() {
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    if (query.length < 3) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      debugPrint("SEARCH QUERY: $query");
      _performSearch(query);
    });
  }

  Future<LatLng> _getLocaleAddress() async {
    final position = await _mapboxMap?.style.getPuckPosition();
    if(position != null) {
      return position;
    }
    return _defaultLatLngPosteCentrale;
  }

  void _performSearch(String query) async {
    if (_placesCache.containsKey(query)) {
      setState(() {
        _searchResults = _placesCache[query]!;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      ApiResponse<SuggestionResponse> searchPlace = await _search!.getSuggestions(
        query,
        proximity: Proximity.LatLong(lat: _selectedLocation!.latitude, long: _selectedLocation!.longitude),
      );
      /*final result = await _geoCodingService!.getPlaces(
        query,
        proximity: Proximity.LatLong(lat: _selectedLocation!.latitude, long: _selectedLocation!.longitude),
      );*/

      searchPlace.fold((success) {
        debugPrint("Search success: ${success.suggestions.toString()}");
        _placesCache[query] = success.suggestions;
        setState(() {
          _searchResults = success.suggestions;
          _isSearching = false;
        });
      }, (failure) {
        debugPrint("Search failed: $failure");
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      });
    } catch (e) {
      debugPrint("Search error: $e");

      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _onPlaceSelected(Suggestion suggestion) async {
    setState(() {
      _searchController.text = suggestion.name ?? '';
      _selectedAddress = suggestion.placeFormatted.isNotEmpty ? suggestion.placeFormatted : (suggestion.name ?? '');
      _searchResults = [];
    });

    String mapboxId = suggestion.mapboxId;

    ApiResponse<RetrieveResonse> placeDetails = await _search!.getPlace(mapboxId);

    placeDetails.fold(
          (placeSuccess) {
        // Access coordinates from the retrieved place
        var features = placeSuccess.features;
        if (features.isNotEmpty) {
          var geometry = features[0].geometry;
          Location coordinates = geometry.coordinates; // [longitude, latitude]
          double longitude = coordinates.long;
          double latitude = coordinates.lat;

          _selectedLocation = LatLng(latitude, longitude);
          _moveCameraToLocation(_selectedLocation!);
          _updateMarker(_selectedLocation!);
          print('Retrieved coordinates: Lat: $latitude, Lon: $longitude');
        }
      },
          (placeFailure) {
        print('Place retrieval failed: ${placeFailure.message}');
      },
    );
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;
    _pointAnnotationManager = await _mapboxMap?.annotations.createPointAnnotationManager();

    if (!_markerImageRegistered) {
      _selectedLocation = await _getLocaleAddress();
      debugPrint("found your location: ${_selectedLocation.toString()}");


      final ByteData bytes =    await rootBundle.load('assets/images/pos-marker.png');
      final Uint8List imageData = bytes.buffer.asUint8List();

      // Create a PointAnnotationOptions
      PointAnnotationOptions pointAnnotationOptions = PointAnnotationOptions(
              /*geometry: Point(coordinates:
                          Position(_selectedLocation != null ?
                                                _selectedLocation!.longitude.toDouble() :
                                                _defaultLatLngPosteCentrale.longitude.toDouble(),
                                                _selectedLocation != null ?
                                                _selectedLocation!.latitude.toDouble() :
                                                _defaultLatLngPosteCentrale.latitude.toDouble()
                                                ),
                        ),*/ // Example coordinates
          geometry: Point(coordinates: Position(_selectedLocation!.longitude.toDouble(), _selectedLocation!.latitude.toDouble())),
          image: imageData,
          iconSize: 3.0
      );
      _markerImageRegistered = true;
      _pointAnnotationManager?.create(pointAnnotationOptions);
    }

    _mapboxMap!.gestures.updateSettings(
      GesturesSettings(
        pinchToZoomEnabled: true,
        doubleTapToZoomInEnabled: true,
        scrollEnabled: true,
        rotateEnabled: false,
        pitchEnabled: true,
        quickZoomEnabled: true,
      ),
    );

    var tapInteraction = TapInteraction.onMap((context) {
      _onMapClick(context);
    });
    _mapboxMap?.addInteraction(tapInteraction);

    if (_selectedLocation == null) {
      _mapboxMap?.location.updateSettings(
        LocationComponentSettings(enabled: true),
      );
      try {
        _selectedLocation = await _mapboxMap?.style.getPuckPosition();
      } catch (_) {
        _selectedLocation = LatLng(
          _defaultPoint.coordinates.lat.toDouble(),
          _defaultPoint.coordinates.lng.toDouble(),
        );
      }
    }

    if (_selectedLocation != null) {
      _moveCameraToLocation(_selectedLocation!);
      _updateMarker(_selectedLocation!);
    }
  }

  void _moveCameraToLocation(LatLng location) {
    _mapboxMap?.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(location.longitude, location.latitude),
        ),
        zoom: 17,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  Future<void> _updateMarker(LatLng location) async {
    if (_mapboxMap == null || _pointAnnotationManager == null) return;
    var newPoint = Point(
                     coordinates: Position(
                         location.longitude,
                          location.latitude,
                     ),
                  );
    _marker?.geometry = newPoint;
    _pointAnnotationManager?.update(_marker!);
  }

  void _onMapClick(MapContentGestureContext context) async {
    final latLng = LatLng(
      context.point.coordinates.lat.toDouble(),
      context.point.coordinates.lng.toDouble(),
    );
    setState(() {
      _selectedLocation = latLng;
      _selectedAddress = '';
    });
    _updateMarker(latLng);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sélection Adresse')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sélection Adresse')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  //onChanged: _searchPlaces(),
                  enableSuggestions: true,
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une adresse',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : null,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    height: 200,
                    color: Colors.white,
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, i) {
                        final suggestion = _searchResults[i];
                        return ListTile(
                          title: Text(suggestion.name ?? "Inconnu"),
                          subtitle: Text(suggestion.placeFormatted ?? ""),
                          onTap: () => _onPlaceSelected(suggestion),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
                children: [
                  MapWidget(
                    key: const ValueKey("mapWidget"),
                    cameraOptions: CameraOptions(
                      center: Point(
                        coordinates: Position(
                          _selectedLocation?.longitude ?? _defaultPoint.coordinates.lng,
                          _selectedLocation?.latitude ?? _defaultPoint.coordinates.lat,
                        ),
                      ),
                      zoom: 16.0,
                    ),
                    onMapCreated: _onMapCreated,
                  ),
                  Positioned(
                    top: 20,
                    right: 10,
                    child: FloatingActionButton(
                      onPressed: _toggleStyle,
                      child: const Icon(Icons.map),
                      tooltip: 'Toggle Map Style',
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }
}
