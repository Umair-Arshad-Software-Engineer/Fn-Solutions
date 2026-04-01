// Models/return_model.dart
import 'package:fnsolutions/Models/quotation_model.dart';

class ReturnModel {
  final String id;
  final String billId;
  final String billNumber;
  final String customerId;
  final String customerName;
  final DateTime returnDate;
  final List<ReturnItem> items;
  final double subtotal;
  final double totalDiscount;
  final double grandTotal;
  final String returnReason;
  final String returnType; // 'full' or 'partial'
  final String status; // 'pending', 'approved', 'completed'
  final String? processedBy;
  final String? processedByName;
  final String? teamId;
  final String? teamName;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReturnModel({
    required this.id,
    required this.billId,
    required this.billNumber,
    required this.customerId,
    required this.customerName,
    required this.returnDate,
    required this.items,
    required this.subtotal,
    required this.totalDiscount,
    required this.grandTotal,
    required this.returnReason,
    required this.returnType,
    required this.status,
    this.processedBy,
    this.processedByName,
    this.teamId,
    this.teamName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billId': billId,
      'billNumber': billNumber,
      'customerId': customerId,
      'customerName': customerName,
      'returnDate': returnDate.toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'totalDiscount': totalDiscount,
      'grandTotal': grandTotal,
      'returnReason': returnReason,
      'returnType': returnType,
      'status': status,
      'processedBy': processedBy,
      'processedByName': processedByName,
      'teamId': teamId,
      'teamName': teamName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReturnModel.fromMap(String id, Map<String, dynamic> map) {
    return ReturnModel(
      id: id,
      billId: map['billId'] ?? '',
      billNumber: map['billNumber'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      returnDate: DateTime.parse(map['returnDate']),
      items: (map['items'] as List)
          .map((e) => ReturnItem.fromMap(e))
          .toList(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      totalDiscount: (map['totalDiscount'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      returnReason: map['returnReason'] ?? '',
      returnType: map['returnType'] ?? 'partial',
      status: map['status'] ?? 'pending',
      processedBy: map['processedBy'],
      processedByName: map['processedByName'],
      teamId: map['teamId'],
      teamName: map['teamName'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

class ReturnItem {
  final String id;
  final String itemName;
  final String? description;
  final double quantity;
  final double rate;
  final double discountValue;
  final DiscountType discountType;
  final double discountAmount;
  final double taxPercent;
  final double taxAmount;
  final double total;
  final double returnedQuantity;
  final String reason;

  ReturnItem({
    required this.id,
    required this.itemName,
    this.description,
    required this.quantity,
    required this.rate,
    required this.discountValue,
    required this.discountType,
    required this.discountAmount,
    required this.taxPercent,
    required this.taxAmount,
    required this.total,
    required this.returnedQuantity,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'description': description,
      'quantity': quantity,
      'rate': rate,
      'discountValue': discountValue,
      'discountType': discountType == DiscountType.percentage ? 'percentage' : 'amount',
      'discountAmount': discountAmount,
      'taxPercent': taxPercent,
      'taxAmount': taxAmount,
      'total': total,
      'returnedQuantity': returnedQuantity,
      'reason': reason,
    };
  }

  factory ReturnItem.fromMap(Map<String, dynamic> map) {
    return ReturnItem(
      id: map['id'] ?? '',
      itemName: map['itemName'] ?? '',
      description: map['description'],
      quantity: (map['quantity'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      discountType: map['discountType'] == 'percentage'
          ? DiscountType.percentage
          : DiscountType.amount,
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      taxPercent: (map['taxPercent'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      returnedQuantity: (map['returnedQuantity'] ?? 0).toDouble(),
      reason: map['reason'] ?? '',
    );
  }
}