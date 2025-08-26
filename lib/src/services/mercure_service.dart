import 'dart:async';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongaz/src/screens/core/contants.dart';
import 'api_service.dart';

enum MercureConnectionState {
  connected,
  disconnected,
  connecting,
  error,
}

final mercureServiceProvider = Provider<MercureService>((ref) {
  final api = ref.watch(apiServiceProvider);
  return MercureService.instance(
    api,
    issuer: kSSEIssuer,
  );
});

final mercureConnectionStateProvider = StreamProvider<MercureConnectionState>((ref) {
  final mercureService = ref.watch(mercureServiceProvider);
  return mercureService.connectionState;
});

class MercureService {
  static MercureService? _instance;

  final ApiService _apiService;
  String? _mercureHubUrl;
  String? _jwtSecret;
  final String _issuer;

  Stream<SSEModel>? _sseStream;
  StreamSubscription<SSEModel>? _subscription;
  final Map<String, StreamController<SSEModel>> _topicControllers = {};

  // Track all subscribed topics
  final Set<String> _subscribedTopics = {};

  // Add connection state tracking
  final StreamController<MercureConnectionState> _connectionStateController =
  StreamController<MercureConnectionState>.broadcast();
  MercureConnectionState _currentState = MercureConnectionState.disconnected;

  // Add getter for connection state stream
  Stream<MercureConnectionState> get connectionState => _connectionStateController.stream;

  MercureService._internal(
      this._apiService, {
        required String issuer,
      })  : _issuer = issuer {
    // Initialize with disconnected state
    _connectionStateController.add(_currentState);
  }

  factory MercureService.instance(
      ApiService apiService, {
        required String issuer,
      }) {
    _instance ??= MercureService._internal(
      apiService,
      issuer: issuer,
    );
    return _instance!;
  }

  // Method to fetch configuration from API if not already set
  Future<void> _ensureConfig() async {
    if (_mercureHubUrl == null || _jwtSecret == null) {
      try {
        final envVars = await _apiService.getEnvVars([
          'MERCURE_SSE_URL',
          'MERCURE_SUBSCRIBER_TOKEN'
        ]);

        _mercureHubUrl = envVars['MERCURE_SSE_URL'];
        _jwtSecret = envVars['MERCURE_SUBSCRIBER_TOKEN'];

        if (_mercureHubUrl == null || _jwtSecret == null) {
          throw Exception('Failed to retrieve Mercure configuration from API');
        }
      } catch (e) {
        _updateConnectionState(MercureConnectionState.error);
        rethrow;
      }
    }
  }

  Future<void> connect(List<String> topics) async {
    _updateConnectionState(MercureConnectionState.connecting);

    // Ensure we have the configuration
    await _ensureConfig();

    // Close existing connection if any
    unsubscribe();

    // Update subscribed topics
    _subscribedTopics.clear();
    _subscribedTopics.addAll(topics);

    //ensures unique element in topics by doing a set
    topics = topics.toSet().toList();

    final token = _generateToken(topics);
    final url = '$_mercureHubUrl?topic=${topics.join('&topic=')}';

    try {
      _sseStream = SSEClient.subscribeToSSE(
        method: SSERequestType.GET,
        url: url,
        header: {
          'Authorization': 'Bearer $token',
          'Accept': 'text/event-stream',
        },
      );

      _subscription = _sseStream!.listen(
            (event) {
          // Broadcast event to all topic-specific streams
          if (event.event != null && _topicControllers.containsKey(event.event!)) {
            _topicControllers[event.event!]!.add(event);
          }
        },
        onError: (error) {
          _updateConnectionState(MercureConnectionState.error);
          // Attempt to reconnect after a delay
          Future.delayed(Duration(seconds: 5), () => connect(_subscribedTopics.toList()));
        },
        onDone: () {
          _updateConnectionState(MercureConnectionState.disconnected);
        },
        cancelOnError: true,
      );

      _updateConnectionState(MercureConnectionState.connected);
    } catch (e) {
      _updateConnectionState(MercureConnectionState.error);
      rethrow;
    }
  }

  void _updateConnectionState(MercureConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  // getter to access the current state
  MercureConnectionState get currentConnectionState => _currentState;

  // Enhanced methods for dynamic topic management
  Future<void> addTopics(List<String> topics) async {
    if (topics.isEmpty) return;

    // Add new topics to our set
    _subscribedTopics.addAll(topics);

    // If we're currently connected, reconnect with the new topics
    if (_currentState == MercureConnectionState.connected) {
      await connect(_subscribedTopics.toList());
    }
    // If we're not connected, the topics will be used on the next connect call
  }

  Future<void> removeTopics(List<String> topics) async {
    if (topics.isEmpty) return;

    // Remove topics from our set
    _subscribedTopics.removeAll(topics);

    // Also remove any stream controllers for these topics
    for (final topic in topics) {
      if (_topicControllers.containsKey(topic)) {
        _topicControllers[topic]!.close();
        _topicControllers.remove(topic);
      }
    }

    // If we're currently connected, reconnect with the remaining topics
    if (_currentState == MercureConnectionState.connected && _subscribedTopics.isNotEmpty) {
      await connect(_subscribedTopics.toList());
    } else if (_subscribedTopics.isEmpty) {
      // If no topics left, disconnect
      unsubscribe();
    }
  }

  // Get a list of all currently subscribed topics
  List<String> get subscribedTopics => _subscribedTopics.toList();

  // Check if a specific topic is currently subscribed
  bool isSubscribedTo(String topic) => _subscribedTopics.contains(topic);

  String _generateToken(List<String> topics) {
    final payload = {
      'mercure': {
        'subscribe': topics,
      },
      'iss': _issuer,
    };

    final secretKey = SecretKey(_jwtSecret!);
    final jwt = JWT(payload);
    return jwt.sign(secretKey, algorithm: JWTAlgorithm.HS256);
  }

  Stream<SSEModel> getTopicStream(String topic) {
    if (!_topicControllers.containsKey(topic)) {
      _topicControllers[topic] = StreamController<SSEModel>.broadcast();
    }
    return _topicControllers[topic]!.stream;
  }

  void unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
    _sseStream = null;
    _updateConnectionState(MercureConnectionState.disconnected);
  }

  Future<void> publish({
    required String message,
    required String event,
    String role = 'ROLE_DRIVER',
    List<String>? userIds,
    Map<String, dynamic>? extra,
  }) async {
    await _apiService.notify(
      message: message,
      event: event,
      role: role,
      userIds: userIds,
      extra: extra,
    );
  }

  Future<void> notifyOrderAssignment({
    required String orderId,
    required List<String> driverIds,
    String message = 'New order assigned',
  }) async {
    await publish(
      message: message,
      event: 'order.assigned',
      userIds: driverIds,
      extra: {
        'orderId': orderId,
        'assignedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  void dispose() {
    unsubscribe();
    for (final controller in _topicControllers.values) {
      controller.close();
    }
    _topicControllers.clear();
    _subscribedTopics.clear();
    _connectionStateController.close();
    _instance = null;
  }
}