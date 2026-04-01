// BillPages/ReturnItemsScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/bill_model.dart';
import '../Models/return_model.dart';
import '../Models/quotation_model.dart';

class ReturnItemsScreen extends StatefulWidget {
  final BillModel bill;
  final String? teamId;
  final String? teamName;

  const ReturnItemsScreen({
    super.key,
    required this.bill,
    this.teamId,
    this.teamName,
  });

  @override
  State<ReturnItemsScreen> createState() => _ReturnItemsScreenState();
}

class _ReturnItemsScreenState extends State<ReturnItemsScreen> {
  final DatabaseReference _returnsRef =
  FirebaseDatabase.instance.ref().child('returns');
  final DatabaseReference _itemsRef =
  FirebaseDatabase.instance.ref().child('items');
  final DatabaseReference _billsRef =
  FirebaseDatabase.instance.ref().child('bills');

  Map<String, double> _returnQuantities = {};
  Map<String, String> _returnReasons = {};
  String _selectedReturnType = 'partial'; // 'full' or 'partial'
  String _globalReturnReason = '';
  bool _isProcessing = false;
  List<QuotationItem> _selectedItems = [];

  // Premium color palette
  static const Color _deepPurple = Color(0xFF6B4EFF);
  static const Color _electricIndigo = Color(0xFF4A3AFF);
  static const Color _royalBlue = Color(0xFF2563EB);
  static const Color _skyBlue = Color(0xFF38BDF8);
  static const Color _emeraldGreen = Color(0xFF10B981);
  static const Color _amberGlow = Color(0xFFF59E0B);
  static const Color _crimsonRed = Color(0xFFEF4444);
  static const Color _darkNavy = Color(0xFF0B1120);
  static const Color _slateGray = Color(0xFF1E293B);
  static const Color _charcoalBlue = Color(0xFF0F172A);
  static const Color _pearlWhite = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _initializeReturnQuantities();
  }

  void _initializeReturnQuantities() {
    for (var item in widget.bill.materialItems) {
      _returnQuantities[item.id] = 0.0;
      _returnReasons[item.id] = '';
    }
  }

  double _calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in widget.bill.materialItems) {
      double qty = _returnQuantities[item.id] ?? 0;
      if (qty > 0) {
        subtotal += qty * item.rate;
      }
    }
    return subtotal;
  }

  double _calculateTotalDiscount() {
    double totalDiscount = 0.0;
    for (var item in widget.bill.materialItems) {
      double qty = _returnQuantities[item.id] ?? 0;
      if (qty > 0) {
        // Calculate discount proportionally
        double itemSubtotal = item.quantity * item.rate;
        double discountPerUnit = item.discountAmount / item.quantity;
        totalDiscount += discountPerUnit * qty;
      }
    }
    return totalDiscount;
  }

  double _calculateGrandTotal() {
    double subtotal = _calculateSubtotal();
    double discount = _calculateTotalDiscount();
    return subtotal - discount;
  }

  Future<void> _processReturn() async {
    // Validate
    List<ReturnItem> returnItems = [];
    bool hasItems = false;

    for (var item in widget.bill.materialItems) {
      double qty = _returnQuantities[item.id] ?? 0;
      if (qty > 0) {
        hasItems = true;
        if (qty > item.quantity) {
          _showErrorSnackBar(
              'Return quantity cannot exceed original quantity for ${item.name}');
          return;
        }
        if (_returnReasons[item.id]?.isEmpty ?? true) {
          _showErrorSnackBar('Please provide reason for returning ${item.name}');
          return;
        }

        // Calculate proportional amounts
        double itemSubtotal = item.quantity * item.rate;
        double discountPerUnit = item.discountAmount / item.quantity;
        double taxPerUnit = item.taxAmount / item.quantity;

        returnItems.add(ReturnItem(
          id: item.id,
          itemName: item.name,
          description: item.description,
          quantity: item.quantity,
          rate: item.rate,
          discountValue: item.discountValue,
          discountType: item.discountType,
          discountAmount: discountPerUnit * qty,
          taxPercent: item.taxPercent,
          taxAmount: taxPerUnit * qty,
          total: qty * item.rate,
          returnedQuantity: qty,
          reason: _returnReasons[item.id]!,
        ));
      }
    }

    if (!hasItems) {
      _showErrorSnackBar('Please select at least one item to return');
      return;
    }

    if (_globalReturnReason.isEmpty && _selectedReturnType == 'full') {
      _showErrorSnackBar('Please provide a reason for the return');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String returnId = _returnsRef.push().key ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Create return record
      ReturnModel returnModel = ReturnModel(
        id: returnId,
        billId: widget.bill.id,
        billNumber: widget.bill.billNumber,
        customerId: widget.bill.customerId,
        customerName: widget.bill.customerName,
        returnDate: DateTime.now(),
        items: returnItems,
        subtotal: _calculateSubtotal(),
        totalDiscount: _calculateTotalDiscount(),
        grandTotal: _calculateGrandTotal(),
        returnReason:
        _selectedReturnType == 'full' ? _globalReturnReason : 'Partial return',
        returnType: _selectedReturnType,
        status: 'completed',
        processedBy: user?.uid,
        processedByName: user?.displayName ?? 'Unknown',
        teamId: widget.teamId,
        teamName: widget.teamName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _returnsRef.child(returnId).set(returnModel.toMap());

      // Update inventory (add back returned quantities)
      await _addBackToInventory(returnItems);

      // Update bill
      await _updateBillAfterReturn(returnItems);

      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackBar(
            'Return processed successfully! ${_calculateGrandTotal().toStringAsFixed(2)} refunded.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to process return: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _addBackToInventory(List<ReturnItem> returnItems) async {
    List<String> failedItems = [];

    for (final item in returnItems) {
      if (item.returnedQuantity <= 0) continue;

      final snapshot = await _itemsRef
          .orderByChild('itemName')
          .equalTo(item.itemName.trim())
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        failedItems.add(item.itemName);
        continue;
      }

      final matchedItems = Map<String, dynamic>.from(snapshot.value as Map);

      for (final entry in matchedItems.entries) {
        final itemRef = _itemsRef.child(entry.key);
        final currentData = Map<String, dynamic>.from(entry.value as Map);

        try {
          final double currentQty = (currentData['qtyOnHand'] ?? 0).toDouble();
          final double newQty = currentQty + item.returnedQuantity;

          await itemRef.update({
            'qtyOnHand': newQty,
            'lastUpdated': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('Error adding back stock for ${item.itemName}: $e');
          failedItems.add(item.itemName);
        }

        break;
      }
    }

    if (failedItems.isNotEmpty) {
      throw Exception('Failed to add back stock for: ${failedItems.join(", ")}');
    }
  }

  Future<void> _updateBillAfterReturn(List<ReturnItem> returnItems) async {
    final billRef = _billsRef.child(widget.bill.id);
    final currentBill = widget.bill;

    // Calculate new totals after return
    double totalReturnAmount = _calculateGrandTotal();

    // Update bill items (reduce quantities)
    List<QuotationItem> updatedItems = [];
    for (var originalItem in currentBill.materialItems) {
      var returnItem = returnItems.firstWhere(
            (r) => r.id == originalItem.id,
        orElse: () => ReturnItem(
          id: '',
          itemName: '',
          quantity: 0,
          rate: 0,
          discountValue: 0,
          discountType: DiscountType.percentage,
          discountAmount: 0,
          taxPercent: 0,
          taxAmount: 0,
          total: 0,
          returnedQuantity: 0,
          reason: '',
        ),
      );

      if (returnItem.returnedQuantity > 0) {
        double newQuantity = originalItem.quantity - returnItem.returnedQuantity;

        if (newQuantity > 0) {
          // Recalculate item totals
          double newSubtotal = newQuantity * originalItem.rate;
          double newDiscountAmount = 0;

          if (originalItem.discountType == DiscountType.percentage) {
            newDiscountAmount = newSubtotal * (originalItem.discountValue / 100);
          } else {
            newDiscountAmount = originalItem.discountValue > newSubtotal
                ? newSubtotal
                : originalItem.discountValue;
          }

          double afterDiscount = newSubtotal - newDiscountAmount;
          double newTaxAmount = afterDiscount * (originalItem.taxPercent / 100);
          double newTotal = afterDiscount + newTaxAmount;

          updatedItems.add(originalItem.copyWith(
            quantity: newQuantity,
            discountAmount: newDiscountAmount,
            taxAmount: newTaxAmount,
            total: newTotal,
          ));
        }
        // If quantity becomes 0, don't add the item
      } else {
        updatedItems.add(originalItem);
      }
    }

    // Recalculate bill totals
    double newMaterialSubtotal = 0;
    double newMaterialDiscountTotal = 0;
    double newMaterialTaxTotal = 0;
    double newMaterialTotal = 0;

    for (var item in updatedItems) {
      double itemSubtotal = item.quantity * item.rate;
      newMaterialSubtotal += itemSubtotal;
      newMaterialDiscountTotal += item.discountAmount;
      newMaterialTaxTotal += item.taxAmount;
    }
    newMaterialTotal = newMaterialSubtotal - newMaterialDiscountTotal + newMaterialTaxTotal;

    double newGrandTotal = newMaterialTotal + currentBill.labourTotal;

    // Recalculate grand discount if applicable
    if (currentBill.grandDiscountAmount > 0) {
      double beforeGrandDiscount = newMaterialTotal + currentBill.labourTotal;
      if (currentBill.grandDiscountType == DiscountType.percentage) {
        newGrandTotal = beforeGrandDiscount * (1 - currentBill.grandDiscountValue / 100);
      } else {
        newGrandTotal = beforeGrandDiscount - currentBill.grandDiscountValue;
        if (newGrandTotal < 0) newGrandTotal = 0;
      }
    }

    double newAmountPaid = currentBill.amountPaid;
    if (newAmountPaid > newGrandTotal) {
      newAmountPaid = newGrandTotal;
    }

    double newBalanceDue = newGrandTotal - newAmountPaid;
    String newPaymentStatus = newBalanceDue <= 0 ? 'Paid' :
    (newAmountPaid > 0 ? 'Partial' : 'Unpaid');

    // Update bill
    await billRef.update({
      'materialItems': updatedItems.map((e) => e.toMap()).toList(),
      'materialSubtotal': newMaterialSubtotal,
      'materialDiscountTotal': newMaterialDiscountTotal,
      'materialTaxTotal': newMaterialTaxTotal,
      'materialTotal': newMaterialTotal,
      'grandTotal': newGrandTotal,
      'amountPaid': newAmountPaid,
      'balanceDue': newBalanceDue,
      'paymentStatus': newPaymentStatus,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Widget _buildReturnItemCard(QuotationItem item, int index) {
    double qty = _returnQuantities[item.id] ?? 0;
    String reason = _returnReasons[item.id] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _slateGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0 ? _crimsonRed.withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.description != null)
                      Text(
                        item.description!,
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Original: ${item.quantity} x \$${item.rate}',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _pearlWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${item.discountAmount > 0 ? 'Disc: \$${item.discountAmount.toStringAsFixed(2)}' : ''}',
                    style: TextStyle(
                      color: _crimsonRed.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _charcoalBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _crimsonRed.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: qty > 0
                            ? () {
                          setState(() {
                            _returnQuantities[item.id] = qty - 0.5;
                            if (qty - 0.5 <= 0) {
                              _returnQuantities[item.id] = 0;
                            }
                          });
                        }
                            : null,
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        color: _crimsonRed,
                      ),
                      Expanded(
                        child: Text(
                          qty.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: qty < item.quantity
                            ? () {
                          setState(() {
                            _returnQuantities[item.id] = qty + 0.5;
                          });
                        }
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        color: _emeraldGreen,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: reason,
                  style: const TextStyle(color: _pearlWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Reason for return',
                    hintStyle: TextStyle(
                      color: _pearlWhite.withOpacity(0.3),
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _crimsonRed.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _crimsonRed.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _crimsonRed),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _returnReasons[item.id] = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = _calculateSubtotal();
    double discount = _calculateTotalDiscount();
    double grandTotal = _calculateGrandTotal();
    bool hasSelectedItems = subtotal > 0;

    return Scaffold(
      backgroundColor: _darkNavy,
      appBar: AppBar(
        backgroundColor: _charcoalBlue,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: _pearlWhite,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Return Items',
          style: TextStyle(
            color: _pearlWhite,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isProcessing
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _charcoalBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bill Number:',
                        style: TextStyle(
                          color: _pearlWhite,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.bill.billNumber,
                        style: const TextStyle(
                          color: _emeraldGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Customer:',
                        style: TextStyle(
                          color: _pearlWhite,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.bill.customerName,
                        style: const TextStyle(
                          color: _pearlWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Return Type Selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _charcoalBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Return Type',
                    style: TextStyle(
                      color: _pearlWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedReturnType = 'partial';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedReturnType == 'partial'
                                  ? _crimsonRed.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedReturnType == 'partial'
                                    ? _crimsonRed
                                    : Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.party_mode,
                                  color: _selectedReturnType == 'partial'
                                      ? _crimsonRed
                                      : _pearlWhite.withOpacity(0.5),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Partial Return',
                                  style: TextStyle(
                                    color: _selectedReturnType == 'partial'
                                        ? _crimsonRed
                                        : _pearlWhite.withOpacity(0.7),
                                    fontWeight: _selectedReturnType ==
                                        'partial'
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedReturnType = 'full';
                              // Select all items for full return
                              for (var item in widget.bill.materialItems) {
                                _returnQuantities[item.id] = item.quantity;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedReturnType == 'full'
                                  ? _crimsonRed.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedReturnType == 'full'
                                    ? _crimsonRed
                                    : Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fullscreen,
                                  color: _selectedReturnType == 'full'
                                      ? _crimsonRed
                                      : _pearlWhite.withOpacity(0.5),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Full Return',
                                  style: TextStyle(
                                    color: _selectedReturnType == 'full'
                                        ? _crimsonRed
                                        : _pearlWhite.withOpacity(0.7),
                                    fontWeight: _selectedReturnType ==
                                        'full'
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedReturnType == 'full')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        maxLines: 2,
                        style: const TextStyle(color: _pearlWhite),
                        decoration: InputDecoration(
                          hintText: 'Global return reason',
                          hintStyle: TextStyle(
                            color: _pearlWhite.withOpacity(0.3),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _crimsonRed.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _crimsonRed.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _crimsonRed),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _globalReturnReason = value;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Items to Return
            const Text(
              'Items to Return',
              style: TextStyle(
                color: _pearlWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.bill.materialItems.length,
              itemBuilder: (context, index) {
                return _buildReturnItemCard(
                    widget.bill.materialItems[index], index);
              },
            ),

            const SizedBox(height: 20),

            // Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _charcoalBlue,
                    _charcoalBlue.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _crimsonRed.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
                  if (discount > 0)
                    _buildSummaryRow(
                        'Discount', '-\$${discount.toStringAsFixed(2)}',
                        color: _crimsonRed),
                  const Divider(color: Colors.white24, height: 24),
                  _buildSummaryRow(
                    'Refund Amount',
                    '\$${grandTotal.toStringAsFixed(2)}',
                    isBold: true,
                    color: _crimsonRed,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Process Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: hasSelectedItems && !_isProcessing
                    ? _processReturn
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _crimsonRed,
                  foregroundColor: _pearlWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _pearlWhite,
                  ),
                )
                    : const Text(
                  'Process Return',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.7),
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? _pearlWhite,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _emeraldGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _crimsonRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}