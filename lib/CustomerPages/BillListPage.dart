// BillPages/BillsListScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/bill_model.dart';
import '../Pdfs/pdfforbill.dart';
import 'BillDetailScreen.dart';
import 'CreateBillScreen.dart';

class BillsListScreen extends StatefulWidget {
  final String? teamId;
  final String? teamName;

  const BillsListScreen({
    super.key,
    this.teamId,
    this.teamName,
  });

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _billsRef =
  FirebaseDatabase.instance.ref().child('bills');
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');

  List<BillModel> _bills = [];
  List<BillModel> _filteredBills = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _currentUser = {};

  // Filters
  String _selectedFilter = 'All';
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Stats
  int _totalBills = 0;
  double _totalRevenue = 0.0;
  double _totalPaid = 0.0;
  double _totalPending = 0.0;
  int _overdueCount = 0;

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

  final List<String> _filterOptions = [
    'All',
    'Paid',
    'Unpaid',
    'Partial',
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
    _loadBills();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============ DEEP CONVERSION HELPER ============
  /// Recursively converts any Map or List from Firebase to proper Dart types
  dynamic _convertToProperType(dynamic value) {
    if (value is Map) {
      // Convert Map<Object?, Object?> to Map<String, dynamic>
      Map<String, dynamic> result = {};
      value.forEach((key, val) {
        if (key != null) {
          result[key.toString()] = _convertToProperType(val);
        }
      });
      return result;
    } else if (value is List) {
      // Convert List elements recursively
      return value.map((item) => _convertToProperType(item)).toList();
    } else {
      // Return primitive values as-is
      return value;
    }
  }

  Future<void> _loadCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseEvent userEvent = await _usersRef.child(user.uid).once();
      if (userEvent.snapshot.value != null) {
        setState(() {
          _currentUser = Map<String, dynamic>.from(
            _convertToProperType(userEvent.snapshot.value) as Map,
          );
        });
      }
    }
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DatabaseEvent event = await _billsRef.once();
      if (event.snapshot.value != null) {
        final data = event.snapshot.value;

        if (data is Map) {
          List<BillModel> bills = [];

          data.forEach((key, value) {
            if (key != null && value != null) {
              try {
                // Deep convert the entire bill data structure
                Map<String, dynamic> billData = Map<String, dynamic>.from(
                  _convertToProperType(value) as Map,
                );

                // Ensure ID is set
                billData['id'] = key.toString();

                // Debug: Print converted data
                debugPrint('Converted bill data for $key: ${billData.keys}');

                BillModel bill = BillModel.fromMap(key.toString(), billData);

                // Filter by team if teamId is provided
                if (widget.teamId == null || bill.teamId == widget.teamId) {
                  bills.add(bill);
                }
              } catch (e, stackTrace) {
                debugPrint('Error parsing bill $key: $e');
                debugPrint('Stack trace: $stackTrace');
              }
            }
          });

          // Sort by date (newest first)
          bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          setState(() {
            _bills = bills;
            _applyFilters();
            _calculateStats();
            _isLoading = false;
          });
        } else {
          setState(() {
            _bills = [];
            _filteredBills = [];
            _calculateStats();
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _bills = [];
          _filteredBills = [];
          _calculateStats();
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to load bills: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to load bills: $e';
        _isLoading = false;
      });
    }
  }

  void _calculateStats() {
    _totalBills = _bills.length;
    _totalRevenue = 0.0;
    _totalPaid = 0.0;
    _totalPending = 0.0;
    _overdueCount = 0;

    DateTime now = DateTime.now();

    for (var bill in _bills) {
      _totalRevenue += bill.grandTotal;
      _totalPaid += bill.amountPaid;

      if (bill.paymentStatus != 'Paid') {
        _totalPending += bill.balanceDue;
      }

      // Check for overdue (unpaid bills past due date)
      if (bill.paymentStatus != 'Paid' &&
          bill.paymentStatus != 'Overdue' &&
          bill.dueDate.isBefore(now)) {
        _overdueCount++;
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredBills = _bills.where((bill) {
        // Apply status filter
        if (_selectedFilter != 'All') {
          // Handle overdue filter specially
          if (_selectedFilter == 'Overdue') {
            if (!bill.isOverdue) return false;
          } else if (bill.paymentStatus != _selectedFilter) {
            return false;
          }
        }

        // Apply search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          bool matchesSearch = bill.billNumber.toLowerCase().contains(query) ||
              bill.customerName.toLowerCase().contains(query) ||
              (bill.customerEmail.toLowerCase().contains(query)) ||
              (bill.customerPhone.toLowerCase().contains(query));

          if (!matchesSearch) {
            return false;
          }
        }

        // Apply date range filter
        if (_selectedDateRange != null) {
          if (bill.billDate.isBefore(_selectedDateRange!.start) ||
              bill.billDate.isAfter(_selectedDateRange!.end)) {
            return false;
          }
        }

        return true;
      }).toList();

      // Sort by date (newest first)
      _filteredBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  void _showDateRangePicker() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _deepPurple,
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
        _selectedDateRange = picked;
        _applyFilters();
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
      _applyFilters();
    });
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

