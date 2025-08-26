// point_of_sale.dart
class PointOfSale {
  final String id;
  final String name;
  final String? address;
  final String lat;
  final String lon;

  PointOfSale({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
  });

  factory PointOfSale.fromJson(Map<String, dynamic> json) {
    return PointOfSale(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      lat: json['lat'],
      lon: json['lon']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lon': lon
    };
  }
}

class PointOfSaleCollection {
  final List<PointOfSale> member;
  final int totalItems;
  final Map<String, dynamic> view;
  final Map<String, dynamic> search;

  PointOfSaleCollection({
    required this.member,
    required this.totalItems,
    required this.view,
    required this.search,
  });

  factory PointOfSaleCollection.fromJson(Map<String, dynamic> json) {
    return PointOfSaleCollection(
      member: (json['member'] as List<dynamic>?)
          ?.map((item) => PointOfSale.fromJson(item))
          .toList() ?? [],
      totalItems: json['totalItems'] ?? 0,
      view: json['view'] ?? {},
      search: json['search'] ?? {},
    );
  }
}