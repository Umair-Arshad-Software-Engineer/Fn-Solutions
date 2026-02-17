enum DiscountType {
  percentage,
  amount
}

class QuotationItem {
  String id;
  String name;
  String description;
  double quantity;
  double rate;

  // Discount can be percentage or amount
  DiscountType discountType;
  double discountValue; // Either percentage or fixed amount
  double discountAmount; // Calculated discount amount

  double taxPercent;
  double taxAmount;
  double total;

  QuotationItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.quantity,
    required this.rate,
    this.discountType = DiscountType.percentage,
    this.discountValue = 0.0,
    this.discountAmount = 0.0,
    this.taxPercent = 0.0,
    this.taxAmount = 0.0,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'quantity': quantity,
      'rate': rate,
      'discountType': discountType.toString().split('.').last,
      'discountValue': discountValue,
      'discountAmount': discountAmount,
      'taxPercent': taxPercent,
      'taxAmount': taxAmount,
      'total': total,
    };
  }

  factory QuotationItem.fromMap(Map<String, dynamic> map) {
    return QuotationItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      discountType: _parseDiscountType(map['discountType']),
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      taxPercent: (map['taxPercent'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
    );
  }

  static DiscountType _parseDiscountType(String? type) {
    if (type == 'amount') return DiscountType.amount;
    return DiscountType.percentage;
  }

  QuotationItem copyWith({
    String? id,
    String? name,
    String? description,
    double? quantity,
    double? rate,
    DiscountType? discountType,
    double? discountValue,
    double? discountAmount,
    double? taxPercent,
    double? taxAmount,
    double? total,
  }) {
    return QuotationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountAmount: discountAmount ?? this.discountAmount,
      taxPercent: taxPercent ?? this.taxPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
    );
  }
}

class QuotationModel {
  final String id;
  final String quotationNumber;
  final String customerId;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerAddress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime validUntil;
  final String createdBy;
  final String createdByName;
  final String status; // Draft, Sent, Accepted, Rejected, Expired
  final List<QuotationItem> items;

  // Discounts
  final double subtotal;
  final double itemDiscountTotal;

  // Grand discount can be percentage or amount
  final DiscountType grandDiscountType;
  final double grandDiscountValue;
  final double grandDiscountAmount;

  final double taxTotal;
  final double grandTotal;

  // Additional fields
  final String? notes;
  final String? termsAndConditions;
  final String? teamId;
  final String? teamName;

  QuotationModel({
    required this.id,
    required this.quotationNumber,
    required this.customerId,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.customerAddress,
    required this.createdAt,
    required this.updatedAt,
    required this.validUntil,
    required this.createdBy,
    required this.createdByName,
    this.status = 'Draft',
    required this.items,
    required this.subtotal,
    required this.itemDiscountTotal,
    this.grandDiscountType = DiscountType.percentage,
    this.grandDiscountValue = 0.0,
    required this.grandDiscountAmount,
    required this.taxTotal,
    required this.grandTotal,
    this.notes,
    this.termsAndConditions,
    this.teamId,
    this.teamName,
  });

  Map<String, dynamic> toMap() {
    return {
      'quotationNumber': quotationNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'itemDiscountTotal': itemDiscountTotal,
      'grandDiscountType': grandDiscountType.toString().split('.').last,
      'grandDiscountValue': grandDiscountValue,
      'grandDiscountAmount': grandDiscountAmount,
      'taxTotal': taxTotal,
      'grandTotal': grandTotal,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
      'teamId': teamId,
      'teamName': teamName,
    };
  }

  factory QuotationModel.fromMap(String id, Map<String, dynamic> map) {
    List<QuotationItem> items = [];
    if (map['items'] != null) {
      items = (map['items'] as List)
          .map((item) => QuotationItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return QuotationModel(
      id: id,
      quotationNumber: map['quotationNumber'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerEmail: map['customerEmail'],
      customerPhone: map['customerPhone'],
      customerAddress: map['customerAddress'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      validUntil: DateTime.parse(map['validUntil'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String()),
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      status: map['status'] ?? 'Draft',
      items: items,
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      itemDiscountTotal: (map['itemDiscountTotal'] ?? 0).toDouble(),
      grandDiscountType: _parseDiscountType(map['grandDiscountType']),
      grandDiscountValue: (map['grandDiscountValue'] ?? 0).toDouble(),
      grandDiscountAmount: (map['grandDiscountAmount'] ?? 0).toDouble(),
      taxTotal: (map['taxTotal'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      notes: map['notes'],
      termsAndConditions: map['termsAndConditions'],
      teamId: map['teamId'],
      teamName: map['teamName'],
    );
  }

  static DiscountType _parseDiscountType(String? type) {
    if (type == 'amount') return DiscountType.amount;
    return DiscountType.percentage;
  }
}