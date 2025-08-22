import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/order.dart';

class DriverMapTracking extends StatefulWidget {
  final Order order;
  const DriverMapTracking({super.key, required this.order});
  @override
  State<StatefulWidget> createState() => _DriverMapTrackingState();
}

class _DriverMapTrackingState extends State<DriverMapTracking> {
  LatLng _current = LatLng(3.8480, 11.5021); // default - Yaounde as example
  MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    setState(() => _current = LatLng(pos.latitude, pos.longitude));
    _mapController.move(_current, 15);
    // start sending location to backend periodically
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _current, initialZoom: 13.0),
        children: [
          TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a','b','c']),
          MarkerLayer(
              markers: [
                Marker(point: _current, width: 60, height: 60, child:  const Icon(Icons.location_on, size: 40)),
                // If you have destination coordinate, add marker
              ]
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final pos = await Geolocator.getCurrentPosition();
          setState(() { _current = LatLng(pos.latitude, pos.longitude); });
          _mapController.move(_current, 15);
          // send update to backend
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
