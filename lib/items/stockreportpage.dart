import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// Design tokens matching ItemsListPage
class _T {
  static const bg         = Color(0xFF0F0F14);
  static const surface    = Color(0xFF1A1A24);
  static const surfaceAlt = Color(0xFF22222F);
  static const border     = Color(0xFF2E2E3E);
  static const accent     = Color(0xFFFF6B35);
  static const accentSoft = Color(0xFFFF8F5E);
  static const gold       = Color(0xFFFFB74D);
  static const textPri    = Color(0xFFF0EFF4);
  static const textSec    = Color(0xFF8B8A99);
  static const textTer    = Color(0xFF4A4A5C);
  static const green      = Color(0xFF26D07C);
  static const red        = Color(0xFFFF4D6D);
  static const blue       = Color(0xFF4D9EFF);
  static const orange     = Color(0xFFFF8C42);
  static const yellow     = Color(0xFFFFB74D);
}

class StockReportPage extends StatefulWidget {
  @override
  _StockReportPageState createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _adjustments = [];
  List<Map<String, dynamic>> _filteredAdjustments = [];

  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchAdjustments();
  }

  void _fetchAdjustments() async {
    final snapshot = await _database.child('qtyAdjustments').get();
    if (snapshot.exists) {
      final Map<dynamic, dynamic> adjustmentsData = snapshot.value as Map;
      final List<Map<String, dynamic>> adjustmentsList = [];

      adjustmentsData.forEach((itemKey, adjustments) {
        adjustments.forEach((adjustmentKey, adjustment) {
          adjustmentsList.add({
            'itemName': adjustment['itemName'],
            'oldQty': adjustment['oldQty'],
            'newQty': adjustment['newQty'],
            'date': adjustment['date'],
            'adjustedBy': adjustment['adjustedBy'],
          });
        });
      });

      // Sort by date (newest first)
      adjustmentsList.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '');
        final dateB = DateTime.tryParse(b['date'] ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _adjustments = adjustmentsList;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAdjustments = _adjustments.where((adjustment) {
        final nameMatch = adjustment['itemName']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());

        final dateMatch = _selectedDateRange == null
            ? true
            : _isWithinRange(adjustment['date']);

        return nameMatch && dateMatch;
      }).toList();
    });
  }

  bool _isWithinRange(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return date.isAfter(_selectedDateRange!.start.subtract(Duration(days: 1))) &&
          date.isBefore(_selectedDateRange!.end.add(Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  void _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _T.accent,
              onPrimary: Colors.white,
              surface: _T.surface,
              onSurface: _T.textPri,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedDateRange = null;
      _applyFilters();
    });
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.surface,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _T.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: _T.textSec, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _T.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_rounded, color: _T.accent, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Stock Adjustments',
              style: TextStyle(
                color: _T.textPri,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _T.border),
        ),
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _T.surface,
              border: Border(bottom: BorderSide(color: _T.border)),
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: _T.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _T.border),
                  ),
                  child: TextField(
                    style: const TextStyle(color: _T.textPri, fontSize: 14),
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by item name...',
                      hintStyle: TextStyle(color: _T.textTer, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: _T.textTer, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.close, color: _T.textTer, size: 16),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Date Range Row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _T.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _T.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range, color: _T.accent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDateRange == null
                                      ? 'All dates'
                                      : '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                                  style: TextStyle(
                                    color: _selectedDateRange == null ? _T.textTer : _T.textPri,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedDateRange != null || _searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear_all, color: _T.accent, size: 20),
                        onPressed: _clearFilters,
                        tooltip: 'Clear filters',
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Row
          if (_filteredAdjustments.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _T.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_filteredAdjustments.length} adjustments',
                      style: TextStyle(
                        color: _T.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Adjustments List
          Expanded(
            child: _filteredAdjustments.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _T.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _T.border),
                    ),
                    child: Icon(Icons.history_rounded, color: _T.textTer, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No adjustments found',
                    style: TextStyle(color: _T.textSec, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _searchQuery.isNotEmpty || _selectedDateRange != null
                        ? 'Try changing your filters'
                        : 'No stock adjustments recorded',
                    style: TextStyle(color: _T.textTer, fontSize: 12),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredAdjustments.length,
              itemBuilder: (context, index) {
                final adjustment = _filteredAdjustments[index];
                final oldQty = adjustment['oldQty'] as num;
                final newQty = adjustment['newQty'] as num;
                final isIncrease = newQty > oldQty;
                final diff = (newQty - oldQty).abs();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _T.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _T.border),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showAdjustmentDetails(adjustment),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isIncrease
                                        ? _T.green.withOpacity(0.12)
                                        : _T.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isIncrease
                                        ? Icons.add_rounded
                                        : Icons.remove_rounded,
                                    color: isIncrease ? _T.green : _T.red,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        adjustment['itemName'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: _T.textPri,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded,
                                              color: _T.textTer, size: 11),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(adjustment['date']),
                                            style: TextStyle(
                                              color: _T.textSec,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.person_outline,
                                              color: _T.textTer, size: 11),
                                          const SizedBox(width: 4),
                                          Text(
                                            adjustment['adjustedBy'] ?? 'System',
                                            style: TextStyle(
                                              color: _T.textSec,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Change indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isIncrease
                                        ? _T.green.withOpacity(0.12)
                                        : _T.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isIncrease
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                        color: isIncrease ? _T.green : _T.red,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        diff.toStringAsFixed(0),
                                        style: TextStyle(
                                          color: isIncrease ? _T.green : _T.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(color: _T.border, height: 1),
                            const SizedBox(height: 12),

                            // Quantity Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuantityCard(
                                    'Old Quantity',
                                    oldQty.toStringAsFixed(0),
                                    _T.textSec,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    color: _T.textTer,
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: _buildQuantityCard(
                                    'New Quantity',
                                    newQty.toStringAsFixed(0),
                                    isIncrease ? _T.green : _T.red,
                                    isBold: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityCard(String label, String value, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _T.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: _T.textTer,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          Text(
            'pcs',
            style: TextStyle(
              color: _T.textTer,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustmentDetails(Map<String, dynamic> adjustment) {
    final oldQty = adjustment['oldQty'] as num;
    final newQty = adjustment['newQty'] as num;
    final isIncrease = newQty > oldQty;
    final diff = (newQty - oldQty).abs();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _T.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _T.border),
        ),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isIncrease ? _T.green.withOpacity(0.12) : _T.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncrease ? Icons.add_rounded : Icons.remove_rounded,
                  color: isIncrease ? _T.green : _T.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                adjustment['itemName'] ?? 'Unknown',
                style: const TextStyle(
                  color: _T.textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isIncrease ? _T.green.withOpacity(0.12) : _T.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isIncrease ? 'Increased by $diff pcs' : 'Decreased by $diff pcs',
                  style: TextStyle(
                    color: isIncrease ? _T.green : _T.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailCard('Old Quantity', '${oldQty.toStringAsFixed(0)} pcs', _T.textSec),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDetailCard('New Quantity', '${newQty.toStringAsFixed(0)} pcs', isIncrease ? _T.green : _T.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailCard('Date', _formatDate(adjustment['date']), _T.textPri),
              const SizedBox(height: 8),
              _buildDetailCard('Adjusted By', adjustment['adjustedBy'] ?? 'System', _T.textSec),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: _T.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: _T.textTer,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}