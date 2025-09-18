import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_search/models/location.dart';

/// Extension to retrieve current user puck position
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

class MapBoxPlaceSearchWidget extends StatefulWidget {
  final BuildContext context;
  final String hint;
  final Function(MapBoxPlace, LatLng?) onSelected;
  final Function(MapBoxPlace)? onSuggestionTap;
  final int limit;
  final String country;
  final bool showMap;
  final bool moveMarker;

  const MapBoxPlaceSearchWidget({
    Key? key,
    required this.context,
    this.hint = 'Rechercher une adresse',
    required this.onSelected,
    this.onSuggestionTap,
    this.limit = 5,
    this.country = 'CM',
    this.showMap = false,
    this.moveMarker = true,
  }) : super(key: key);

  @override
  _MapBoxPlaceSearchWidgetState createState() => _MapBoxPlaceSearchWidgetState();
}

class _MapBoxPlaceSearchWidgetState extends State<MapBoxPlaceSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<MapBoxPlace> _searchResults = [];
  bool _isSearching = false;
  bool _showMap = false;
  Point _defaultPoint = Point(coordinates: Position(3.86077, 11.520531)); // Default to Yaoundé, Cameroon
  GeoCoding? _geoCodingService;
  final Map<String, List<MapBoxPlace>> _placesCache = {};
  final Map<String, String> _reverseGeocodeCache = {};
  Timer? _reverseDebounce;

  // Debouncer
  Timer? _debounce;

  // Map-related variables
  MapboxMap? _mapboxMap;
  LatLng? _selectedLocation;
  PointAnnotation? _marker;
  PointAnnotationManager? _pointAnnotationManager;

  @override
  void initState() {
    super.initState();
    _initMapBox();
    _searchController.addListener(_onSearchChanged);
    _showMap = widget.showMap;

    // If map should be shown initially, focus on the search field
    if (_showMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(widget.context).requestFocus(_searchFocusNode);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MapBoxPlaceSearchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showMap != oldWidget.showMap) {
      setState(() {
        _showMap = widget.showMap;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapboxMap?.dispose();
    _debounce?.cancel();
    _reverseDebounce?.cancel();
    super.dispose();
  }

  void _initMapBox() {
    _geoCodingService = GeoCoding(
      country: widget.country,
      limit: widget.limit,
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    if (query.length < 3) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) async {
    if (_placesCache.containsKey(query)) {
      // Return cached results
      setState(() {
        _searchResults = _placesCache[query]!;
      });
      _showBottomSuggestions(_searchResults);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await _geoCodingService!.getPlaces(
        query,
        proximity: Proximity.LatLong(lat: 3.8480, long: 11.5021),
      );

      result.fold((success) {
        _placesCache[query] = success; // Cache results
        setState(() {
          _searchResults = success;
          _isSearching = false;
        });
        if (success.isNotEmpty) _showBottomSuggestions(success);
      }, (failure) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      });
    } catch (_) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _showBottomSuggestions(List<MapBoxPlace> places) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: places.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, index) {
          final place = places[index];
          return ListTile(
            leading: const Icon(Icons.location_on, color: Colors.indigo),
            title: Text(place.text ?? 'Inconnu'),
            subtitle: Text(
              place.placeName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.pop(ctx);
              if (widget.onSuggestionTap != null) {
                widget.onSuggestionTap!(place);
              }
              _onPlaceSelected(place);
            },
          );
        },
      ),
    );
  }

  void _onPlaceSelected(MapBoxPlace place) {
    _searchController.text = place.text ?? '';
    if (place.geometry?.coordinates != null) {
      final lat = place.geometry!.coordinates.lat;
      final lng = place.geometry!.coordinates.long;
      _selectedLocation = LatLng(lat, lng);

      if (widget.moveMarker) {
        _moveCameraToLocation(_selectedLocation!);
        _addOrUpdateMarker(_selectedLocation!);
      }

      widget.onSelected(place, _selectedLocation);
    } else {
      widget.onSelected(place, null);
    }
  }



  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;
    _pointAnnotationManager =
    await _mapboxMap!.annotations.createPointAnnotationManager();
    _mapboxMap!.gestures.updateSettings(
      GesturesSettings(
        pinchToZoomEnabled: true,
        pinchToZoomDecelerationEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        scrollEnabled: true,
        rotateEnabled: false,
        pitchEnabled: true,
        quickZoomEnabled: true,
      ),
    );

    var tapInteraction = TapInteraction.onMap((context) {
      debugPrint("Tap on map itself at: ${context.point.coordinates.lat}, ${context.point.coordinates.lng}");
      _onMapClick(context);
    });
    // Add tap listener for the map
    _mapboxMap?.addInteraction(tapInteraction);

    if (_selectedLocation == null) {
      _mapboxMap?.location.updateSettings(
        LocationComponentSettings(enabled: true),
      );
      try {
        _selectedLocation = await _mapboxMap?.style.getPuckPosition();
      } catch (e) {
        // Fallback to default location if puck position is not available
        _selectedLocation = LatLng(_defaultPoint.coordinates.lat.toDouble(), _defaultPoint.coordinates.lng.toDouble());
      }
    }

    if (_selectedLocation != null) {
      _moveCameraToLocation(_selectedLocation!);
      _addOrUpdateMarker(_selectedLocation!);
    }
  }

  void _moveCameraToLocation(LatLng location) {
    _mapboxMap?.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(location.latitude, location.longitude),
        ),
        zoom: 17,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  void _addOrUpdateMarker(LatLng location) async {
    if (_mapboxMap == null || _pointAnnotationManager == null) return;
    if (_marker != null) _pointAnnotationManager!.delete(_marker!);

    final ByteData bytes =
    await rootBundle.load('assets/images/pos-marker.png');

    _marker = await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        iconSize: 0.1,
        geometry: Point(
          coordinates: Position(location.latitude, location.longitude),
        ),
        image: bytes.buffer.asUint8List(),
        isDraggable: true,
      ),
    );

    // Drag event → update + reverse geocode
    _pointAnnotationManager!.dragEvents(onEnd: (annotation) {
      _selectedLocation = LatLng(
        annotation.geometry.coordinates.lat.toDouble(),
        annotation.geometry.coordinates.lng.toDouble(),
      );
      _reverseGeocode(_selectedLocation!);
    });
  }

  void _onMapClick(MapContentGestureContext context) {
    final latLng = LatLng(
      context.point.coordinates.lat.toDouble(),
      context.point.coordinates.lng.toDouble(),
    );

    _selectedLocation = latLng;

    _addOrUpdateMarker(latLng);
    _reverseGeocode(latLng);
  }

  void _reverseGeocode(LatLng latLng) {
    final key = "${latLng.latitude},${latLng.longitude}";
    if (_reverseGeocodeCache.containsKey(key)) {
      _searchController.text = _reverseGeocodeCache[key]!;
      widget.onSelected(
        MapBoxPlace(
          id: 'reverse_geocode',
          text: _reverseGeocodeCache[key]!,
          placeName: _reverseGeocodeCache[key]!,
          geometry:  Geometry.fromJson(
              Point(
                coordinates: Position(
                  latLng.longitude,
                  latLng.latitude,
                ),
              ).toJson(),
          ),
        ),
        latLng,
      );
      return;
    }

    // Debounce 1 second
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(seconds: 2), () async {
      try {
        final result = await _geoCodingService!.getAddress((
        lat: latLng.latitude,
        long: latLng.longitude,
        ));

        result.fold((success) {
          if (success.isNotEmpty) {
            final place = success.first;
            _reverseGeocodeCache[key] = place.placeName ?? "Position choisie";

            setState(() {
              _searchController.text = place.placeName ?? 'Position choisie';
            });

            widget.onSelected(
              MapBoxPlace(
                id: 'reverse_geocode',
                text: place.placeName ?? 'Position choisie',
                placeName: place.placeName,
                geometry: place.geometry,
              ),
              latLng,
            );
          }
        }, (_) {});
      } catch (_) {}
    });
  }

  void _toggleMapVisibility() {
    setState(() => _showMap = !_showMap);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _selectedLocation = null;
                        _marker = null;
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
                  onPressed: _toggleMapVisibility,
                ),
              ],
            ),
          ),
        ),

        if (_showMap)
          Container(
            height: 300,
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MapWidget(
                cameraOptions: CameraOptions(
                  center: Point(
                    coordinates: Position(
                      _selectedLocation?.latitude ?? _defaultPoint.coordinates.lat,
                      _selectedLocation?.longitude ?? _defaultPoint.coordinates.lng,
                    ),
                  ),
                  zoom: 14.0,
                ),
                key: const ValueKey("mapWidget"),
                onMapCreated: _onMapCreated,
              ),
            ),
          ),

        if (_showMap)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Touchez ou déplacez le marker pour affiner la position',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}