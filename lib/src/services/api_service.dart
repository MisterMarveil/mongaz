// api_service.dart (updated)
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:toast/toast.dart';

// Import all the models
import '../models/errors.dart';
import '../models/activity_logs.dart';
import '../models/comment.dart';
import '../models/driver_profile.dart';
import '../models/order.dart';
import '../models/point_of_sale.dart';
import '../models/system.dart';
import '../models/users.dart';
import '../models/api_response.dart';

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  late Stream<SSEModel> _subscription;
  final _baseUrl = "https://api.mongaz.b-cash.shop";

  ApiService()
      : _dio = Dio(BaseOptions(
    baseUrl: "https://api.mongaz.b-cash.shop",
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  )),
        _storage = const FlutterSecureStorage() {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final opts = e.requestOptions;
            opts.headers['Authorization'] = _dio.options.headers['Authorization'];
            try {
              final cloneResponse = await _dio.fetch(opts);
              return handler.resolve(cloneResponse);
            } catch (err) {
              return handler.reject(err as DioException);
            }
          } else {
            await logout();
          }
        }

        // Handle validation errors
        if (e.response?.statusCode == 422) {
          try {
            final violations = ConstraintViolationList.fromJson(e.response?.data);
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              error: violations,
              response: e.response,
              type: e.type,
            ));
          } catch (parseError) {
            debugPrint('Failed to parse constraint violations: $parseError');
          }
        }

        // Handle other API errors
        if (e.response?.statusCode != null && e.response!.statusCode! >= 400) {
          try {
            final error = ApiError.fromJson(e.response?.data);
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              error: error,
              response: e.response,
              type: e.type,
            ));
          } catch (parseError) {
            debugPrint('Failed to parse API error: $parseError');
          }
        }

        return handler.next(e);
      },
    ));
  }

  Future<void> setAuthToken(Map<String, dynamic> result) async {
    await _storage.write(key: 'access_token', value: result['token']);
    await _storage.write(key: 'user_role', value: result['user']?['role']?.toString() ?? 'user');
    await _storage.write(key: 'user_id', value: result['user']?['id'] ?? '');
    await _storage.write(key: 'user_phone', value: result['user']?['phone'] ?? '');
    _dio.options.headers['Authorization'] = 'Bearer ${result['token']}';
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<User> login(String phone, String password) async {
    print("trying to connect with $phone and $password");
    try {
      final response = await _dio.post(
        '/api/login',
        data: {
          'phone': phone,
          'password': password,
        },
      );

      // On suppose que la réponse API est au format :
      // {
      //   "token": "...",
      //   "refresh_token": "...",
      //   "user": { "id": "...", "phone": "...", "name": "...", "roles": [...] }
      // }

      final data = response.data as Map<String, dynamic>;
      print("received from API: $data");

      if(response.statusCode == 200) {
        // Créer l'objet User avec la méthode corrigée
        final user = User.fromApiResponse(data);

        // Sauvegarder les tokens dans le stockage sécurisé
        await _storage.write(key: 'access_token', value: user.token);
        await _storage.write(key: 'refresh_token', value: user.refreshToken);
        await _storage.write(key: 'password', value: password);

        // Sauvegarder éventuellement les infos de l'utilisateur
        await _storage.write(key: 'user_id', value: user.id);
        await _storage.write(key: 'user_phone', value: user.phone);
        if (user.name != null) {
          await _storage.write(key: 'user_name', value: user.name!);
        }

        return user;
      }
      throw Exception("Oops! something went wrong");
    } on DioException catch (e) {
      debugPrint('Login error: ${e.response?.data}');
      rethrow;
    }
  }

  Future<ApiResponse<String>> sendResetCode(String phoneNumber) async {
    try {
      final response = await _dio.post(
        '/api/users/request-password-reset',
        data: {'phone': phoneNumber},
      );

      return ApiResponse.fromJson(
        response.data,
            (data) => data != null ? data.toString() : '',
      );
    } on DioException catch (e) {
      debugPrint('Send reset code error: ${e.response?.data}');
      return ApiResponse(
        success: false,
        error: e.response?.data != null
            ? ApiError.fromJson(e.response!.data['error'])
            : null,
      );
    }
  }

  Future<bool> verifyResetCode(String phoneNumber, String resetCode) async {
    try {
      final response = await _dio.post(
        '/api/users/verify-reset-password-code',
        data: {
          'phone': phoneNumber,
          'code': resetCode,
        },
      );

      final result = ApiResponse.fromJson(response.data, (data) => data);
      if(result.success)
        await _storage.write(key: 'reset_code', value: resetCode);

      return result.success;
    } on DioException catch (e) {
      debugPrint('Verify reset code error: ${e.response?.data}');
      return false;
    }
  }

  Future<ApiResponse<String>> resetPassword(String phoneNumber, String newPassword) async {
    try {
      final response = await _dio.post(
        '/api/users/reset-password',
        data: {
          'phone': phoneNumber,
          'password': newPassword,
          'reset_code': await _storage.read(key: 'reset_code'),
        },
      );

      return ApiResponse.fromJson(
        response.data,
            (data) => data != null ? data.toString() : '',
      );
    } on DioException catch (e) {
      debugPrint('Reset password error: ${e.response?.data}');
      return ApiResponse(
        success: false,
        error: e.response?.data != null
            ? ApiError.fromJson(e.response!.data['error'])
            : null,
      );
    }
  }


  // Activity Logs
  Future<ActivityLogCollection> getActivityLogs({int page = 1}) async {
    try {
      final response = await _dio.get('/api/activity_logs', queryParameters: {
        'page': page,
      });
      return ActivityLogCollection.fromJson(response.data);
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      }
      rethrow;
    }
  }

  Future<ActivityLog> createActivityLog(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/api/activity_logs', data: data);
      return ActivityLog.fromJson(response.data);
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      } else if (e.error is ConstraintViolationList) {
        throw e.error as ConstraintViolationList;
      }
      rethrow;
    }
  }

  // Comments
  Future<CommentCollection> getComments({int page = 1}) async {
    try {
      final response = await _dio.get('/api/comments', queryParameters: {
        'page': page,
      });
      return CommentCollection.fromJson(response.data);
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      }
      rethrow;
    }
  }

  Future<Comment> createComment(String text) async {
    try {
      final response = await _dio.post('/api/comments', data: {
        'text': text,
      });
      return Comment.fromJson(response.data);
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      } else if (e.error is ConstraintViolationList) {
        throw e.error as ConstraintViolationList;
      }
      rethrow;
    }
  }

  // Driver Operations
  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    try {
      final response = await _dio.post('/api/drivers/current/accept', data: {
        'order_id': orderId,
      });
      return response.data;
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      }
      rethrow;
    }
  }

  Future<void> updateAvailability(bool available) async {
    try {
      await _dio.post('/api/drivers/current/availability', data: {
        'available': available,
      });
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      } else if (e.error is ConstraintViolationList) {
        throw e.error as ConstraintViolationList;
      }
      rethrow;
    }
  }

  // Add similar methods for other driver operations...

  // Orders
  Future<Order> createOrder(Order order) async {
    try {
      final response = await _dio.post('/api/orders', data: order.toJson());
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      } else if (e.error is ConstraintViolationList) {
        throw e.error as ConstraintViolationList;
      }
      rethrow;
    }
  }

  Future<List<Order>> getOrders({OrderStatus? status}) async {
    try {
      print("trying to retrieve orders with status: ${status?.value}");

      final response = await _dio.get('/api/orders', queryParameters: {
        if (status != null) 'status': status.value,
      });

      debugPrint(response.data.toString());
      // Handle both collection response and simple array response
      if (response.data is Map && response.data.containsKey('member')) {
        final collection = OrderCollection.fromJson(response.data);
        return collection.member;
      } else if (response.data is List) {
        return (response.data as List).map((e) => Order.fromJson(e)).toList();
      }

      return [];
    } on DioException catch (e) {
      if (e.error is ApiError) {
        throw e.error as ApiError;
      }
      rethrow;
    }
  }

  Future<bool> _refreshToken() async {
    final password = await _storage.read(key: 'password');
    final phone = await _storage.read(key: 'user_phone');
    if (phone == null || password == null) {
      debugPrint('Refresh token failed: phone or password not found');
      await logout();
      return false;
    }

    // Create a new Dio instance without interceptors for token refresh
    final refreshDio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    try {
      final response = await refreshDio.post(
        '/api/login',
        data: {'phone': phone, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      if (response.statusCode == 200) {
        // Update storage with new tokens
        await _storage.write(key: 'access_token', value: data['token']);
        await _storage.write(key: 'refresh_token', value: data['refresh_token']);

        // Update the main Dio instance headers
        _dio.options.headers['Authorization'] = 'Bearer ${data['token']}';

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Refresh token failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _dio.options.headers.remove('Authorization');
  }

  // Mercure SSE subscribe
  Future<Stream<SSEModel>> subscribeToTopic(String hubUrl, String topic, String jwt) async {
    final jwt = await getAuthToken();
    if (jwt == null) {
      throw Exception('No auth token available for SSE subscription');
    }

    _subscription = SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: '$hubUrl?topic=$topic',
      header: {'Authorization': 'Bearer $jwt'},
    );

    return _subscription;
  }
}