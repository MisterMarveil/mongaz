import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_search/models/location.dart';

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
  //final String apiKey;
  final BuildContext context;
  final String hint;
  final Function(MapBoxPlace, LatLng?) onSelected;
  final int limit;
  final String country;

  const MapBoxPlaceSearchWidget({
    Key? key,
    //required this.apiKey,
    required this.context,
    this.hint = 'Rechercher une adresse',
    required this.onSelected,
    this.limit = 5,
    this.country = 'CM',
  }) : super(key: key);

  @override
  _MapBoxPlaceSearchWidgetState createState() => _MapBoxPlaceSearchWidgetState();
}

class _MapBoxPlaceSearchWidgetState extends State<MapBoxPlaceSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<MapBoxPlace> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  bool _showMap = false;
  GeoCoding? _geoCodingService;

  // Map-related variables
  MapboxMap? _mapboxMap;
  //MapboxMapController? _mapController;
  LatLng? _selectedLocation;
  PointAnnotation? _marker;
  PointAnnotationManager? _pointAnnotationManager;

  @override
  void initState() {
    super.initState();
    _initMapBox();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    _mapboxMap?.dispose();
    super.dispose();
  }

  void _initMapBox() {
    //MapBoxSearch.init(widget.apiKey);
    _geoCodingService = GeoCoding(
      //apiKey: widget.apiKey,
      country: widget.country,
      limit: widget.limit,
    );
  }

  void _onFocusChanged() {
    setState(() {
      _showResults = _searchFocusNode.hasFocus && _searchResults.isNotEmpty;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
      });
      return;
    }

    if (query.length < 3) return;

    _performSearch(query);
  }

  void _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final result = await _geoCodingService!.getPlaces(
        query,
        proximity: Proximity.LatLong(
          lat: 3.8480, // Default center for Cameroon
          long: 11.5021,
        ),
      );

      result.fold(
            (success) {
          setState(() {
            _searchResults = success;
            _showResults = _searchFocusNode.hasFocus;
            _isSearching = false;
          });
        },
            (failure) {
          setState(() {
            _searchResults = [];
            _showResults = false;
            _isSearching = false;
          });
          print('Search failed: $failure');
        },
      );
    } catch (e) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
      });
      print('Search error: $e');
    }
  }

  void _onPlaceSelected(MapBoxPlace place) {
    _searchController.text = place.text!;
    _searchFocusNode.unfocus();

    // Extract coordinates from the selected place
    if (place.geometry?.coordinates != null) {
      final double lng = place.geometry!.coordinates.long;
      final double lat = place.geometry!.coordinates.lat;
      _selectedLocation = LatLng(lat, lng);

      // Update map to show the selected location
      _moveCameraToLocation(_selectedLocation!);
      _addOrUpdateMarker(_selectedLocation!);

      setState(() {
        _showResults = false;
        _showMap = true;
      });

      widget.onSelected(place, _selectedLocation);
    } else {
      setState(() {
        _showResults = false;
      });
      widget.onSelected(place, null);
    }
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;
    _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();

    if(_selectedLocation == null){
      _mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: true));
      _selectedLocation = await _mapboxMap?.style.getPuckPosition();

      if (_selectedLocation != null) {
        print('Location: ${_selectedLocation}');
      }else{
        debugPrint("location is null");
      }
    }

    // If we already have a selected location, move camera to it
    if (_selectedLocation != null) {
      _moveCameraToLocation(_selectedLocation!);
      _addOrUpdateMarker(_selectedLocation!);
    }
  }

  void _moveCameraToLocation(LatLng location) {
    _mapboxMap?.easeTo(
        CameraOptions(
            center: Point(
                coordinates: Position(
                  location.latitude,
                  location.longitude,
                )),
            zoom: 17,
            bearing: 180,
            pitch: 30),
        MapAnimationOptions(duration: 2000, startDelay: 0));
  }

  void _addOrUpdateMarker(LatLng location) async {
    if(_mapboxMap == null || _pointAnnotationManager == null) return;

    if(_marker != null)
      _pointAnnotationManager!.delete(_marker!);

    final ByteData bytes =  await rootBundle.load('assets/images/pos-marker.png');

    _pointAnnotationManager!.create(PointAnnotationOptions(
      geometry: Point(
          coordinates: Position(
            location.latitude,
            location.longitude,
          ),
      ),
      image: bytes.buffer.asUint8List(),
      textField:  "client",
      isDraggable: true,
    )).then((value) => _marker = value);

    _pointAnnotationManager!.dragEvents(
      onEnd: (annotation) {
        _selectedLocation = LatLng(annotation.geometry.coordinates.lat.toDouble(), annotation.geometry.coordinates.lng.toDouble());

        print("point lat: ${annotation.geometry.coordinates.lat} long: ${annotation.geometry.coordinates.lng} drag end");
      },
    );
  }


  void _onMapClick(Point point, LatLng latLng) {
    // Update selected location when user clicks on the map
    _addOrUpdateMarker(latLng);
  }

  void _reverseGeocode(LatLng latLng) async {
    try {
      final result = await _geoCodingService!.getAddress((
      lat: latLng.latitude,
      long: latLng.longitude,
      ));

      result.fold(
            (success) {
          if (success.isNotEmpty) {
            final place = success.first;
            setState(() {
              _searchController.text = place.placeName ?? 'Selected Location';
            });

            // Create a minimal MapBoxPlace object with the text
            final minimalPlace = MapBoxPlace(
              id: 'reverse_geocode',
              text: place.placeName ?? 'Selected Location',
              placeName: place.placeName,
              geometry: place.geometry,
            );

            widget.onSelected(minimalPlace, latLng);
          }
        },
            (failure) {
          print('Reverse geocoding failed: $failure');
          setState(() {
            _searchController.text = 'Location: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
          });
        },
      );
    } catch (e) {
      print('Reverse geocoding error: $e');
      setState(() {
        _searchController.text = 'Location: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
      });
    }
  }

  void _toggleMapVisibility() {
    setState(() {
      _showMap = !_showMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
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
                        _showResults = false;
                        _selectedLocation = null;
                        _marker = null;
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
                  onPressed: _toggleMapVisibility,
                  tooltip: _showMap ? 'Hide map' : 'Show map',
                ),
              ],
            ),
          ),
        ),

        // Search results
        if (_showResults)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final place = _searchResults[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, size: 20),
                  title: Text(
                    place.text ?? 'Unknown',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: place.placeName != null
                      ? Text(
                    place.placeName!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                      : null,
                  onTap: () => _onPlaceSelected(place),
                  dense: true,
                );
              },
            ),
          ),

        // Interactive map
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
                key: ValueKey("mapWidget"),
                onMapCreated: _onMapCreated,
              ),
            ),
          ),

        // Instructions
        if (_showMap)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Tap on the map to select a precise location',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}