// Models/bill_model.dart
import 'quotation_model.dart';
import 'labour_model.dart';

class BillModel {
  final String id;
  final String billNumber;

  // Quotation Reference
  final String? quotationId;
  final String? quotationNumber;

  // Customer Details
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String? customerAddress;

  // Material Items (from quotation or new)
  final List<QuotationItem> materialItems;

  // Labour Items
  final List<LabourItem> labourItems;

  // Labour Option Flag - NEW FIELD
  final bool isLabourProvidedByUs;

  // Bill Dates
  final DateTime billDate;
  final DateTime dueDate;
  final DateTime? paidDate;

  // Financial Summary
  final double materialSubtotal;
  final double materialDiscountTotal;
  final double materialTaxTotal;
  final double materialTotal;

  final double labourSubtotal;
  final double labourDiscountTotal;
  final double labourTotal;

  // Grand Discount on overall bill
  final DiscountType grandDiscountType;
  final double grandDiscountValue;
  final double grandDiscountAmount;

  final double taxTotal;
  final double grandTotal;

  // Payment
  final double amountPaid;
  final double balanceDue;
  final String paymentStatus; // Paid, Partial, Unpaid, Overdue
  final String? paymentMethod;
  final DateTime? paymentDate;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String createdByName;
  final String? teamId;
  final String? teamName;

  // Additional Info
  final String? notes;
  final String? termsAndConditions;

  BillModel({
    required this.id,
    required this.billNumber,
    this.quotationId,
    this.quotationNumber,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    this.customerAddress,
    required this.materialItems,
    required this.labourItems,
    required this.isLabourProvidedByUs, // NEW FIELD - required
    required this.billDate,
    required this.dueDate,
    this.paidDate,
    required this.materialSubtotal,
    required this.materialDiscountTotal,
    required this.materialTaxTotal,
    required this.materialTotal,
    required this.labourSubtotal,
    required this.labourDiscountTotal,
    required this.labourTotal,
    required this.grandDiscountType,
    required this.grandDiscountValue,
    required this.grandDiscountAmount,
    required this.taxTotal,
    required this.grandTotal,
    required this.amountPaid,
    required this.balanceDue,
    required this.paymentStatus,
    this.paymentMethod,
    this.paymentDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.createdByName,
    this.teamId,
    this.teamName,
    this.notes,
    this.termsAndConditions,
  });

  // CopyWith method for creating modified copies
  BillModel copyWith({
    String? id,
    String? billNumber,
    String? quotationId,
    String? quotationNumber,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? customerAddress,
    List<QuotationItem>? materialItems,
    List<LabourItem>? labourItems,
    bool? isLabourProvidedByUs, // NEW FIELD
    DateTime? billDate,
    DateTime? dueDate,
    DateTime? paidDate,
    double? materialSubtotal,
    double? materialDiscountTotal,
    double? materialTaxTotal,
    double? materialTotal,
    double? labourSubtotal,
    double? labourDiscountTotal,
    double? labourTotal,
    DiscountType? grandDiscountType,
    double? grandDiscountValue,
    double? grandDiscountAmount,
    double? taxTotal,
    double? grandTotal,
    double? amountPaid,
    double? balanceDue,
    String? paymentStatus,
    String? paymentMethod,
    DateTime? paymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByName,
    String? teamId,
    String? teamName,
    String? notes,
    String? termsAndConditions,
  }) {
    return BillModel(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      quotationId: quotationId ?? this.quotationId,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      materialItems: materialItems ?? this.materialItems,
      labourItems: labourItems ?? this.labourItems,
      isLabourProvidedByUs: isLabourProvidedByUs ?? this.isLabourProvidedByUs, // NEW FIELD
      billDate: billDate ?? this.billDate,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      materialSubtotal: materialSubtotal ?? this.materialSubtotal,
      materialDiscountTotal: materialDiscountTotal ?? this.materialDiscountTotal,
      materialTaxTotal: materialTaxTotal ?? this.materialTaxTotal,
      materialTotal: materialTotal ?? this.materialTotal,
      labourSubtotal: labourSubtotal ?? this.labourSubtotal,
      labourDiscountTotal: labourDiscountTotal ?? this.labourDiscountTotal,
      labourTotal: labourTotal ?? this.labourTotal,
      grandDiscountType: grandDiscountType ?? this.grandDiscountType,
      grandDiscountValue: grandDiscountValue ?? this.grandDiscountValue,
      grandDiscountAmount: grandDiscountAmount ?? this.grandDiscountAmount,
      taxTotal: taxTotal ?? this.taxTotal,
      grandTotal: grandTotal ?? this.grandTotal,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceDue: balanceDue ?? this.balanceDue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billNumber': billNumber,
      'quotationId': quotationId,
      'quotationNumber': quotationNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'materialItems': materialItems.map((item) => item.toMap()).toList(),
      'labourItems': labourItems.map((item) => item.toMap()).toList(),
      'isLabourProvidedByUs': isLabourProvidedByUs, // NEW FIELD
      'billDate': billDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'materialSubtotal': materialSubtotal,
      'materialDiscountTotal': materialDiscountTotal,
      'materialTaxTotal': materialTaxTotal,
      'materialTotal': materialTotal,
      'labourSubtotal': labourSubtotal,
      'labourDiscountTotal': labourDiscountTotal,
      'labourTotal': labourTotal,
      'grandDiscountType': grandDiscountType.toString().split('.').last, // Better storage format
      'grandDiscountValue': grandDiscountValue,
      'grandDiscountAmount': grandDiscountAmount,
      'taxTotal': taxTotal,
      'grandTotal': grandTotal,
      'amountPaid': amountPaid,
      'balanceDue': balanceDue,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentDate': paymentDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'teamId': teamId,
      'teamName': teamName,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
    };
  }

