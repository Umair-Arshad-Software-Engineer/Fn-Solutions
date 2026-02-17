// Models/payment_model.dart
class PaymentModel {
  final String id;
  final String billId;
  final String billNumber;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? reference;
  final double? discountApplied;
  final String? discountReason;
  final String processedBy;
  final String processedByName;
  final String? teamId;
  final String? teamName;

  PaymentModel({
    required this.id,
    required this.billId,
    required this.billNumber,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.reference,
    this.discountApplied,
    this.discountReason,
    required this.processedBy,
    required this.processedByName,
    this.teamId,
    this.teamName,
  });

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'billNumber': billNumber,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentMethod': paymentMethod,
      'reference': reference,
      'discountApplied': discountApplied,
      'discountReason': discountReason,
      'processedBy': processedBy,
      'processedByName': processedByName,
      'teamId': teamId,
      'teamName': teamName,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory PaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentModel(
      id: id,
      billId: map['billId'] ?? '',
      billNumber: map['billNumber'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentDate: DateTime.parse(map['paymentDate'] ?? DateTime.now().toIso8601String()),
      paymentMethod: map['paymentMethod'] ?? '',
      reference: map['reference'],
      discountApplied: map['discountApplied']?.toDouble(),
      discountReason: map['discountReason'],
      processedBy: map['processedBy'] ?? '',
      processedByName: map['processedByName'] ?? '',
      teamId: map['teamId'],
      teamName: map['teamName'],
    );
  }
}