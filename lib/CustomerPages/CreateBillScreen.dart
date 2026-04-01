// BillPages/CreateBillScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/quotation_model.dart';
import '../Models/bill_model.dart';
import '../Models/labour_model.dart';

class CreateBillScreen extends StatefulWidget {
  final QuotationModel? quotation; // Optional - create bill from quotation
  final String? teamId;
  final String? teamName;

  const CreateBillScreen({
    super.key,
    this.quotation,
    this.teamId,
    this.teamName,
  });

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _billsRef =
  FirebaseDatabase.instance.ref().child('bills');
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _itemsRef =
  FirebaseDatabase.instance.ref().child('items');

  // Material Items (from quotation or new)
  List<QuotationItem> _materialItems = [];

  // Labour Items
  List<LabourItem> _labourItems = [];

  // Flag to indicate if labour is provided by us
  bool _isLabourProvidedByUs = true;

  DateTime _billDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  // Grand discount on overall bill
  DiscountType _grandDiscountType = DiscountType.percentage;
  double _grandDiscountValue = 0.0;
  double _grandDiscountAmount = 0.0;

  // Payment
  double _amountPaid = 0.0;
  String _paymentStatus = 'Unpaid';
  String _selectedPaymentMethod = 'Cash';
  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'Bank Transfer',
    'Cheque',
    'Online'
  ];

  TextEditingController _notesController = TextEditingController();
  TextEditingController _termsController = TextEditingController();
  TextEditingController _amountPaidController = TextEditingController();

  Map<String, dynamic> _currentUser = {};
  bool _isLoading = false;
  bool _isSaving = false;

  // Calculations
  double _materialSubtotal = 0.0;
  double _materialDiscountTotal = 0.0;
  double _materialTaxTotal = 0.0;
  double _materialTotal = 0.0;

  double _labourSubtotal = 0.0;
  double _labourDiscountTotal = 0.0;
  double _labourTotal = 0.0;

  double _taxTotal = 0.0;
  double _grandTotal = 0.0;
  double _balanceDue = 0.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
  static const Color _steelGray = Color(0xFF334155);
  static const Color _pearlWhite = Color(0xFFF8FAFC);

  final List<String> _paymentStatusOptions = [
    'Unpaid',
    'Partial',
    'Paid',
    'Overdue',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    _loadCurrentUser();
    _initializeFromQuotation();
    _addLabourItem(); // Add one empty labour item to start
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseEvent userEvent = await _usersRef.child(user.uid).once();
      if (userEvent.snapshot.value != null) {
        setState(() {
          _currentUser =
          Map<String, dynamic>.from(userEvent.snapshot.value as Map);
        });
      }
    }
  }

  void _initializeFromQuotation() {
    if (widget.quotation != null) {
      setState(() {
        // Copy material items from quotation
        _materialItems =
            widget.quotation!.items.map((item) => item.copyWith()).toList();

        // Copy customer details and other info
        _notesController.text = widget.quotation!.notes ?? '';
        _termsController.text = widget.quotation!.termsAndConditions ?? '';
      });
      _calculateTotals();
    }
  }

  void _addMaterialItem() {
    setState(() {
      _materialItems.add(QuotationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        quantity: 1.0,
        rate: 0.0,
        discountType: DiscountType.percentage,
        discountValue: 0.0,
        discountAmount: 0.0,
        taxPercent: 0.0,
        taxAmount: 0.0,
        total: 0.0,
      ));
    });
  }

  void _removeMaterialItem(int index) {
    setState(() {
      _materialItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateMaterialItem(
      int index, {
        String? name,
        String? description,
        double? quantity,
        double? rate,
        DiscountType? discountType,
        double? discountValue,
        double? taxPercent,
      }) {
    setState(() {
      var item = _materialItems[index];

      if (name != null) item = item.copyWith(name: name);
      if (description != null) item = item.copyWith(description: description);
      if (quantity != null) item = item.copyWith(quantity: quantity);
      if (rate != null) item = item.copyWith(rate: rate);
      if (discountType != null) item = item.copyWith(discountType: discountType);
      if (discountValue != null) item = item.copyWith(discountValue: discountValue);
      if (taxPercent != null) item = item.copyWith(taxPercent: taxPercent);

      // Calculate item totals
      double subtotal = item.quantity * item.rate;

      if (item.discountType == DiscountType.percentage) {
        item.discountAmount = subtotal * (item.discountValue / 100);
      } else {
        item.discountAmount =
        item.discountValue > subtotal ? subtotal : item.discountValue;
      }

      double afterDiscount = subtotal - item.discountAmount;
      item.taxAmount = afterDiscount * (item.taxPercent / 100);
      item.total = afterDiscount + item.taxAmount;

      _materialItems[index] = item;
      _calculateTotals();
    });
  }

  // Labour Item Methods
  void _addLabourItem() {
    setState(() {
      _labourItems.add(LabourItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        hours: 1.0,
        rate: 0.0,
        discountType: DiscountType.percentage,
        discountValue: 0.0,
        discountAmount: 0.0,
        total: 0.0,
      ));
    });
  }

  void _removeLabourItem(int index) {
    setState(() {
      _labourItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateLabourItem(
      int index, {
        String? name,
        String? description,
        double? hours,
        double? rate,
        DiscountType? discountType,
        double? discountValue,
      }) {
    setState(() {
      var item = _labourItems[index];

      if (name != null) item = item.copyWith(name: name);
      if (description != null) item = item.copyWith(description: description);
      if (hours != null) item = item.copyWith(hours: hours);
      if (rate != null) item = item.copyWith(rate: rate);
      if (discountType != null) item = item.copyWith(discountType: discountType);
      if (discountValue != null) item = item.copyWith(discountValue: discountValue);

      // Calculate labour totals
      double subtotal = item.hours * item.rate;

      if (item.discountType == DiscountType.percentage) {
        item.discountAmount = subtotal * (item.discountValue / 100);
      } else {
        item.discountAmount =
        item.discountValue > subtotal ? subtotal : item.discountValue;
      }

      item.total = subtotal - item.discountAmount;

      _labourItems[index] = item;
      _calculateTotals();
    });
  }

  void _updateGrandDiscount({
    required DiscountType type,
    required double value,
  }) {
    setState(() {
      _grandDiscountType = type;
      _grandDiscountValue = value;
      _calculateTotals();
    });
  }

  void _updateAmountPaid(String value) {
    double? amount = double.tryParse(value);
    if (amount != null && amount >= 0) {
      setState(() {
        _amountPaid = amount;
        _balanceDue = _grandTotal - _amountPaid;

        // Update payment status based on amount paid
        if (_amountPaid <= 0) {
          _paymentStatus = 'Unpaid';
        } else if (_amountPaid >= _grandTotal) {
          _paymentStatus = 'Paid';
        } else {
          _paymentStatus = 'Partial';
        }
      });
    }
  }

  void _calculateTotals() {
    // Calculate Material Totals
    _materialSubtotal = 0.0;
    _materialDiscountTotal = 0.0;
    _materialTaxTotal = 0.0;

    for (var item in _materialItems) {
      double itemSubtotal = item.quantity * item.rate;
      _materialSubtotal += itemSubtotal;
      _materialDiscountTotal += item.discountAmount;
      _materialTaxTotal += item.taxAmount;
    }
    _materialTotal =
        _materialSubtotal - _materialDiscountTotal + _materialTaxTotal;

    // Calculate Labour Totals only if labour is provided by us
    _labourSubtotal = 0.0;
    _labourDiscountTotal = 0.0;
    _labourTotal = 0.0;

    if (_isLabourProvidedByUs) {
      for (var item in _labourItems) {
        double itemSubtotal = item.hours * item.rate;
        _labourSubtotal += itemSubtotal;
        _labourDiscountTotal += item.discountAmount;
      }
      _labourTotal = _labourSubtotal - _labourDiscountTotal;
    }

    // Combined total before grand discount
    double beforeGrandDiscount = _materialTotal + _labourTotal;
    _taxTotal = _materialTaxTotal; // Labour typically doesn't have tax

    // Calculate grand discount
    if (_grandDiscountType == DiscountType.percentage) {
      _grandDiscountAmount =
          beforeGrandDiscount * (_grandDiscountValue / 100);
    } else {
      _grandDiscountAmount = _grandDiscountValue > beforeGrandDiscount
          ? beforeGrandDiscount
          : _grandDiscountValue;
    }

    _grandTotal = beforeGrandDiscount - _grandDiscountAmount;
    _balanceDue = _grandTotal - _amountPaid;

    setState(() {});
  }

  String _generateBillNumber() {
    DateTime now = DateTime.now();
    String year = now.year.toString();
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    String random =
    (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'INV-${year}${month}${day}-${random}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _deductItemQuantities(List<QuotationItem> items) async {
    List<String> failedItems = [];

    for (final item in items) {
      if (item.name.trim().isEmpty || item.quantity <= 0) continue;

      final snapshot = await _itemsRef
          .orderByChild('itemName')
          .equalTo(item.name.trim())
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        failedItems.add(item.name);
        continue;
      }

      final matchedItems = Map<String, dynamic>.from(snapshot.value as Map);

      for (final entry in matchedItems.entries) {
        final itemRef = _itemsRef.child(entry.key);
        final currentData = Map<String, dynamic>.from(entry.value as Map);

        try {
          // Get current quantity
          final double currentQty = (currentData['qtyOnHand'] ?? 0).toDouble();
          final double newQty = (currentQty - item.quantity).clamp(0.0, double.infinity);

          // Create update map with only the fields that need to be updated
          // and ensure all required fields are present
          final Map<String, dynamic> updateMap = {
            'qtyOnHand': newQty,
            'lastUpdated': DateTime.now().toIso8601String(),
          };

          // Ensure all required fields exist in the current data
          // Add any missing required fields if they don't exist
          if (!currentData.containsKey('itemName')) {
            updateMap['itemName'] = item.name.trim();
          }
          if (!currentData.containsKey('salePrice')) {
            updateMap['salePrice'] = currentData['salePrice'] ?? 0.0;
          }
          if (!currentData.containsKey('qtyOnHand')) {
            updateMap['qtyOnHand'] = newQty;
          }

          // Use update instead of transaction to avoid complex validation issues
          await itemRef.update(updateMap);

          // Verify the update was successful
          final verifySnapshot = await itemRef.get();
          if (verifySnapshot.exists) {
            final updatedData = verifySnapshot.value as Map;
            final double updatedQty = (updatedData['qtyOnHand'] ?? 0).toDouble();

            if (updatedQty > newQty + 0.01) { // Allow small floating point differences
              failedItems.add('${item.name} (Update verification failed)');
            }
          } else {
            failedItems.add('${item.name} (Item not found after update)');
          }
        } catch (e) {
          print('Error deducting stock for ${item.name}: $e');
          failedItems.add('${item.name} (Error: $e)');
        }

        break;
      }
    }

    if (failedItems.isNotEmpty) {
      throw Exception('Failed to deduct stock for: ${failedItems.join(", ")}');
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveBill() async {
    // Validate items
    if (_materialItems.isEmpty && _labourItems.isEmpty) {
      _showErrorSnackBar('Please add at least one item (material or labour)');
      return;
    }

    for (var item in _materialItems) {
      if (item.name.isEmpty) {
        _showErrorSnackBar('Please enter material item names');
        return;
      }
      if (item.quantity <= 0) {
        _showErrorSnackBar('Quantity must be greater than 0');
        return;
      }
      if (item.rate <= 0) {
        _showErrorSnackBar('Rate must be greater than 0');
        return;
      }
    }

    // ✅ NEW: Check stock availability before proceeding
    if (!await _checkStockAvailability(_materialItems)) {
      return;
    }

    // Only validate labour items if labour is provided by us
    if (_isLabourProvidedByUs) {
      for (var item in _labourItems) {
        if (item.name.isEmpty) {
          _showErrorSnackBar('Please enter labour item names');
          return;
        }
        if (item.hours <= 0) {
          _showErrorSnackBar('Hours must be greater than 0');
          return;
        }
        if (item.rate <= 0) {
          _showErrorSnackBar('Rate must be greater than 0');
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String billId = _billsRef.push().key ??
          DateTime.now().millisecondsSinceEpoch.toString();

      BillModel bill = BillModel(
        id: billId,
        billNumber: _generateBillNumber(),
        quotationId: widget.quotation?.id,
        quotationNumber: widget.quotation?.quotationNumber,
        customerId: widget.quotation?.customerId ?? '',
        customerName: widget.quotation?.customerName ?? '',
        customerEmail: widget.quotation?.customerEmail ?? '',
        customerPhone: widget.quotation?.customerPhone ?? '',
        customerAddress: widget.quotation?.customerAddress,
        materialItems: List.from(_materialItems),
        labourItems: _isLabourProvidedByUs
            ? List.from(_labourItems)
            : [],
        billDate: _billDate,
        dueDate: _dueDate,
        paidDate: _paymentStatus == 'Paid' ? DateTime.now() : null,
        materialSubtotal: _materialSubtotal,
        materialDiscountTotal: _materialDiscountTotal,
        materialTaxTotal: _materialTaxTotal,
        materialTotal: _materialTotal,
        labourSubtotal: _labourSubtotal,
        labourDiscountTotal: _labourDiscountTotal,
        labourTotal: _labourTotal,
        grandDiscountType: _grandDiscountType,
        grandDiscountValue: _grandDiscountValue,
        grandDiscountAmount: _grandDiscountAmount,
        taxTotal: _taxTotal,
        grandTotal: _grandTotal,
        amountPaid: _amountPaid,
        balanceDue: _balanceDue,
        paymentStatus: _paymentStatus,
        paymentMethod: _amountPaid > 0 ? _selectedPaymentMethod : null,
        paymentDate: _amountPaid > 0 ? DateTime.now() : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user?.uid ?? '',
        createdByName: _currentUser['name'] ?? 'Unknown',
        teamId: widget.teamId,
        teamName: widget.teamName,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        termsAndConditions: _termsController.text.trim().isNotEmpty
            ? _termsController.text.trim()
            : null,
        isLabourProvidedByUs: _isLabourProvidedByUs,
      );

      // 1. Save the bill
      await _billsRef.child(billId).set(bill.toMap());

      // 2. Deduct qtyOnHand for each material item from inventory
      await _deductItemQuantities(_materialItems);

      // 3. If created from quotation, update quotation status to 'Billed'
      if (widget.quotation != null) {
        final DatabaseReference quotationsRef =
        FirebaseDatabase.instance.ref().child('quotations');
        await quotationsRef.child(widget.quotation!.id).update({
          'status': 'Billed',
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackBar('✅ Bill created successfully!');
      }
    } catch (e) {
      if (mounted) {
        print('Error creating bill: $e');
        _showErrorSnackBar('Failed to create bill: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Add this method to check stock before creating bill
  Future<bool> _checkStockAvailability(List<QuotationItem> items) async {
    List<String> insufficientStockItems = [];

    for (final item in items) {
      if (item.name.trim().isEmpty || item.quantity <= 0) continue;

      final snapshot = await _itemsRef
          .orderByChild('itemName')
          .equalTo(item.name.trim())
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        // Item not found in inventory
        insufficientStockItems.add('${item.name} (Item not found in inventory)');
        continue;
      }

      final matchedItems = Map<String, dynamic>.from(snapshot.value as Map);

      for (final entry in matchedItems.entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final double currentQty = (data['qtyOnHand'] ?? 0).toDouble();

        if (currentQty < item.quantity) {
          insufficientStockItems.add(
              '${item.name} (Available: $currentQty, Required: ${item.quantity})'
          );
        }
        break; // Only check the first match (assuming item names are unique)
      }
    }

    if (insufficientStockItems.isNotEmpty) {
      final message = 'Insufficient stock for:\n${insufficientStockItems.join('\n')}';
      _showErrorSnackBar(message);
      return false;
    }

    return true;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _pearlWhite.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _emeraldGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _pearlWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _emeraldGreen.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _pearlWhite.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: _crimsonRed,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _pearlWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _crimsonRed.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_emeraldGreen, _deepPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_rounded,
                color: _pearlWhite,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Bill',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.quotation != null)
                  Text(
                    'From: ${widget.quotation!.quotationNumber}',
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _paymentStatus == 'Paid'
                  ? _emeraldGreen.withOpacity(0.2)
                  : _paymentStatus == 'Partial'
                  ? _amberGlow.withOpacity(0.2)
                  : _crimsonRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _paymentStatus == 'Paid'
                        ? _emeraldGreen
                        : _paymentStatus == 'Partial'
                        ? _amberGlow
                        : _crimsonRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _paymentStatus,
                  style: TextStyle(
                    color: _paymentStatus == 'Paid'
                        ? _emeraldGreen
                        : _paymentStatus == 'Partial'
                        ? _amberGlow
                        : _crimsonRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: _pearlWhite,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info Card
                if (widget.quotation != null)
                  _buildCustomerInfoCard(),

                const SizedBox(height: 20),

                // Bill Details
                _buildBillDetailsCard(),

                const SizedBox(height: 20),

                // Material Items Section
                _buildMaterialItemsSection(),

                const SizedBox(height: 20),

                // Labour Option Checkbox
                _buildLabourOptionCard(),

                const SizedBox(height: 20),

                // Labour Items Section (only shown if labour is provided by us)
                if (_isLabourProvidedByUs) ...[
                  _buildLabourItemsSection(),
                  const SizedBox(height: 24),
                ],

                // Summary Card
                _buildSummaryCard(),

                const SizedBox(height: 20),

                // Payment Section
                _buildPaymentSection(),

                const SizedBox(height: 20),

                // Notes & Terms
                _buildNotesCard(),

                const SizedBox(height: 32),

                // Save Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_deepPurple, _electricIndigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _deepPurple.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(
                            _pearlWhite),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.save_rounded),
                        SizedBox(width: 12),
                        Text(
                          'Create Bill',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _pearlWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Container(
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
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _skyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _skyBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Customer Information',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_skyBlue, _royalBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    widget.quotation!.customerName[0].toUpperCase(),
                    style: const TextStyle(
                      color: _pearlWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.quotation!.customerName,
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.quotation!.customerEmail ??
                          'No email provided',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    if (widget.quotation!.customerPhone != null &&
                        widget.quotation!.customerPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.quotation!.customerPhone!,
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetailsCard() {
    return Container(
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
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _amberGlow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: _amberGlow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Bill Details',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Date',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: _amberGlow.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_billDate.day}/${_billDate.month}/${_billDate.year}',
                            style: const TextStyle(
                              color: _pearlWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _billDate,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: _amberGlow,
                                        onPrimary: _pearlWhite,
                                        surface: _charcoalBlue,
                                        onSurface: _pearlWhite,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _billDate = picked;
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _amberGlow,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due Date',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: _crimsonRed.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                            style: const TextStyle(
                              color: _pearlWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: _crimsonRed,
                                        onPrimary: _pearlWhite,
                                        surface: _charcoalBlue,
                                        onSurface: _pearlWhite,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _dueDate = picked;
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _crimsonRed,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_rounded,
                    color: _deepPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Materials',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _addMaterialItem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Material'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _pearlWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_materialItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _charcoalBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_outlined,
                  size: 48,
                  color: _pearlWhite.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Material Items',
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add materials from quotation or create new ones',
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
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
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _slateGray.withOpacity(0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Item',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600))),
                      Expanded(
                          flex: 1,
                          child: Text('Qty',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child: Text('Rate',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('Disc',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('Disc Type',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child: Text('Tax %',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('Total',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                // Items List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _materialItems.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.white24,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    var item = _materialItems[index];
                    return _buildMaterialItemRow(index, item);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMaterialItemRow(int index, QuotationItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Name & Description
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: item.name,
                  style: const TextStyle(color: _pearlWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Item name',
                    hintStyle: TextStyle(
                      color: _pearlWhite.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (value) {
                    _updateMaterialItem(index, name: value);
                  },
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: item.description,
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: TextStyle(
                      color: _pearlWhite.withOpacity(0.2),
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    _updateMaterialItem(index, description: value);
                  },
                ),
              ],
            ),
          ),
          // Quantity with increment/decrement buttons
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _deepPurple.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      double newQty = item.quantity - 1;
                      if (newQty >= 0.01) {
                        _updateMaterialItem(index, quantity: newQty);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.remove_rounded,
                        size: 16,
                        color: item.quantity > 0.01
                            ? _pearlWhite
                            : _pearlWhite.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.quantity.toString(),
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                        EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (value) {
                        double? qty = double.tryParse(value);
                        if (qty != null && qty > 0) {
                          _updateMaterialItem(index, quantity: qty);
                        } else if (value.isEmpty) {
                          _updateMaterialItem(index, quantity: 1);
                        }
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      double newQty = item.quantity + 1;
                      _updateMaterialItem(index, quantity: newQty);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: _pearlWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Rate
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.rate.toStringAsFixed(2),
              style: const TextStyle(color: _pearlWhite, fontSize: 14),
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: ' ',
                prefixStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? rate = double.tryParse(value);
                if (rate != null && rate > 0) {
                  _updateMaterialItem(index, rate: rate);
                }
              },
            ),
          ),
          // Discount Value
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.discountValue.toStringAsFixed(
                  item.discountType == DiscountType.percentage ? 1 : 2),
              style: const TextStyle(color: _pearlWhite, fontSize: 14),
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: item.discountType == DiscountType.percentage
                    ? '%'
                    : '',
                suffixStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? discount = double.tryParse(value);
                if (discount != null && discount >= 0) {
                  _updateMaterialItem(index, discountValue: discount);
                }
              },
            ),
          ),
          // Discount Type Radio Buttons
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _updateMaterialItem(index,
                        discountType: DiscountType.percentage),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.discountType == DiscountType.percentage
                            ? _amberGlow.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                          item.discountType == DiscountType.percentage
                              ? _amberGlow
                              : Colors.white.withOpacity(0.1),
                          width:
                          item.discountType == DiscountType.percentage
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: item.discountType ==
                                    DiscountType.percentage
                                    ? _amberGlow
                                    : _pearlWhite.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: item.discountType ==
                                DiscountType.percentage
                                ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _amberGlow,
                                ),
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.percent_rounded,
                            size: 14,
                            color: _amberGlow,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _updateMaterialItem(index,
                        discountType: DiscountType.amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.discountType == DiscountType.amount
                            ? _emeraldGreen.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.discountType == DiscountType.amount
                              ? _emeraldGreen
                              : Colors.white.withOpacity(0.1),
                          width: item.discountType == DiscountType.amount
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                item.discountType == DiscountType.amount
                                    ? _emeraldGreen
                                    : _pearlWhite.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: item.discountType == DiscountType.amount
                                ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _emeraldGreen,
                                ),
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.attach_money_rounded,
                            size: 14,
                            color: _emeraldGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tax %
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.taxPercent.toStringAsFixed(1),
              style: const TextStyle(color: _pearlWhite, fontSize: 14),
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: '%',
                suffixStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? tax = double.tryParse(value);
                if (tax != null && tax >= 0) {
                  _updateMaterialItem(index, taxPercent: tax);
                }
              },
            ),
          ),
          // Total
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                item.total.toStringAsFixed(2),
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Delete Button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _crimsonRed.withOpacity(0.7),
                size: 20,
              ),
              onPressed: () => _removeMaterialItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourOptionCard() {
    return Container(
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
          color: _amberGlow.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _amberGlow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  color: _amberGlow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Labour Options',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _slateGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isLabourProvidedByUs
                    ? _amberGlow.withOpacity(0.3)
                    : _skyBlue.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isLabourProvidedByUs = !_isLabourProvidedByUs;
                      _calculateTotals();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _isLabourProvidedByUs
                                ? _amberGlow
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isLabourProvidedByUs
                                  ? _amberGlow
                                  : _pearlWhite.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: _isLabourProvidedByUs
                              ? const Icon(
                            Icons.check_rounded,
                            color: _pearlWhite,
                            size: 18,
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Labour provided by us',
                                style: TextStyle(
                                  color: _pearlWhite,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Our team will provide labour services',
                                style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLabourProvidedByUs)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _amberGlow.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _amberGlow.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: _amberGlow,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isLabourProvidedByUs = false;
                      _calculateTotals();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: !_isLabourProvidedByUs
                                ? _skyBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: !_isLabourProvidedByUs
                                  ? _skyBlue
                                  : _pearlWhite.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: !_isLabourProvidedByUs
                              ? const Icon(
                            Icons.check_rounded,
                            color: _pearlWhite,
                            size: 18,
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer provides labour',
                                style: TextStyle(
                                  color: _pearlWhite,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Customer will arrange their own labour',
                                style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isLabourProvidedByUs)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _skyBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _skyBlue.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'Selected',
                              style: TextStyle(
                                color: _skyBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _amberGlow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.engineering_rounded,
                    color: _amberGlow,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Labour Services',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_amberGlow, _deepPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _addLabourItem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Labour'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _pearlWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_labourItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _charcoalBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.engineering_outlined,
                  size: 48,
                  color: _pearlWhite.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Labour Items',
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add labour services with hourly rates and discounts',
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
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
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _slateGray.withOpacity(0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Labour',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600))),
                      Expanded(
                          flex: 1,
                          child: Text('Hours',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child: Text('Rate/hr',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('Disc',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('Disc Type',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child: Text('Total',
                              style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.8),
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _labourItems.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.white24,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    var item = _labourItems[index];
                    return _buildLabourItemRow(index, item);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLabourItemRow(int index, LabourItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: item.name,
                  style: const TextStyle(color: _pearlWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Labour type',
                    hintStyle: TextStyle(
                      color: _pearlWhite.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (value) {
                    _updateLabourItem(index, name: value);
                  },
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: item.description,
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: TextStyle(
                      color: _pearlWhite.withOpacity(0.2),
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    _updateLabourItem(index, description: value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _amberGlow.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      double newHours = item.hours - 0.5;
                      if (newHours >= 0.5) {
                        _updateLabourItem(index, hours: newHours);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _amberGlow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.remove_rounded,
                        size: 16,
                        color: item.hours > 0.5
                            ? _pearlWhite
                            : _pearlWhite.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.hours.toString(),
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                        EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (value) {
                        double? hours = double.tryParse(value);
                        if (hours != null && hours > 0) {
                          _updateLabourItem(index, hours: hours);
                        } else if (value.isEmpty) {
                          _updateLabourItem(index, hours: 1);
                        }
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      double newHours = item.hours + 0.5;
                      _updateLabourItem(index, hours: newHours);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _amberGlow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: _pearlWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.rate.toStringAsFixed(2),
              style: const TextStyle(color: _pearlWhite, fontSize: 14),
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: ' ',
                prefixStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? rate = double.tryParse(value);
                if (rate != null && rate > 0) {
                  _updateLabourItem(index, rate: rate);
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.discountValue.toStringAsFixed(
                  item.discountType == DiscountType.percentage ? 1 : 2),
              style: const TextStyle(color: _pearlWhite, fontSize: 14),
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: item.discountType == DiscountType.percentage
                    ? '%'
                    : '',
                suffixStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? discount = double.tryParse(value);
                if (discount != null && discount >= 0) {
                  _updateLabourItem(index, discountValue: discount);
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _updateLabourItem(index,
                        discountType: DiscountType.percentage),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.discountType == DiscountType.percentage
                            ? _amberGlow.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                          item.discountType == DiscountType.percentage
                              ? _amberGlow
                              : Colors.white.withOpacity(0.1),
                          width:
                          item.discountType == DiscountType.percentage
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: item.discountType ==
                                    DiscountType.percentage
                                    ? _amberGlow
                                    : _pearlWhite.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: item.discountType ==
                                DiscountType.percentage
                                ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _amberGlow,
                                ),
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.percent_rounded,
                              size: 14, color: _amberGlow),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _updateLabourItem(index,
                        discountType: DiscountType.amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.discountType == DiscountType.amount
                            ? _emeraldGreen.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.discountType == DiscountType.amount
                              ? _emeraldGreen
                              : Colors.white.withOpacity(0.1),
                          width: item.discountType == DiscountType.amount
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                item.discountType == DiscountType.amount
                                    ? _emeraldGreen
                                    : _pearlWhite.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: item.discountType == DiscountType.amount
                                ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _emeraldGreen,
                                ),
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.attach_money_rounded,
                              size: 14, color: _emeraldGreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                item.total.toStringAsFixed(2),
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _crimsonRed.withOpacity(0.7),
                size: 20,
              ),
              onPressed: () => _removeLabourItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    double beforeGrandDiscount = _materialTotal + _labourTotal;

    return Container(
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
          color: _deepPurple.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_rounded,
                    color: _deepPurple,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Materials',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildSummaryRow(
              'Subtotal', _materialSubtotal.toStringAsFixed(2)),
          const SizedBox(height: 4),
          _buildSummaryRow(
              'Discount', '-${_materialDiscountTotal.toStringAsFixed(2)}',
              color: _crimsonRed),
          const SizedBox(height: 4),
          _buildSummaryRow(
              'Tax', '+${_materialTaxTotal.toStringAsFixed(2)}',
              color: _emeraldGreen),
          const SizedBox(height: 8),
          _buildSummaryRow(
              'Material Total', _materialTotal.toStringAsFixed(2),
              isBold: true, color: _deepPurple),

          if (_isLabourProvidedByUs) ...[
            const Divider(color: Colors.white24, height: 24),
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _amberGlow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.engineering_rounded,
                      color: _amberGlow,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Labour',
                    style: TextStyle(
                      color: _pearlWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _buildSummaryRow(
                'Subtotal', _labourSubtotal.toStringAsFixed(2)),
            const SizedBox(height: 4),
            _buildSummaryRow(
                'Discount', '-${_labourDiscountTotal.toStringAsFixed(2)}',
                color: _crimsonRed),
            const SizedBox(height: 8),
            _buildSummaryRow(
                'Labour Total', _labourTotal.toStringAsFixed(2),
                isBold: true, color: _amberGlow),
          ],

          const Divider(color: Colors.white24, height: 24),

          // Grand Discount
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Grand Discount',
                        style: TextStyle(
                          color: _pearlWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _updateGrandDiscount(
                                type: DiscountType.percentage,
                                value: _grandDiscountValue,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: _grandDiscountType ==
                                      DiscountType.percentage
                                      ? _amberGlow.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _grandDiscountType ==
                                        DiscountType.percentage
                                        ? _amberGlow
                                        : Colors.white.withOpacity(0.1),
                                    width: _grandDiscountType ==
                                        DiscountType.percentage
                                        ? 1.5
                                        : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _grandDiscountType ==
                                              DiscountType.percentage
                                              ? _amberGlow
                                              : _pearlWhite.withOpacity(0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: _grandDiscountType ==
                                          DiscountType.percentage
                                          ? Center(
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration:
                                          const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _amberGlow,
                                          ),
                                        ),
                                      )
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.percent_rounded,
                                        size: 12, color: _amberGlow),
                                    const SizedBox(width: 2),
                                    const Text('%',
                                        style: TextStyle(
                                            color: _amberGlow,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _updateGrandDiscount(
                                type: DiscountType.amount,
                                value: _grandDiscountValue,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _grandDiscountType ==
                                      DiscountType.amount
                                      ? _emeraldGreen.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _grandDiscountType ==
                                        DiscountType.amount
                                        ? _emeraldGreen
                                        : Colors.white.withOpacity(0.1),
                                    width: _grandDiscountType ==
                                        DiscountType.amount
                                        ? 1.5
                                        : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _grandDiscountType ==
                                              DiscountType.amount
                                              ? _emeraldGreen
                                              : _pearlWhite.withOpacity(0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: _grandDiscountType ==
                                          DiscountType.amount
                                          ? Center(
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration:
                                          const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _emeraldGreen,
                                          ),
                                        ),
                                      )
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.attach_money_rounded,
                                        size: 12, color: _emeraldGreen),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: TextFormField(
                          initialValue: _grandDiscountValue.toStringAsFixed(
                              _grandDiscountType == DiscountType.percentage
                                  ? 1
                                  : 2),
                          style: const TextStyle(
                              color: _pearlWhite, fontSize: 14),
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: _grandDiscountType ==
                                DiscountType.percentage
                                ? '%'
                                : '',
                            suffixStyle: TextStyle(
                              color: _pearlWhite.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 4),
                          ),
                          onChanged: (value) {
                            double? discount = double.tryParse(value);
                            if (discount != null && discount >= 0) {
                              _updateGrandDiscount(
                                type: _grandDiscountType,
                                value: discount,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _crimsonRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Discount: -${_grandDiscountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _crimsonRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          _buildSummaryRow(
              'Subtotal', beforeGrandDiscount.toStringAsFixed(2)),
          const SizedBox(height: 8),
          _buildSummaryRow('Grand Discount',
              '-${_grandDiscountAmount.toStringAsFixed(2)}',
              color: _crimsonRed),
          const Divider(color: Colors.white24, height: 20),

          Container(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GRAND TOTAL',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_deepPurple, _electricIndigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _grandTotal.toStringAsFixed(2),
                    style: const TextStyle(
                      color: _pearlWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
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
          color: _emeraldGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _emeraldGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payment_rounded,
                  color: _emeraldGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Payment',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount Paid',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _emeraldGreen.withOpacity(0.3),
                        ),
                      ),
                      child: TextFormField(
                        controller: _amountPaidController,
                        style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: ' ',
                          prefixStyle: const TextStyle(
                            color: _emeraldGreen,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: _pearlWhite.withOpacity(0.3),
                          ),
                        ),
                        onChanged: _updateAmountPaid,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPaymentMethod,
                          dropdownColor: _charcoalBlue,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _pearlWhite.withOpacity(0.7),
                          ),
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 14,
                          ),
                          items: _paymentMethods.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Row(
                                children: [
                                  Icon(
                                    _getPaymentMethodIcon(method),
                                    size: 16,
                                    color: _emeraldGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(method),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedPaymentMethod = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _slateGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _balanceDue <= 0
                    ? _emeraldGreen.withOpacity(0.3)
                    : _crimsonRed.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _balanceDue <= 0
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      color: _balanceDue <= 0
                          ? _emeraldGreen
                          : _crimsonRed,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance Due',
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _balanceDue.toStringAsFixed(2),
                          style: TextStyle(
                            color: _balanceDue <= 0
                                ? _emeraldGreen
                                : _crimsonRed,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _paymentStatus == 'Paid'
                        ? _emeraldGreen.withOpacity(0.1)
                        : _paymentStatus == 'Partial'
                        ? _amberGlow.withOpacity(0.1)
                        : _crimsonRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _paymentStatus == 'Paid'
                          ? _emeraldGreen.withOpacity(0.3)
                          : _paymentStatus == 'Partial'
                          ? _amberGlow.withOpacity(0.3)
                          : _crimsonRed.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _paymentStatus,
                    style: TextStyle(
                      color: _paymentStatus == 'Paid'
                          ? _emeraldGreen
                          : _paymentStatus == 'Partial'
                          ? _amberGlow
                          : _crimsonRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'Cash':
        return Icons.money_rounded;
      case 'Card':
        return Icons.credit_card_rounded;
      case 'Bank Transfer':
        return Icons.account_balance_rounded;
      case 'Cheque':
        return Icons.receipt_rounded;
      case 'Online':
        return Icons.payments_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Widget _buildSummaryRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _pearlWhite.withOpacity(0.8),
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? _pearlWhite,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
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
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _emeraldGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.note_alt_rounded,
                  color: _emeraldGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notes & Terms',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: TextFormField(
              controller: _notesController,
              style: const TextStyle(color: _pearlWhite),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes',
                labelStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                hintText: 'Additional notes for the customer...',
                hintStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: TextFormField(
              controller: _termsController,
              style: const TextStyle(color: _pearlWhite),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Terms & Conditions',
                labelStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                hintText: 'Terms and conditions...',
                hintStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}