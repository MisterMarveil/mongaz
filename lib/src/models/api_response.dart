// api_response.dart
import 'errors.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;
  final ConstraintViolationList? violations;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.violations,
  });

  factory ApiResponse.fromJson(
      Map<String, dynamic> json,
      T Function(dynamic) fromJsonT,
      ) {
    return ApiResponse(
      success: json['status'] == 'success',
      data: fromJsonT(json['data']),
      error: json['error'] != null ? ApiError.fromJson(json['error']) : null,
      violations: json['violations'] != null
          ? ConstraintViolationList.fromJson(json['violations'])
          : null,
    );
  }
}