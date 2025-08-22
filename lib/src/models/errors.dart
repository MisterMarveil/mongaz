
class ApiError {
  final String title;
  final String detail;
  final int status;
  final String? instance;
  final String type;

  ApiError({
    required this.title,
    required this.detail,
    required this.status,
    this.instance,
    required this.type,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      title: json['title'] ?? 'Error',
      detail: json['detail'] ?? 'An error occurred',
      status: json['status'] ?? 500,
      instance: json['instance'],
      type: json['type'] ?? 'about:blank',
    );
  }
}

class ConstraintViolation {
  final String propertyPath;
  final String message;

  ConstraintViolation({
    required this.propertyPath,
    required this.message,
  });

  factory ConstraintViolation.fromJson(Map<String, dynamic> json) {
    return ConstraintViolation(
      propertyPath: json['propertyPath'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class ConstraintViolationList {
  final int status;
  final List<ConstraintViolation> violations;
  final String detail;
  final String type;
  final String? title;
  final String? instance;

  ConstraintViolationList({
    this.status = 422,
    required this.violations,
    required this.detail,
    required this.type,
    this.title,
    this.instance,
  });

  factory ConstraintViolationList.fromJson(Map<String, dynamic> json) {
    return ConstraintViolationList(
      status: json['status'] ?? 422,
      violations: (json['violations'] as List<dynamic>?)
          ?.map((v) => ConstraintViolation.fromJson(v))
          .toList() ?? [],
      detail: json['detail'] ?? '',
      type: json['type'] ?? '',
      title: json['title'],
      instance: json['instance'],
    );
  }
}