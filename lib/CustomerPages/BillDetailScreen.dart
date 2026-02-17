// BillPages/BillDetailsScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/bill_model.dart';
import '../Models/labour_model.dart';
import '../Models/quotation_model.dart';
import 'PayBillScreen.dart';

class BillDetailsScreen extends StatefulWidget {
  final BillModel bill;
  final String? teamId;
  final String? teamName;

  const BillDetailsScreen({
    super.key,
    required this.bill,
    this.teamId,
    this.teamName,
  });

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen>
    with SingleTickerProviderStateMixin {
  late BillModel _bill;
  bool _isLoading = false;

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

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return _emeraldGreen;
      case 'Partial':
        return _amberGlow;
      case 'Overdue':
        return _crimsonRed;
      case 'Unpaid':
      default:
        return _steelGray;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Paid':
        return Icons.check_circle_rounded;
      case 'Partial':
        return Icons.payment_rounded;
      case 'Overdue':
        return Icons.warning_rounded;
      case 'Unpaid':
      default:
        return Icons.pending_actions_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    bool isOverdue = _bill.paymentStatus != 'Paid' &&
        _bill.paymentStatus != 'Overdue' &&
        _bill.dueDate.isBefore(DateTime.now());

    String displayStatus = isOverdue ? 'Overdue' : _bill.paymentStatus;
    Color statusColor =
    isOverdue ? _crimsonRed : _getStatusColor(_bill.paymentStatus);

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bill.billNumber,
                    style: const TextStyle(
                      color: _pearlWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Created: ${_formatDate(_bill.createdAt)}',
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  displayStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_bill.paymentStatus != 'Paid' && _bill.balanceDue > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _processPayment,
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Pay Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emeraldGreen,
                  foregroundColor: _pearlWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
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
                _buildCustomerInfoCard(),
                const SizedBox(height: 20),

                // Bill Details Card
                _buildBillDetailsCard(),
                const SizedBox(height: 20),

                // Material Items Table Card
                _buildMaterialItemsTableCard(),
                const SizedBox(height: 20),

                // Labour Items Table Card (if any and provided by us)
                if (_bill.labourItems.isNotEmpty &&
                    _bill.isLabourProvidedByUs) ...[
                  _buildLabourItemsTableCard(),
                  const SizedBox(height: 20),
                ],

                // Summary Card
                _buildSummaryCard(),
                const SizedBox(height: 20),

                // Payment Info Card
                _buildPaymentInfoCard(),
                const SizedBox(height: 20),

                // Notes & Terms Card
                if (_bill.notes != null ||
                    _bill.termsAndConditions != null)
                  _buildNotesCard(),
                const SizedBox(height: 32),
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
                  gradient: const LinearGradient(
                    colors: [_skyBlue, _royalBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _bill.customerName[0].toUpperCase(),
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
                      _bill.customerName,
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_bill.customerEmail != null &&
                        _bill.customerEmail!.isNotEmpty)
                      Text(
                        _bill.customerEmail!,
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    if (_bill.customerPhone != null &&
                        _bill.customerPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _bill.customerPhone!,
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (_bill.customerAddress != null &&
                        _bill.customerAddress!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _bill.customerAddress!,
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                  Icons.receipt_rounded,
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
                child: _buildDetailItem(
                  'Bill Number',
                  _bill.billNumber,
                  Icons.numbers_rounded,
                  _deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  'Quotation',
                  _bill.quotationNumber ?? 'N/A',
                  Icons.description_rounded,
                  _skyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Bill Date',
                  _formatDate(_bill.billDate),
                  Icons.calendar_today_rounded,
                  _amberGlow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  'Due Date',
                  _formatDate(_bill.dueDate),
                  Icons.event_rounded,
                  _crimsonRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Created By',
                  _bill.createdByName,
                  Icons.person_outline_rounded,
                  _emeraldGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  'Team',
                  _bill.teamName ?? 'N/A',
                  Icons.group_rounded,
                  _royalBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _slateGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ MATERIAL ITEMS TABLE ============
  Widget _buildMaterialItemsTableCard() {
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
          // Header
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_bill.materialItems.length} items',
                  style: const TextStyle(
                    color: _deepPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_bill.materialItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: _pearlWhite.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No material items',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _deepPurple.withOpacity(0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTableHeader('#', flex: 1),
                      _buildTableHeader('Item', flex: 4),
                      _buildTableHeader('Qty', flex: 2, align: TextAlign.center),
                      _buildTableHeader('Rate', flex: 2, align: TextAlign.right),
                      _buildTableHeader('Disc.', flex: 2, align: TextAlign.right),
                      _buildTableHeader('Tax', flex: 2, align: TextAlign.right),
                      _buildTableHeader('Total', flex: 3, align: TextAlign.right),
                    ],
                  ),
                ),

                // Table Body
                Container(
                  decoration: BoxDecoration(
                    color: _slateGray.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _bill.materialItems.length,
                    separatorBuilder: (context, index) => Divider(
                      color: _pearlWhite.withOpacity(0.1),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = _bill.materialItems[index];
                      return _buildMaterialTableRow(item, index + 1);
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Subtotals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _deepPurple.withOpacity(0.1),
                        _deepPurple.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _deepPurple.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTotalRow(
                        'Subtotal',
                        '\$${_bill.materialSubtotal.toStringAsFixed(2)}',
                      ),
                      if (_bill.materialDiscountTotal > 0)
                        _buildTotalRow(
                          'Total Discount',
                          '-\$${_bill.materialDiscountTotal.toStringAsFixed(2)}',
                          valueColor: _crimsonRed,
                        ),
                      if (_bill.materialTaxTotal > 0)
                        _buildTotalRow(
                          'Total Tax',
                          '+\$${_bill.materialTaxTotal.toStringAsFixed(2)}',
                          valueColor: _emeraldGreen,
                        ),
                      const SizedBox(height: 8),
                      Divider(color: _pearlWhite.withOpacity(0.2)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MATERIAL TOTAL',
                            style: TextStyle(
                              color: _pearlWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _deepPurple,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${_bill.materialTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _pearlWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTableHeader(String text,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: _pearlWhite.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: align,
      ),
    );
  }

  Future<void> _processPayment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayBillScreen(
          bill: _bill,
          teamId: widget.teamId,
          teamName: widget.teamName,
        ),
      ),
    );

    if (result == true) {
      // Refresh bill data after payment
      setState(() => _isLoading = true);
      try {
        DatabaseReference billRef = FirebaseDatabase.instance.ref().child('bills').child(_bill.id);
        DatabaseEvent event = await billRef.once();
        if (event.snapshot.value != null) {
          Map<String, dynamic> billData = Map<String, dynamic>.from(
            event.snapshot.value as Map,
          );
          billData['id'] = _bill.id;
          setState(() {
            _bill = BillModel.fromMap(_bill.id, billData);
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing bill: $e'),
            backgroundColor: _crimsonRed,
          ),
        );
      }
    }
  }

  Widget _buildMaterialTableRow(QuotationItem  item, int index) {
    String discountText = '-';
    if (item.discountAmount > 0) {
      if (item.discountType == DiscountType.percentage) {
        discountText = '${item.discountValue.toStringAsFixed(0)}%';
      } else {
        discountText = '\$${item.discountValue.toStringAsFixed(2)}';
      }
    }

    String taxText = item.taxPercent > 0 ? '${item.taxPercent.toStringAsFixed(0)}%' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index
          Expanded(
            flex: 1,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _deepPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: _deepPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Item Name & Description
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.5),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Quantity
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _skyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.quantity}',
                style: const TextStyle(
                  color: _skyBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Rate
          Expanded(
            flex: 2,
            child: Text(
              '\$${item.rate.toStringAsFixed(2)}',
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Discount
          Expanded(
            flex: 2,
            child: Text(
              discountText,
              style: TextStyle(
                color: item.discountAmount > 0
                    ? _crimsonRed
                    : _pearlWhite.withOpacity(0.4),
                fontSize: 11,
                fontWeight:
                item.discountAmount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Tax
          Expanded(
            flex: 2,
            child: Text(
              taxText,
              style: TextStyle(
                color: item.taxPercent > 0
                    ? _emeraldGreen
                    : _pearlWhite.withOpacity(0.4),
                fontSize: 11,
                fontWeight:
                item.taxPercent > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Total
          Expanded(
            flex: 3,
            child: Text(
              '\$${item.total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: _pearlWhite,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _pearlWhite,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============ LABOUR ITEMS TABLE ============
  Widget _buildLabourItemsTableCard() {
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
          // Header
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _amberGlow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_bill.labourItems.length} items',
                  style: const TextStyle(
                    color: _amberGlow,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: _amberGlow.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeader('#', flex: 1),
                _buildTableHeader('Service', flex: 5),
                _buildTableHeader('Hours', flex: 2, align: TextAlign.center),
                _buildTableHeader('Rate/Hr', flex: 2, align: TextAlign.right),
                _buildTableHeader('Disc.', flex: 2, align: TextAlign.right),
                _buildTableHeader('Total', flex: 3, align: TextAlign.right),
              ],
            ),
          ),

          // Table Body
          Container(
            decoration: BoxDecoration(
              color: _slateGray.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bill.labourItems.length,
              separatorBuilder: (context, index) => Divider(
                color: _pearlWhite.withOpacity(0.1),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = _bill.labourItems[index];
                return _buildLabourTableRow(item, index + 1);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Subtotals
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _amberGlow.withOpacity(0.1),
                  _amberGlow.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _amberGlow.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                _buildTotalRow(
                  'Subtotal',
                  '\$${_bill.labourSubtotal.toStringAsFixed(2)}',
                ),
                if (_bill.labourDiscountTotal > 0)
                  _buildTotalRow(
                    'Total Discount',
                    '-\$${_bill.labourDiscountTotal.toStringAsFixed(2)}',
                    valueColor: _crimsonRed,
                  ),
                const SizedBox(height: 8),
                Divider(color: _pearlWhite.withOpacity(0.2)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LABOUR TOTAL',
                      style: TextStyle(
                        color: _pearlWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _amberGlow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '\$${_bill.labourTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _charcoalBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourTableRow(LabourItem item, int index) {
    String discountText = '-';
    if (item.discountAmount > 0) {
      if (item.discountType == DiscountType.percentage) {
        discountText = '${item.discountValue.toStringAsFixed(0)}%';
      } else {
        discountText = '\$${item.discountValue.toStringAsFixed(2)}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index
          Expanded(
            flex: 1,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _amberGlow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: _amberGlow,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Service Name & Description
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.5),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Hours
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _amberGlow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.hours}',
                style: const TextStyle(
                  color: _amberGlow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Rate
          Expanded(
            flex: 2,
            child: Text(
              '\$${item.rate.toStringAsFixed(2)}',
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Discount
          Expanded(
            flex: 2,
            child: Text(
              discountText,
              style: TextStyle(
                color: item.discountAmount > 0
                    ? _crimsonRed
                    : _pearlWhite.withOpacity(0.4),
                fontSize: 11,
                fontWeight:
                item.discountAmount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Total
          Expanded(
            flex: 3,
            child: Text(
              '\$${item.total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: _pearlWhite,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    double beforeGrandDiscount = _bill.materialTotal + _bill.labourTotal;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _emeraldGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: _emeraldGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Bill Summary',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary rows
          _buildSummaryRow('Material Total',
              '\$${_bill.materialTotal.toStringAsFixed(2)}'),

          if (_bill.labourItems.isNotEmpty && _bill.isLabourProvidedByUs)
            _buildSummaryRow(
                'Labour Total', '\$${_bill.labourTotal.toStringAsFixed(2)}'),

          const SizedBox(height: 8),
          Divider(color: _pearlWhite.withOpacity(0.15)),
          const SizedBox(height: 8),

          _buildSummaryRow(
              'Subtotal', '\$${beforeGrandDiscount.toStringAsFixed(2)}'),

          if (_bill.grandDiscountAmount > 0)
            _buildSummaryRow(
              'Grand Discount (${_bill.grandDiscountType == DiscountType.percentage ? '${_bill.grandDiscountValue}%' : 'Fixed'})',
              '-\$${_bill.grandDiscountAmount.toStringAsFixed(2)}',
              color: _crimsonRed,
            ),

          const SizedBox(height: 12),
          Divider(color: _pearlWhite.withOpacity(0.2), thickness: 2),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRAND TOTAL',
                      style: TextStyle(
                        color: _pearlWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Including all taxes & discounts',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${_bill.grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    bool isOverdue = _bill.paymentStatus != 'Paid' &&
        _bill.paymentStatus != 'Overdue' &&
        _bill.dueDate.isBefore(DateTime.now());

    String displayStatus = isOverdue ? 'Overdue' : _bill.paymentStatus;
    Color statusColor =
    isOverdue ? _crimsonRed : _getStatusColor(_bill.paymentStatus);

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
          color: statusColor.withOpacity(0.2),
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getStatusIcon(displayStatus),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Payment Information',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Payment Stats Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _emeraldGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _emeraldGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: _emeraldGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Amount Paid',
                            style: TextStyle(
                              color: _pearlWhite.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${_bill.amountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _emeraldGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_bill.balanceDue <= 0
                        ? _emeraldGreen
                        : _crimsonRed)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_bill.balanceDue <= 0
                          ? _emeraldGreen
                          : _crimsonRed)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _bill.balanceDue <= 0
                                ? Icons.done_all_rounded
                                : Icons.schedule_rounded,
                            size: 16,
                            color: _bill.balanceDue <= 0
                                ? _emeraldGreen
                                : _crimsonRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Balance Due',
                            style: TextStyle(
                              color: _pearlWhite.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${_bill.balanceDue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _bill.balanceDue <= 0
                              ? _emeraldGreen
                              : _crimsonRed,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          if (_bill.amountPaid > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Progress',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(_bill.amountPaid / _bill.grandTotal * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: _emeraldGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _bill.amountPaid / _bill.grandTotal,
                      backgroundColor: _charcoalBlue,
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(_emeraldGreen),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Payment Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payment_rounded,
                      size: 16,
                      color: _pearlWhite.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment Method: ',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _bill.paymentMethod ?? 'Not specified',
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_bill.paymentDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: _pearlWhite.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Date: ',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _formatDate(_bill.paymentDate!),
                        style: const TextStyle(
                          color: _pearlWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
          if (_bill.notes != null && _bill.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: _emeraldGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Notes',
                        style: TextStyle(
                          color: _emeraldGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bill.notes!,
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_bill.termsAndConditions != null &&
              _bill.termsAndConditions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        size: 14,
                        color: _amberGlow,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          color: _amberGlow,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bill.termsAndConditions!,
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
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
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? _pearlWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}