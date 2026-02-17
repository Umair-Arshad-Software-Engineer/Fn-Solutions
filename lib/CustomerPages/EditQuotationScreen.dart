import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/customer_model.dart';
import '../Models/quotation_model.dart';

class EditQuotationScreen extends StatefulWidget {
  final QuotationModel quotation;
  final String? teamId;
  final String? teamName;

  const EditQuotationScreen({
    super.key,
    required this.quotation,
    this.teamId,
    this.teamName,
  });

  @override
  State<EditQuotationScreen> createState() => _EditQuotationScreenState();
}

class _EditQuotationScreenState extends State<EditQuotationScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _quotationsRef =
  FirebaseDatabase.instance.ref().child('quotations');
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _customersRef =
  FirebaseDatabase.instance.ref().child('customers');

  late List<QuotationItem> _items;
  late DateTime _validUntil;
  late String _selectedStatus;

  // Grand discount
  late DiscountType _grandDiscountType;
  late double _grandDiscountValue;
  late double _grandDiscountAmount;

  late TextEditingController _notesController;
  late TextEditingController _termsController;

  Map<String, dynamic> _currentUser = {};
  CustomerModel? _customer;
  bool _isLoading = false;
  bool _isSaving = false;

  // Calculations
  double _subtotal = 0.0;
  double _itemDiscountTotal = 0.0;
  double _taxTotal = 0.0;
  double _grandTotal = 0.0;

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

  final List<String> _statusOptions = [
    'Draft',
    'Sent',
    'Accepted',
    'Rejected',
    'Expired',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize with existing quotation data
    _items = widget.quotation.items.map((item) => item.copyWith()).toList();
    _validUntil = widget.quotation.validUntil;
    _selectedStatus = widget.quotation.status;

    _grandDiscountType = widget.quotation.grandDiscountType;
    _grandDiscountValue = widget.quotation.grandDiscountValue;
    _grandDiscountAmount = widget.quotation.grandDiscountAmount;

    _notesController = TextEditingController(text: widget.quotation.notes ?? '');
    _termsController =
        TextEditingController(text: widget.quotation.termsAndConditions ?? '');

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
    _loadCustomer();
    _calculateTotals();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    _termsController.dispose();
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

  Future<void> _loadCustomer() async {
    try {
      DatabaseEvent customerEvent =
      await _customersRef.child(widget.quotation.customerId).once();
      if (customerEvent.snapshot.value != null) {
        Map<String, dynamic> customerData =
        Map<String, dynamic>.from(customerEvent.snapshot.value as Map);
        setState(() {
          _customer = CustomerModel.fromMap(
              widget.quotation.customerId, customerData);
        });
      }
    } catch (e) {
      debugPrint('Error loading customer: $e');
    }
  }

  void _addItem() {
    setState(() {
      _items.add(QuotationItem(
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

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateItem(int index,
      {String? name,
        String? description,
        double? quantity,
        double? rate,
        DiscountType? discountType,
        double? discountValue,
        double? taxPercent}) {
    setState(() {
      var item = _items[index];

      if (name != null) item = item.copyWith(name: name);
      if (description != null) item = item.copyWith(description: description);
      if (quantity != null) item = item.copyWith(quantity: quantity);
      if (rate != null) item = item.copyWith(rate: rate);
      if (discountType != null) item = item.copyWith(discountType: discountType);
      if (discountValue != null) item = item.copyWith(discountValue: discountValue);
      if (taxPercent != null) item = item.copyWith(taxPercent: taxPercent);

      // Calculate item totals
      double subtotal = item.quantity * item.rate;

      // Calculate discount based on type
      if (item.discountType == DiscountType.percentage) {
        item.discountAmount = subtotal * (item.discountValue / 100);
      } else {
        // Fixed amount discount (cannot exceed subtotal)
        item.discountAmount =
        item.discountValue > subtotal ? subtotal : item.discountValue;
      }

      double afterDiscount = subtotal - item.discountAmount;
      item.taxAmount = afterDiscount * (item.taxPercent / 100);
      item.total = afterDiscount + item.taxAmount;

      _items[index] = item;
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

  void _calculateTotals() {
    _subtotal = 0.0;
    _itemDiscountTotal = 0.0;
    _taxTotal = 0.0;

    for (var item in _items) {
      double itemSubtotal = item.quantity * item.rate;
      _subtotal += itemSubtotal;
      _itemDiscountTotal += item.discountAmount;
      _taxTotal += item.taxAmount;
    }

    double afterItemDiscount = _subtotal - _itemDiscountTotal;

    // Calculate grand discount based on type
    if (_grandDiscountType == DiscountType.percentage) {
      _grandDiscountAmount = afterItemDiscount * (_grandDiscountValue / 100);
    } else {
      // Fixed amount discount (cannot exceed afterItemDiscount)
      _grandDiscountAmount = _grandDiscountValue > afterItemDiscount
          ? afterItemDiscount
          : _grandDiscountValue;
    }

    _grandTotal = afterItemDiscount - _grandDiscountAmount + _taxTotal;

    setState(() {});
  }

  Future<void> _saveQuotation() async {
    // Validate items
    if (_items.isEmpty) {
      _showErrorSnackBar('Please add at least one item');
      return;
    }

    for (var item in _items) {
      if (item.name.isEmpty) {
        _showErrorSnackBar('Please enter item names');
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

    setState(() => _isSaving = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      QuotationModel updatedQuotation = QuotationModel(
        id: widget.quotation.id,
        quotationNumber: widget.quotation.quotationNumber,
        customerId: widget.quotation.customerId,
        customerName: widget.quotation.customerName,
        customerEmail: widget.quotation.customerEmail,
        customerPhone: widget.quotation.customerPhone,
        customerAddress: widget.quotation.customerAddress,
        createdAt: widget.quotation.createdAt,
        updatedAt: DateTime.now(),
        validUntil: _validUntil,
        createdBy: widget.quotation.createdBy,
        createdByName: widget.quotation.createdByName,
        status: _selectedStatus,
        items: List.from(_items),
        subtotal: _subtotal,
        itemDiscountTotal: _itemDiscountTotal,
        grandDiscountType: _grandDiscountType,
        grandDiscountValue: _grandDiscountValue,
        grandDiscountAmount: _grandDiscountAmount,
        taxTotal: _taxTotal,
        grandTotal: _grandTotal,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        termsAndConditions: _termsController.text.trim().isNotEmpty
            ? _termsController.text.trim()
            : null,
        teamId: widget.teamId,
        teamName: widget.teamName,
      );

      await _quotationsRef.child(widget.quotation.id).set(updatedQuotation.toMap());

      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackBar('✅ Quotation updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update quotation: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: _pearlWhite,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Quotation',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.quotation.quotationNumber,
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
              color: _getStatusColor(_selectedStatus).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(_selectedStatus),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedStatus,
                  style: TextStyle(
                    color: _getStatusColor(_selectedStatus),
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
                _customer != null
                    ? _buildCustomerInfoCard()
                    : _buildCustomerInfoPlaceholder(),

                const SizedBox(height: 20),

                // Quotation Details
                _buildQuotationDetailsCard(),

                const SizedBox(height: 20),

                // Items Header
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
                            Icons.shopping_cart_rounded,
                            color: _deepPurple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Items',
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
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Item'),
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

                // Items Table
                _buildItemsTable(),

                const SizedBox(height: 24),

                // Summary Card
                _buildSummaryCard(),

                const SizedBox(height: 20),

                // Notes & Terms
                _buildNotesCard(),

                const SizedBox(height: 20),

                // Status & Validity
                _buildStatusCard(),

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
                    onPressed: _isSaving ? null : _saveQuotation,
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _pearlWhite),
                      ),
                    )
                        : Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.save_rounded),
                        SizedBox(width: 12),
                        Text(
                          'Update Quotation',
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
                    _customer!.name[0].toUpperCase(),
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
                      _customer!.name,
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _customer!.email,
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    if (_customer!.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _customer!.phone,
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

  Widget _buildCustomerInfoPlaceholder() {
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: _pearlWhite,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.quotation.customerName,
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Fix: Provide default empty string for nullable email
                Text(
                  widget.quotation.customerEmail ?? 'No email provided',
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                // Fix: Add null check for customerPhone
                if (widget.quotation.customerPhone != null &&
                    widget.quotation.customerPhone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.quotation.customerPhone!,
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
    );
  }

  Widget _buildQuotationDetailsCard() {
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
                'Validity',
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
                      'Valid Until',
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
                            '${_validUntil.day}/${_validUntil.month}/${_validUntil.year}',
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
                                initialDate: _validUntil,
                                firstDate: DateTime.now(),
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
                                  _validUntil = picked;
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _skyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: _skyBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quotation Number',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _slateGray,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  widget.quotation.quotationNumber,
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Container(
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
            itemCount: _items.length,
            separatorBuilder: (context, index) => const Divider(
              color: Colors.white24,
              height: 1,
            ),
            itemBuilder: (context, index) {
              var item = _items[index];
              return _buildItemRow(index, item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, QuotationItem item) {
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (value) {
                    _updateItem(index, name: value);
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
                    _updateItem(index, description: value);
                  },
                ),
              ],
            ),
          ),

          // Quantity
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: item.quantity.toString(),
              style: const TextStyle(color: _pearlWhite, fontSize: 14),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? qty = double.tryParse(value);
                if (qty != null && qty > 0) {
                  _updateItem(index, quantity: qty);
                }
              },
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
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? rate = double.tryParse(value);
                if (rate != null && rate > 0) {
                  _updateItem(index, rate: rate);
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
                    : '\$',
                suffixStyle: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? discount = double.tryParse(value);
                if (discount != null && discount >= 0) {
                  _updateItem(index, discountValue: discount);
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
                  // Percentage Radio
                  GestureDetector(
                    onTap: () => _updateItem(index,
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
                          color: item.discountType == DiscountType.percentage
                              ? _amberGlow
                              : Colors.white.withOpacity(0.1),
                          width: item.discountType == DiscountType.percentage
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
                            child: item.discountType == DiscountType.percentage
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
                  // Fixed Amount Radio
                  GestureDetector(
                    onTap: () =>
                        _updateItem(index, discountType: DiscountType.amount),
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
                                color: item.discountType == DiscountType.amount
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
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (value) {
                double? tax = double.tryParse(value);
                if (tax != null && tax >= 0) {
                  _updateItem(index, taxPercent: tax);
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
                '\$${item.total.toStringAsFixed(2)}',
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
              onPressed: () => _removeItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    double afterItemDiscount = _subtotal - _itemDiscountTotal;

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
          // Summary Rows
          _buildSummaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Item Discount',
              '-\$${_itemDiscountTotal.toStringAsFixed(2)}',
              color: _crimsonRed),
          const SizedBox(height: 8),
          _buildSummaryRow('Subtotal after discount',
              '\$${afterItemDiscount.toStringAsFixed(2)}',
              isBold: true),
          const Divider(color: Colors.white24, height: 20),

          // Grand Discount with Radio Buttons
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
                    // Radio Buttons for Discount Type
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          // Percentage Radio
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
                                    const Icon(
                                      Icons.percent_rounded,
                                      size: 12,
                                      color: _amberGlow,
                                    ),
                                    const SizedBox(width: 2),
                                    const Text(
                                      '%',
                                      style: TextStyle(
                                        color: _amberGlow,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Fixed Amount Radio
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
                                    const Icon(
                                      Icons.attach_money_rounded,
                                      size: 12,
                                      color: _emeraldGreen,
                                    ),
                                    const SizedBox(width: 2),
                                    const Text(
                                      '\$',
                                      style: TextStyle(
                                        color: _emeraldGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                : '\$',
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
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _crimsonRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Discount: -\$${_grandDiscountAmount.toStringAsFixed(2)}',
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
          _buildSummaryRow('Tax Total', '+\$${_taxTotal.toStringAsFixed(2)}',
              color: _emeraldGreen),
          const Divider(color: Colors.white24, height: 20),

          // Grand Total
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
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_deepPurple, _electricIndigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\$${_grandTotal.toStringAsFixed(2)}',
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

  Widget _buildStatusCard() {
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
                  Icons.flag_rounded,
                  color: _amberGlow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Status',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusOptions.map((status) {
                bool isSelected = _selectedStatus == status;
                Color statusColor = _getStatusColor(status);
                bool isDisabled = false;

                // Prevent changing from Accepted/Rejected
                if (widget.quotation.status == 'Accepted' ||
                    widget.quotation.status == 'Rejected') {
                  isDisabled = status != widget.quotation.status;
                }

                return GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [
                          statusColor,
                          statusColor.withOpacity(0.7)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : null,
                      color: isSelected
                          ? null
                          : _slateGray.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected
                            ? statusColor
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected ? _pearlWhite : statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: TextStyle(
                            color: isSelected
                                ? _pearlWhite
                                : isDisabled
                                ? statusColor.withOpacity(0.3)
                                : statusColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (widget.quotation.status == 'Accepted' ||
              widget.quotation.status == 'Rejected')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _amberGlow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _amberGlow.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 20,
                      color: _amberGlow,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This quotation has been ${widget.quotation.status.toLowerCase()}. Status cannot be changed.',
                        style: TextStyle(
                          color: _amberGlow,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return _steelGray;
      case 'Sent':
        return _skyBlue;
      case 'Accepted':
        return _emeraldGreen;
      case 'Rejected':
        return _crimsonRed;
      case 'Expired':
        return _amberGlow;
      default:
        return _steelGray;
    }
  }
}