  Future<void> _deleteBill(BillModel bill) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
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
                Icons.delete_forever_rounded,
                color: _crimsonRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Bill',
              style: TextStyle(
                color: _pearlWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this bill?',
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Bill #: ',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        bill.billNumber,
                        style: const TextStyle(
                          color: _pearlWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Customer: ',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bill.customerName,
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Amount: ',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '\$${bill.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _emeraldGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: _crimsonRed.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _pearlWhite.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                await _billsRef.child(bill.id).remove();
                await _loadBills(); // Reload bills

                if (mounted) {
                  _showSuccessSnackBar('✅ Bill deleted successfully');
                }
              } catch (e) {
                if (mounted) {
                  _showErrorSnackBar('Failed to delete bill: $e');
                  setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _crimsonRed,
              foregroundColor: _pearlWhite,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
                  'Bills',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.teamName != null)
                  Text(
                    widget.teamName!,
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
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: _pearlWhite,
                size: 20,
              ),
            ),
            onPressed: _loadBills,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _deepPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: _pearlWhite,
                size: 20,
              ),
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateBillScreen(
                    teamId: widget.teamId,
                    teamName: widget.teamName,
                  ),
                ),
              );
              if (result == true) {
                _loadBills();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _charcoalBlue,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildStatCard(
                    'Total Bills',
                    _totalBills.toString(),
                    Icons.receipt_rounded,
                    _deepPurple,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Revenue',
                    '\$${_totalRevenue.toStringAsFixed(2)}',
                    Icons.attach_money_rounded,
                    _emeraldGreen,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Paid',
                    '\$${_totalPaid.toStringAsFixed(2)}',
                    Icons.check_circle_rounded,
                    _skyBlue,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Pending',
                    '\$${_totalPending.toStringAsFixed(2)}',
                    Icons.pending_rounded,
                    _amberGlow,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Overdue',
                    _overdueCount.toString(),
                    Icons.warning_rounded,
                    _crimsonRed,
                  ),
                ],
              ),
            ),
          ),

          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _charcoalBlue,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: _slateGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: TextField(
                    style: const TextStyle(color: _pearlWhite),
                    decoration: InputDecoration(
                      hintText: 'Search by bill #, customer...',
                      hintStyle: TextStyle(
                        color: _pearlWhite.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _pearlWhite.withOpacity(0.7),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: _pearlWhite.withOpacity(0.7),
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
                        vertical: 12,
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

                const SizedBox(height: 12),

                // Filter Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Status Filter Chips
                      ..._filterOptions.map((filter) {
                        bool isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = filter;
                                _applyFilters();
                              });
                            },
                            backgroundColor: _slateGray,
                            selectedColor: _getStatusColor(filter).withOpacity(0.2),
                            checkmarkColor: _getStatusColor(filter),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getStatusColor(filter)
                                  : _pearlWhite.withOpacity(0.7),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? _getStatusColor(filter)
                                    : Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Date Filter Button
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedDateRange != null
                                ? _deepPurple
                                : Colors.white.withOpacity(0.1),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: MaterialButton(
                          onPressed: _showDateRangePicker,
                          elevation: 0,
                          color: _selectedDateRange != null
                              ? _deepPurple.withOpacity(0.1)
                              : _slateGray,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: _selectedDateRange != null
                                    ? _deepPurple
                                    : _pearlWhite.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDateRange != null
                                    ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                                    : 'Date Range',
                                style: TextStyle(
                                  color: _selectedDateRange != null
                                      ? _deepPurple
                                      : _pearlWhite.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              if (_selectedDateRange != null) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _clearDateRange,
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: _deepPurple,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bills List
          Expanded(
            child: _isLoading
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
                    'Loading bills...',
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : _errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _crimsonRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: _crimsonRed,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Bills',
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadBills,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deepPurple,
                      foregroundColor: _pearlWhite,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            )
                : _filteredBills.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _slateGray,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_outlined,
                      size: 48,
                      color: _pearlWhite.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Bills Found',
                    style: TextStyle(
                      color: _pearlWhite.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _searchQuery.isNotEmpty ||
                          _selectedFilter != 'All' ||
                          _selectedDateRange != null
                          ? 'Try adjusting your filters'
                          : 'Create your first bill to get started',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty ||
                      _selectedFilter != 'All' ||
                      _selectedDateRange != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedFilter = 'All';
                          _selectedDateRange = null;
                          _applyFilters();
                        });
                      },
                      icon: const Icon(Icons.clear_all_rounded),
                      label: const Text('Clear Filters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _pearlWhite,
                        side: BorderSide(
                          color: _pearlWhite.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateBillScreen(
                              teamId: widget.teamId,
                              teamName: widget.teamName,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadBills();
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _deepPurple,
                        foregroundColor: _pearlWhite,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
                : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredBills.length,
                  itemBuilder: (context, index) {
                    final bill = _filteredBills[index];
                    return _buildBillCard(bill, index);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _pearlWhite.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(BillModel bill, int index) {
    // Calculate overdue status
    bool isOverdue = bill.isOverdue;

    String displayStatus = isOverdue ? 'Overdue' : bill.paymentStatus;
    Color statusColor = isOverdue ? _crimsonRed : _getStatusColor(bill.paymentStatus);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BillDetailsScreen(
              bill: bill,
              teamId: widget.teamId,
              teamName: widget.teamName,
            ),
          ),
        );
        if (result == true) {
          _loadBills(); // Reload if bill was updated
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
            color: isOverdue
                ? _crimsonRed.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Row
            Row(
              children: [
                // Bill Number and Status
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getStatusIcon(displayStatus),
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.billNumber,
                              style: const TextStyle(
                                color: _pearlWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: _pearlWhite.withOpacity(0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}',
                                  style: TextStyle(
                                    color: _pearlWhite.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                if (bill.quotationNumber != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: _pearlWhite.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.description_rounded,
                                    size: 12,
                                    color: _pearlWhite.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'QT-${bill.quotationNumber!.substring(bill.quotationNumber!.length - 6)}',
                                    style: TextStyle(
                                      color: _pearlWhite.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu Button
                // PopupMenuButton<String>(
                //   icon: Icon(
                //     Icons.more_vert_rounded,
                //     color: _pearlWhite.withOpacity(0.7),
                //   ),
                //   color: _charcoalBlue,
                //   shape: RoundedRectangleBorder(
                //     borderRadius: BorderRadius.circular(16),
                //   ),
                //   onSelected: (value) {
                //     if (value == 'delete') {
                //       _deleteBill(bill);
                //     }
                //   },
                //   itemBuilder: (context) => [
                //     PopupMenuItem(
                //       value: 'delete',
                //       child: Row(
                //         children: [
                //           Container(
                //             padding: const EdgeInsets.all(4),
                //             decoration: BoxDecoration(
                //               color: _crimsonRed.withOpacity(0.1),
                //               borderRadius: BorderRadius.circular(8),
                //             ),
                //             child: const Icon(
                //               Icons.delete_outline_rounded,
                //               color: _crimsonRed,
                //               size: 18,
                //             ),
                //           ),
                //           const SizedBox(width: 12),
                //           const Text(
                //             'Delete',
                //             style: TextStyle(
                //               color: _crimsonRed,
                //               fontSize: 14,
                //               fontWeight: FontWeight.w500,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ],
                // ),
                // In _buildBillCard method, replace the PopupMenuButton with this:

                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: _pearlWhite.withOpacity(0.7),
                  ),
                  color: _charcoalBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      _deleteBill(bill);
                    } else if (value == 'print') {
                      try {
                        setState(() => _isLoading = true);
                        await PdfService.printBill(context, bill);
                      } catch (e) {
                        _showErrorSnackBar('Failed to print bill: $e');
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    } else if (value == 'save') {
                      try {
                        setState(() => _isLoading = true);
                        await PdfService.saveBillPdf(context, bill);
                      } catch (e) {
                        _showErrorSnackBar('Failed to save bill: $e');
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    } else if (value == 'share') {
                      try {
                        setState(() => _isLoading = true);
                        await PdfService.shareBillPdf(context, bill);
                      } catch (e) {
                        _showErrorSnackBar('Failed to share bill: $e');
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _skyBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.print_rounded,
                              color: _skyBlue,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Print',
                            style: TextStyle(
                              color: _pearlWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _emeraldGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.save_rounded,
                              color: _emeraldGreen,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Save PDF',
                            style: TextStyle(
                              color: _pearlWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.share_rounded,
                              color: _deepPurple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Share',
                            style: TextStyle(
                              color: _pearlWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'divider',
                      enabled: false,
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _crimsonRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: _crimsonRed,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Delete',
                            style: TextStyle(
                              color: _crimsonRed,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Customer Info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                      bill.customerName.isNotEmpty ? bill.customerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.customerName,
                        style: const TextStyle(
                          color: _pearlWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bill.customerEmail.isNotEmpty)
                        Text(
                          bill.customerEmail,
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount and Due Date
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${bill.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _emeraldGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 12,
                            color: isOverdue
                                ? _crimsonRed
                                : _pearlWhite.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}',
                            style: TextStyle(
                              color: isOverdue
                                  ? _crimsonRed
                                  : _pearlWhite.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Payment Progress
            if (bill.paymentStatus != 'Paid' && bill.amountPaid > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Paid: \$${bill.amountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _emeraldGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Balance: \$${bill.balanceDue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _crimsonRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: bill.amountPaid / bill.grandTotal,
                            backgroundColor: _slateGray,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _emeraldGreen,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Team info if available
            if (bill.teamName != null && widget.teamId == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _slateGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.group_rounded,
                      size: 14,
                      color: _deepPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      bill.teamName!,
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}