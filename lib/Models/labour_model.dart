// Models/labour_model.dart
import 'package:fnsolutions/Models/quotation_model.dart';

class LabourItem {
  final String id;
  String name;
  String? description;
  double hours;
  double rate;
  DiscountType discountType;
  double discountValue;
  double discountAmount;
  double total;

  LabourItem({
    required this.id,
    required this.name,
    this.description,
    required this.hours,
    required this.rate,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.total,
  });

  LabourItem copyWith({
    String? id,
    String? name,
    String? description,
    double? hours,
    double? rate,
    DiscountType? discountType,
    double? discountValue,
    double? discountAmount,
    double? total,
  }) {
    return LabourItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      hours: hours ?? this.hours,
      rate: rate ?? this.rate,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'hours': hours,
      'rate': rate,
      'discountType': discountType.toString(),
      'discountValue': discountValue,
      'discountAmount': discountAmount,
      'total': total,
    };
  }

  factory LabourItem.fromMap(Map<String, dynamic> map) {
    return LabourItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      hours: (map['hours'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      discountType: map['discountType'] == 'DiscountType.percentage'
          ? DiscountType.percentage
          : DiscountType.amount,
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
    );
  }
}