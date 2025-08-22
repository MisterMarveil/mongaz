
class ActivityLog {
  final String id;
  final String type;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  ActivityLog({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.data,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      type: json['@type'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toString()),
      data: json,
    );
  }
}

class ActivityLogCollection {
  final List<ActivityLog> member;
  final int totalItems;
  final Map<String, dynamic> view;
  final Map<String, dynamic> search;

  ActivityLogCollection({
    required this.member,
    required this.totalItems,
    required this.view,
    required this.search,
  });

  factory ActivityLogCollection.fromJson(Map<String, dynamic> json) {
    return ActivityLogCollection(
      member: (json['member'] as List<dynamic>?)
          ?.map((item) => ActivityLog.fromJson(item))
          .toList() ?? [],
      totalItems: json['totalItems'] ?? 0,
      view: json['view'] ?? {},
      search: json['search'] ?? {},
    );
  }
}