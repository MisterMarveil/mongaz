// services/network_service.dart
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NetworkService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  bool _isChecking = false;

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;

  NetworkService() {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity status
    await checkConnection();

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        // When connectivity returns, verify with a real network request
        await checkConnectionWithRequest();
      } else {
        _updateConnectionStatus(false);
      }
    });
  }

  Future<void> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result != ConnectivityResult.none);
  }

  Future<void> checkConnectionWithRequest() async {
    if (_isChecking) return;

    _isChecking = true;
    notifyListeners();

    try {
      // Try to reach a reliable endpoint
      final response = await http.get(
        Uri.parse('https://api.mongaz.b-cash.shop/api/_health'),
      ).timeout(const Duration(seconds: 15));

      _updateConnectionStatus(response.statusCode == 200);
    } on SocketException catch (_) {
      _updateConnectionStatus(false);
    } on TimeoutException catch (_) {
      _updateConnectionStatus(false);
    } catch (_) {
      _updateConnectionStatus(false);
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(bool newStatus) {
    if (_isConnected != newStatus) {
      _isConnected = newStatus;
      notifyListeners();
    }
  }
}