  factory BillModel.fromMap(String id, Map<String, dynamic> map) {
    List<QuotationItem> materialItems = [];
    if (map['materialItems'] != null) {
      materialItems = (map['materialItems'] as List)
          .map((item) => QuotationItem.fromMap(item))
          .toList();
    }

    List<LabourItem> labourItems = [];
    if (map['labourItems'] != null) {
      labourItems = (map['labourItems'] as List)
          .map((item) => LabourItem.fromMap(item))
          .toList();
    }

    // Parse DiscountType with better handling
    DiscountType parseDiscountType(dynamic type) {
      if (type == null) return DiscountType.percentage;
      String typeStr = type.toString();
      if (typeStr.contains('percentage') || typeStr.toLowerCase() == 'percentage') {
        return DiscountType.percentage;
      }
      return DiscountType.amount;
    }

    return BillModel(
      id: id,
      billNumber: map['billNumber'] ?? '',
      quotationId: map['quotationId']?.toString(),
      quotationNumber: map['quotationNumber']?.toString(),
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerAddress: map['customerAddress']?.toString(),
      materialItems: materialItems,
      labourItems: labourItems,
      isLabourProvidedByUs: map['isLabourProvidedByUs'] ?? true, // NEW FIELD - default to true for backward compatibility
      billDate: map['billDate'] != null
          ? DateTime.parse(map['billDate'])
          : DateTime.now(),
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'])
          : DateTime.now().add(const Duration(days: 30)),
      paidDate: map['paidDate'] != null
          ? DateTime.parse(map['paidDate'])
          : null,
      materialSubtotal: (map['materialSubtotal'] ?? 0).toDouble(),
      materialDiscountTotal: (map['materialDiscountTotal'] ?? 0).toDouble(),
      materialTaxTotal: (map['materialTaxTotal'] ?? 0).toDouble(),
      materialTotal: (map['materialTotal'] ?? 0).toDouble(),
      labourSubtotal: (map['labourSubtotal'] ?? 0).toDouble(),
      labourDiscountTotal: (map['labourDiscountTotal'] ?? 0).toDouble(),
      labourTotal: (map['labourTotal'] ?? 0).toDouble(),
      grandDiscountType: parseDiscountType(map['grandDiscountType']),
      grandDiscountValue: (map['grandDiscountValue'] ?? 0).toDouble(),
      grandDiscountAmount: (map['grandDiscountAmount'] ?? 0).toDouble(),
      taxTotal: (map['taxTotal'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      balanceDue: (map['balanceDue'] ?? 0).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'Unpaid',
      paymentMethod: map['paymentMethod']?.toString(),
      paymentDate: map['paymentDate'] != null
          ? DateTime.parse(map['paymentDate'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      teamId: map['teamId']?.toString(),
      teamName: map['teamName']?.toString(),
      notes: map['notes']?.toString(),
      termsAndConditions: map['termsAndConditions']?.toString(),
    );
  }

  // Helper method to check if labour is billable (provided by us and has items)
  bool get hasBillableLabour => isLabourProvidedByUs && labourItems.isNotEmpty;

  // Helper method to get the effective labour total (0 if not provided by us)
  double get effectiveLabourTotal => isLabourProvidedByUs ? labourTotal : 0.0;

  // Helper method to get the payment status with proper formatting
  String getFormattedPaymentStatus() {
    if (paymentStatus == 'Paid') return 'Paid';
    if (paymentStatus == 'Partial') return 'Partially Paid';
    if (paymentStatus == 'Overdue') return 'Overdue';
    return 'Unpaid';
  }

  // Helper method to check if bill is overdue
  bool get isOverdue {
    return paymentStatus != 'Paid' &&
        paymentStatus != 'Overdue' &&
        dueDate.isBefore(DateTime.now());
  }

  // Helper method to get the amount due
  double get amountDue => grandTotal - amountPaid;

  // Helper method to get payment progress (0-1)
  double get paymentProgress {
    if (grandTotal <= 0) return 0.0;
    return (amountPaid / grandTotal).clamp(0.0, 1.0);
  }

  String _generateBillNumber() {
    DateTime now = DateTime.now();
    String year = now.year.toString();
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    String random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'INV-${year}${month}${day}-${random}';
  }
}