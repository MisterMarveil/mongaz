// comment.dart
class Comment {
  final String id;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
    };
  }
}

class CommentCollection {
  final List<Comment> member;
  final int totalItems;
  final Map<String, dynamic> view;
  final Map<String, dynamic> search;

  CommentCollection({
    required this.member,
    required this.totalItems,
    required this.view,
    required this.search,
  });

  factory CommentCollection.fromJson(Map<String, dynamic> json) {
    return CommentCollection(
      member: (json['member'] as List<dynamic>?)
          ?.map((item) => Comment.fromJson(item))
          .toList() ?? [],
      totalItems: json['totalItems'] ?? 0,
      view: json['view'] ?? {},
      search: json['search'] ?? {},
    );
  }
}