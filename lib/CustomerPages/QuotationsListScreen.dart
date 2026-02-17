import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/quotation_model.dart';
import '../Models/customer_model.dart';
import 'CreateBillScreen.dart';
import 'EditQuotationScreen.dart';

class QuotationsListScreen extends StatefulWidget {
  final CustomerModel? customer; // Optional - to show quotes for specific customer
  final String? teamId;
  final String? teamName;

  const QuotationsListScreen({
    super.key,
    this.customer,
    this.teamId,
    this.teamName,
  });

  @override
  State<QuotationsListScreen> createState() => _QuotationsListScreenState();
}

class _QuotationsListScreenState extends State<QuotationsListScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _quotationsRef =
  FirebaseDatabase.instance.ref().child('quotations');
  final DatabaseReference _customersRef =
  FirebaseDatabase.instance.ref().child('customers');
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');

  List<QuotationModel> _quotations = [];
  List<QuotationModel> _filteredQuotations = [];
  Map<String, CustomerModel> _customerCache = {};
  Map<String, Map<String, dynamic>> _userCache = {};

  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Premium color palette - matching the existing design
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
  static const Color _violet = Color(0xFF8B5CF6);
  static const Color _pink = Color(0xFFEC4899);

  final List<String> _statusFilters = [
    'All',
    'Draft',
    'Sent',
    'Accepted',
    'Rejected',
    'Expired',
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
    _loadQuotations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      DatabaseEvent quotationsEvent = await _quotationsRef.once();

      _quotations.clear();
      _customerCache.clear();
      _userCache.clear();

      if (quotationsEvent.snapshot.value != null) {
        Map<dynamic, dynamic> quotationsMap =
        quotationsEvent.snapshot.value as Map<dynamic, dynamic>;

        for (var entry in quotationsMap.entries) {
          String quotationId = entry.key;
          Map<String, dynamic> quotationData =
          Map<String, dynamic>.from(entry.value as Map);

          QuotationModel quotation =
          QuotationModel.fromMap(quotationId, quotationData);

          // Filter by customer if specified
          if (widget.customer != null) {
            if (quotation.customerId == widget.customer!.id) {
              _quotations.add(quotation);
            }
          } else {
            // For workers, show only their quotations
            if (user != null && quotation.createdBy == user.uid) {
              _quotations.add(quotation);
            }
          }
        }
      }

      // Sort by date (newest first)
      _quotations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _applyFilters();
    } catch (e) {
      _showErrorSnackBar('Failed to load quotations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<CustomerModel?> _getCustomer(String customerId) async {
    if (_customerCache.containsKey(customerId)) {
      return _customerCache[customerId];
    }

    try {
      DatabaseEvent customerEvent = await _customersRef.child(customerId).once();
      if (customerEvent.snapshot.value != null) {
        Map<String, dynamic> customerData =
        Map<String, dynamic>.from(customerEvent.snapshot.value as Map);
        CustomerModel customer =
        CustomerModel.fromMap(customerId, customerData);
        _customerCache[customerId] = customer;
        return customer;
      }
    } catch (e) {
      debugPrint('Error loading customer: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      DatabaseEvent userEvent = await _usersRef.child(userId).once();
      if (userEvent.snapshot.value != null) {
        Map<String, dynamic> userData =
        Map<String, dynamic>.from(userEvent.snapshot.value as Map);
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
    return null;
  }

  void _applyFilters() {
    setState(() {
      _filteredQuotations = _quotations.where((quotation) {
        // Apply status filter
        if (_selectedFilter != 'All' && quotation.status != _selectedFilter) {
          return false;
        }

        // Apply search query
        if (_searchQuery.isNotEmpty) {
          String query = _searchQuery.toLowerCase();
          return quotation.quotationNumber.toLowerCase().contains(query) ||
              quotation.customerName.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
                Icons.description_rounded,
                color: _pearlWhite,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer != null
                      ? 'Quotations for ${widget.customer!.name}'
                      : 'My Quotations',
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_filteredQuotations.length} total',
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
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: _pearlWhite,
                size: 22,
              ),
              onPressed: _loadQuotations,
              tooltip: 'Refresh',
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
              'Loading quotations...',
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
          child: Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _charcoalBlue,
                      _charcoalBlue.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: TextFormField(
                        style: const TextStyle(color: _pearlWhite),
                        decoration: InputDecoration(
                          hintText: 'Search by number or customer...',
                          hintStyle: TextStyle(
                            color: _pearlWhite.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: _deepPurple.withOpacity(0.8),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: _pearlWhite.withOpacity(0.5),
                            ),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Status Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusFilters.map((status) {
                          bool isSelected = _selectedFilter == status;
                          Color statusColor = status == 'All'
                              ? _deepPurple
                              : _getStatusColor(status);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = status;
                                _applyFilters();
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
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
                                  if (status != 'All')
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _pearlWhite
                                            : statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (status != 'All')
                                    const SizedBox(width: 8),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: isSelected
                                          ? _pearlWhite
                                          : status == 'All'
                                          ? _pearlWhite
                                          : statusColor,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Quotations List
              Expanded(
                child: _filteredQuotations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredQuotations.length,
                  itemBuilder: (context, index) {
                    var quotation = _filteredQuotations[index];
                    return TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(
                          milliseconds: 300 + (index * 50)),
                      curve: Curves.easeOutCubic,
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _buildQuotationCard(quotation),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotationCard(QuotationModel quotation) {
    Color statusColor = _getStatusColor(quotation.status);
    bool isExpired = quotation.validUntil.isBefore(DateTime.now()) &&
        quotation.status != 'Accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          color: isExpired
              ? _crimsonRed.withOpacity(0.3)
              : statusColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isExpired
                      ? [_crimsonRed, _crimsonRed.withOpacity(0.7)]
                      : [statusColor, statusColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Q-${quotation.quotationNumber.substring(quotation.quotationNumber.lastIndexOf('-') + 1)}',
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    quotation.quotationNumber,
                    style: const TextStyle(
                      color: _pearlWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
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
                  child: Text(
                    quotation.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: _pearlWhite.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        quotation.customerName,
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _pearlWhite.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Created: ${_formatDate(quotation.createdAt)}',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: isExpired
                          ? _crimsonRed
                          : _pearlWhite.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpired ? 'Expired' : 'Valid till: ${_formatDate(quotation.validUntil)}',
                      style: TextStyle(
                        color: isExpired
                            ? _crimsonRed
                            : _pearlWhite.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: isExpired ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${quotation.items.length} ${quotation.items.length == 1 ? 'item' : 'items'}',
                        style: TextStyle(
                          color: _deepPurple,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _emeraldGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total: \$${quotation.grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _emeraldGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View Details Button
                OutlinedButton.icon(
                  onPressed: () {
                    _showQuotationDetails(quotation);
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _skyBlue,
                    side: BorderSide(color: _skyBlue.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Add this after the View button
                if (quotation.status == 'Accepted') ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_emeraldGreen, _deepPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateBillScreen(
                              quotation: quotation,
                              teamId: widget.teamId,
                              teamName: widget.teamName,
                            ),
                          ),
                        ).then((refresh) {
                          if (refresh == true) {
                            _loadQuotations();
                            _showSuccessSnackBar('✅ Bill created successfully!');
                          }
                        });
                      },
                      icon: const Icon(Icons.receipt_rounded, size: 18),
                      label: const Text('Create Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: _pearlWhite,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Edit Button (only for Draft status)
                if (quotation.status == 'Draft')
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditQuotationScreen(
                            quotation: quotation,
                            teamId: widget.teamId,
                            teamName: widget.teamName,
                          ),
                        ),
                      ).then((refresh) {
                        if (refresh == true) {
                          _loadQuotations();
                          _showSuccessSnackBar('✅ Quotation updated successfully!');
                        }
                      });
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _amberGlow,
                      side: BorderSide(color: _amberGlow.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                // Send Button (for Draft)
                if (quotation.status == 'Draft')
                  const SizedBox(width: 8),
                if (quotation.status == 'Draft')
                  ElevatedButton.icon(
                    onPressed: () {
                      _updateQuotationStatus(quotation.id, 'Sent');
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _skyBlue,
                      foregroundColor: _pearlWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                // Accept/Reject for Sent status
                if (quotation.status == 'Sent') ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      _updateQuotationStatus(quotation.id, 'Rejected');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _crimsonRed,
                      side: BorderSide(color: _crimsonRed.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _updateQuotationStatus(quotation.id, 'Accepted');
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emeraldGreen,
                      foregroundColor: _pearlWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                // Delete Button (only for Draft)
                if (quotation.status == 'Draft') ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _showDeleteDialog(quotation.id);
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: _crimsonRed.withOpacity(0.7),
                      size: 22,
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

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _charcoalBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _deepPurple.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.description_rounded,
                size: 80,
                color: _deepPurple.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.customer != null
                  ? 'No Quotations for this Customer'
                  : 'No Quotations Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _pearlWhite.withOpacity(0.9),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.customer != null
                    ? 'Create your first quotation for ${widget.customer!.name} to get started'
                    : _searchQuery.isNotEmpty || _selectedFilter != 'All'
                    ? 'Try adjusting your filters or search query'
                    : 'Create your first quotation to get started',
                style: TextStyle(
                  fontSize: 15,
                  color: _pearlWhite.withOpacity(0.6),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedFilter != 'All') ...[
              const SizedBox(height: 24),
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
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedFilter = 'All';
                      _applyFilters();
                    });
                  },
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: _pearlWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateQuotationStatus(String quotationId, String status) async {
    try {
      await _quotationsRef.child(quotationId).update({
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await _loadQuotations();
      _showSuccessSnackBar('✅ Quotation marked as $status');
    } catch (e) {
      _showErrorSnackBar('Failed to update status: $e');
    }
  }

  Future<void> _showDeleteDialog(String quotationId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _crimsonRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: _crimsonRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Quotation',
              style: TextStyle(
                color: _pearlWhite,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this quotation? This action cannot be undone.',
          style: TextStyle(color: _pearlWhite, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _pearlWhite.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              color: _crimsonRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: _pearlWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _quotationsRef.child(quotationId).remove();
        await _loadQuotations();
        _showSuccessSnackBar('✅ Quotation deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to delete quotation: $e');
      }
    }
  }//s

  void _showQuotationDetails(QuotationModel quotation) {
    Color statusColor = _getStatusColor(quotation.status);
    bool isExpired = quotation.validUntil.isBefore(DateTime.now()) &&
        quotation.status != 'Accepted';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: 900,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - Fixed at top
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_deepPurple, _electricIndigo],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: _pearlWhite,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quotation.quotationNumber,
                            style: const TextStyle(
                              color: _pearlWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Created on ${_formatDate(quotation.createdAt)}',
                            style: TextStyle(
                              color: _pearlWhite.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            quotation.status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _slateGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
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
                                gradient: const LinearGradient(
                                  colors: [_skyBlue, _royalBlue],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  quotation.customerName.isNotEmpty
                                      ? quotation.customerName[0].toUpperCase()
                                      : 'C',
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
                                    quotation.customerName,
                                    style: const TextStyle(
                                      color: _pearlWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    quotation.customerEmail ?? 'No email provided',
                                    style: TextStyle(
                                      color: _pearlWhite.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (quotation.customerPhone != null &&
                                      quotation.customerPhone!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      quotation.customerPhone!,
                                      style: TextStyle(
                                        color: _pearlWhite.withOpacity(0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Items Table
                      const Text(
                        'Items',
                        style: TextStyle(
                          color: _pearlWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: _slateGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              _slateGray.withOpacity(0.5),
                            ),
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Item',
                                  style: TextStyle(
                                    color: _pearlWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Qty',
                                  style: TextStyle(
                                    color: _pearlWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Rate',
                                  style: TextStyle(
                                    color: _pearlWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Discount',
                                  style: TextStyle(
                                    color: _pearlWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Tax',
                                  style: TextStyle(
                                    color: _pearlWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Total',
                                  style: TextStyle(
                                    color: _pearlWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            rows: quotation.items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: _pearlWhite,
                                          ),
                                        ),
                                        if (item.description?.isNotEmpty ?? false)
                                          Text(
                                            item.description!,
                                            style: TextStyle(
                                              color: _pearlWhite.withOpacity(0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.quantity.toStringAsFixed(0),
                                      style: const TextStyle(color: _pearlWhite),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '\$${item.rate.toStringAsFixed(2)}',
                                      style: const TextStyle(color: _pearlWhite),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.discountType == DiscountType.percentage
                                          ? '${item.discountValue.toStringAsFixed(1)}%'
                                          : '\$${item.discountValue.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: _crimsonRed.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${item.taxPercent.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: _emeraldGreen.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '\$${item.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: _pearlWhite,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Summary
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _slateGray.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow(
                                    'Subtotal',
                                    '\$${quotation.subtotal.toStringAsFixed(2)}',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'Item Discount',
                                    '-\$${quotation.itemDiscountTotal.toStringAsFixed(2)}',
                                    color: _crimsonRed,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'Grand Discount',
                                    '-\$${quotation.grandDiscountAmount.toStringAsFixed(2)}',
                                    color: _crimsonRed,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    'Tax Total',
                                    '+\$${quotation.taxTotal.toStringAsFixed(2)}',
                                    color: _emeraldGreen,
                                  ),
                                  const Divider(color: Colors.white24, height: 20),
                                  _buildDetailRow(
                                    'GRAND TOTAL',
                                    '\$${quotation.grandTotal.toStringAsFixed(2)}',
                                    isBold: true,
                                    color: _deepPurple,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                if (quotation.notes != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _slateGray.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.note_alt_rounded,
                                              size: 16,
                                              color: _emeraldGreen,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Notes',
                                              style: TextStyle(
                                                color: _pearlWhite,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          quotation.notes!,
                                          style: TextStyle(
                                            color: _pearlWhite.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (quotation.termsAndConditions != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _slateGray.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.gavel_rounded,
                                              size: 16,
                                              color: _amberGlow,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Terms & Conditions',
                                              style: TextStyle(
                                                color: _pearlWhite,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          quotation.termsAndConditions!,
                                          style: TextStyle(
                                            color: _pearlWhite.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
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
                ),
              ),

              // Actions - Fixed at bottom
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: _pearlWhite.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 12),
                    if (quotation.status == 'Draft')
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
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditQuotationScreen(
                                  quotation: quotation,
                                  teamId: widget.teamId,
                                  teamName: widget.teamName,
                                ),
                              ),
                            ).then((refresh) {
                              if (refresh == true) {
                                _loadQuotations();
                                _showSuccessSnackBar(
                                    '✅ Quotation updated successfully!');
                              }
                            });
                          },
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Edit Quotation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: _pearlWhite,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    if (quotation.status == 'Draft')
                      const SizedBox(width: 12),
                    if (quotation.status == 'Draft')
                      Container(
                        decoration: BoxDecoration(
                          color: _skyBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateQuotationStatus(quotation.id, 'Sent');
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send Quotation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _skyBlue,
                            foregroundColor: _pearlWhite,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
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
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

