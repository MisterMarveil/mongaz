// order.dart (updated)
class OrderItem {
  final String id;
  final String brand;
  final String capacity;
  final int quantity;

  OrderItem({
    required this.id,
    required this.brand,
    required this.capacity,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'] ?? '',
    brand: json['brand'] ?? '',
    capacity: json['capacity'] ?? '',
    quantity: json['quantity'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'capacity': capacity,
    'quantity': quantity,
  };
}

class OrderItemCollection {
  final List<OrderItem> member;
  final int totalItems;
  final Map<String, dynamic> view;
  final Map<String, dynamic> search;

  OrderItemCollection({
    required this.member,
    required this.totalItems,
    required this.view,
    required this.search,
  });

  factory OrderItemCollection.fromJson(Map<String, dynamic> json) {
    return OrderItemCollection(
      member: (json['member'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ?? [],
      totalItems: json['totalItems'] ?? 0,
      view: json['view'] ?? {},
      search: json['search'] ?? {},
    );
  }
}

enum OrderStatus {
  AWAITING_ASSIGNMENT,
  ASSIGNED,
  DELIVERY_IN_PROGRESS,
  DELIVERY_CONFIRMED,
  DELIVERY_CANCELED
}

extension OrderStatusExtension on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.AWAITING_ASSIGNMENT:
        return 'AWAITING_ASSIGNMENT';
      case OrderStatus.ASSIGNED:
        return 'ASSIGNED';
      case OrderStatus.DELIVERY_IN_PROGRESS:
        return 'DELIVERY_IN_PROGRESS';
      case OrderStatus.DELIVERY_CONFIRMED:
        return 'DELIVERY_CONFIRMED';
      case OrderStatus.DELIVERY_CANCELED:
        return 'DELIVERY_CANCELED';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'AWAITING_ASSIGNMENT':
        return OrderStatus.AWAITING_ASSIGNMENT;
      case 'ASSIGNED':
        return OrderStatus.ASSIGNED;
      case 'DELIVERY_IN_PROGRESS':
        return OrderStatus.DELIVERY_IN_PROGRESS;
      case 'DELIVERY_CONFIRMED':
        return OrderStatus.DELIVERY_CONFIRMED;
      case 'DELIVERY_CANCELED':
        return OrderStatus.DELIVERY_CANCELED;
      default:
        return OrderStatus.AWAITING_ASSIGNMENT;
    }
  }
}

class Order {
  final String id;
  final String customerPhone;
  final String? customerName;
  final List<OrderItem> items;
  final String amount;
  final String address;
  final String lat;
  final String lon;
  final OrderStatus status;
  final String? assignedDriver;
  final String? createdBy;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.customerPhone,
    this.customerName,
    required this.items,
    required this.amount,
    required this.address,
    required this.lat,
    required this.lon,
    required this.status,
    this.assignedDriver,
    this.createdBy,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerName: json['customerName'],
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ?? [],
      amount: json['amount'] ?? '0.0',
      address: json['address'] ?? '',
      lat: json['lat'] ?? '',
      lon: json['lon'] ?? '',
      status: OrderStatusExtension.fromString(json['status'] ?? 'AWAITING_ASSIGNMENT'),
      assignedDriver: json['assignedDriver'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'customerPhone': customerPhone,
    'customerName': customerName,
    'items': items.map((item) => item.toJson()).toList(),
    'amount': amount,
    'address': address,
    'lat': lat,
    'lon': lon,
    'status': status.value,
  };
}

class OrderCollection {
  final List<Order> member;
  final int totalItems;
  final Map<String, dynamic> view;
  final Map<String, dynamic> search;

  OrderCollection({
    required this.member,
    required this.totalItems,
    required this.view,
    required this.search,
  });

  factory OrderCollection.fromJson(Map<String, dynamic> json) {
    return OrderCollection(
      member: (json['member'] as List<dynamic>?)
          ?.map((item) => Order.fromJson(item))
          .toList() ?? [],
      totalItems: json['totalItems'] ?? 0,
      view: json['view'] ?? {},
      search: json['search'] ?? {},
    );
  }
}