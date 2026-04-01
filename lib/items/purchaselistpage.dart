import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../lanprovider.dart';
import 'itemPurchasePage.dart';

// ─────────────────────────────────────────────
//  DESIGN TOKENS (Matching ItemsListPage)
// ─────────────────────────────────────────────
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
}

class PurchaseListPage extends StatefulWidget {
  @override
  State<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends State<PurchaseListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _filteredPurchases = [];
  bool _isLoading = true;
  Map<String, String> _vendorNames = {};
  Uint8List? _pdfBytes;
  String? _savedPdfPath;

  @override
  void initState() {
    super.initState();
    fetchPurchases();
    _fetchVendorNames();
    _searchController.addListener(_searchPurchases);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchVendorNames() async {
    final snapshot = await FirebaseDatabase.instance.ref('vendors').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final Map<String, String> map = {};
      data.forEach((k, v) {
        if (v is Map && v.containsKey('name')) map[k] = v['name'].toString();
      });
      setState(() => _vendorNames = map);
    }
  }

  void fetchPurchases() {
    setState(() => _isLoading = true);
    FirebaseDatabase.instance.ref('purchases').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> purchases = [];

        data.forEach((key, value) {
          final purchase = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          purchase['key'] = key;

          // Handle items if they exist
          if (purchase['items'] != null) {
            final items = List<Map<String, dynamic>>.from(
                (purchase['items'] as List<dynamic>).map(
                        (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)
                )
            );
            purchase['items'] = items;
          }

          purchases.add(purchase);
        });

        // Sort by timestamp (newest first)
        purchases.sort((a, b) {
          final aTime = a['timestamp']?.toString() ?? '';
          final bTime = b['timestamp']?.toString() ?? '';
          return bTime.compareTo(aTime);
        });

        setState(() {
          _purchases = purchases;
          _filteredPurchases = purchases;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }, onError: (error) {
      setState(() => _isLoading = false);
      _snack('Error fetching purchases: $error', error: true);
    });
  }

  void _searchPurchases() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPurchases = _purchases.where((purchase) {
        final vendorName = purchase['vendorName']?.toString().toLowerCase() ?? '';
        final items = purchase['items'] as List<Map<String, dynamic>>? ?? [];

        // Search in vendor name or any item name
        return vendorName.contains(query) ||
            items.any((item) =>
            item['itemName']?.toString().toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void editPurchase(Map<String, dynamic> purchase) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemPurchasePage(
          initialVendorId: purchase['vendorId'],
          initialVendorName: purchase['vendorName'],
          initialItems: List<Map<String, dynamic>>.from(purchase['items']),
          isEditMode: true,
          purchaseKey: purchase['key'],
        ),
      ),
    ).then((_) {
      // Refresh data when returning from edit
      fetchPurchases();
    });
  }

  void deletePurchase(String key) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: languageProvider.isEnglish ? 'Delete Purchase' : 'خریداری حذف کریں',
        message: languageProvider.isEnglish
            ? 'Are you sure you want to delete this purchase?'
            : 'کیا آپ واقعی اس خریداری کو حذف کرنا چاہتے ہیں؟',
        confirmLabel: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
        confirmColor: _T.red,
        onConfirm: () async {
          try {
            await FirebaseDatabase.instance.ref('purchases/$key').remove();
            _snack(languageProvider.isEnglish
                ? 'Purchase deleted successfully'
                : 'خریداری کامیابی سے حذف ہو گئی');
          } catch (error) {
            _snack(languageProvider.isEnglish
                ? 'Failed to delete purchase: $error'
                : 'خریداری کو حذف کرنے میں ناکامی: $error', error: true);
          }
        },
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? _T.red : _T.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── PDF Generation ───────────────────────────────
  Future<void> _createPDFAndSave() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 80, height: 80),
              pw.Text('Purchase List',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Vendor', 'Total Items', 'Grand Total (PKR)'],
            data: _filteredPurchases.map((purchase) {
              final timestamp = purchase['timestamp']?.toString();
              final date = timestamp != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(timestamp))
                  : 'N/A';
              final itemsCount = (purchase['items'] as List?)?.length ?? 0;
              return [
                date,
                purchase['vendorName']?.toString() ?? 'Unknown',
                itemsCount.toString(),
                purchase['grandTotal']?.toStringAsFixed(2) ?? '0.00',
              ];
            }).toList(),
          ),
        ],
      ));

      final bytes = await pdf.save();
      _pdfBytes = bytes;

      if (kIsWeb) {
        _snack('PDF ready — tap share to download');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/purchase_list.pdf');
        await file.writeAsBytes(bytes);
        setState(() => _savedPdfPath = file.path);
        _snack('PDF saved');
      }
    } catch (e) {
      _snack('PDF error: $e', error: true);
    }
  }

  Future<void> _sharePDF() async {
    if (kIsWeb) {
      if (_pdfBytes == null) {
        _snack('Generate PDF first', error: true);
        return;
      }
      await Printing.sharePdf(bytes: _pdfBytes!, filename: 'purchase_list.pdf');
    } else {
      if (_savedPdfPath == null) {
        _snack('Generate PDF first', error: true);
        return;
      }
      await Share.shareXFiles([XFile(_savedPdfPath!)], text: 'Purchase List PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(languageProvider),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSearchBar(languageProvider),
            const SizedBox(height: 20),
            Expanded(
              child: _filteredPurchases.isEmpty
                  ? _EmptyState()
                  : ListView.builder(
                itemCount: _filteredPurchases.length,
                itemBuilder: (context, index) {
                  final purchase = _filteredPurchases[index];
                  return _PurchaseCard(
                    purchase: purchase,
                    dateFormat: dateFormat,
                    onEdit: () => editPurchase(purchase),
                    onDelete: () => deletePurchase(purchase['key']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(languageProvider),
    );
  }

  PreferredSizeWidget _buildAppBar(LanguageProvider lang) {
    return AppBar(
      backgroundColor: _T.surface,
      elevation: 0,
      titleSpacing: 20,
      title: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.shopping_cart_outlined, color: _T.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          lang.isEnglish ? 'Purchase List' : 'خریداری کی فہرست',
          style: const TextStyle(
            color: _T.textPri,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ]),
      actions: [
        _AppBarBtn(
          icon: Icons.picture_as_pdf,
          onTap: _createPDFAndSave,
        ),
        _AppBarBtn(
          icon: Icons.share,
          onTap: _sharePDF,
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
    );
  }

  Widget _buildSearchBar(LanguageProvider lang) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _T.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.border),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: _T.textPri, fontSize: 13),
        decoration: InputDecoration(
          hintText: lang.isEnglish
              ? 'Search by item or vendor...'
              : 'آئٹم یا وینڈر کے ذریعہ تلاش کریں...',
          hintStyle: const TextStyle(color: _T.textTer, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _T.textTer, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildFAB(LanguageProvider lang) {
    return FloatingActionButton.extended(
      backgroundColor: _T.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        lang.isEnglish ? 'New Purchase' : 'نئی خریداری',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ItemPurchasePage()),
        ).then((_) {
          fetchPurchases();
        });
      },
    );
  }
}

// ─────────────────────────────────────────────
//  PURCHASE CARD
// ─────────────────────────────────────────────
class _PurchaseCard extends StatelessWidget {
  final Map<String, dynamic> purchase;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PurchaseCard({
    required this.purchase,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final items = purchase['items'] as List<Map<String, dynamic>>? ?? [];
    final timestamp = purchase['timestamp']?.toString();
    final date = timestamp != null
        ? dateFormat.format(DateTime.parse(timestamp))
        : 'N/A';
    final grandTotal = purchase['grandTotal']?.toStringAsFixed(2) ?? '0.00';
    final isExpanded = false; // We'll use ExpansionTile which manages its own state

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.receipt, color: _T.accent, size: 20),
        ),
        title: Text(
          purchase['vendorName'] ?? 'Unknown Vendor',
          style: const TextStyle(
            color: _T.textPri,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: PKR $grandTotal',
              style: const TextStyle(color: _T.gold, fontSize: 12),
            ),
            Text(
              'Items: ${items.length}',
              style: const TextStyle(color: _T.textSec, fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              date,
              style: const TextStyle(color: _T.textTer, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBtn(icon: Icons.edit_outlined, color: _T.blue, onTap: onEdit, size: 28),
                const SizedBox(width: 4),
                _IconBtn(icon: Icons.delete_outline, color: _T.red, onTap: onDelete, size: 28),
              ],
            ),
          ],
        ),
        children: [
          const Divider(color: _T.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Items header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('Item', style: TextStyle(color: _T.textTer, fontSize: 11))),
                      Expanded(child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: _T.textTer, fontSize: 11))),
                      Expanded(child: Text('Price', textAlign: TextAlign.center, style: TextStyle(color: _T.textTer, fontSize: 11))),
                      Expanded(child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: _T.textTer, fontSize: 11))),
                    ],
                  ),
                ),
                ...items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final qty = item['quantity']?.toDouble() ?? 0;
                  final price = item['purchasePrice']?.toDouble() ?? 0;
                  final total = qty * price;
                  final isLast = entry.key == items.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item['itemName'] ?? 'Unknown',
                                style: const TextStyle(color: _T.textPri, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                qty.toStringAsFixed(2),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _T.textSec, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'PKR ${price.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _T.textSec, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'PKR ${total.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: _T.textPri, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) const Divider(color: _T.border, height: 1),
                    ],
                  );
                }).toList(),
                const Divider(color: _T.border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      const Spacer(),
                      const Text('Grand Total: ', style: TextStyle(color: _T.textSec, fontSize: 13)),
                      Text(
                        'PKR $grandTotal',
                        style: const TextStyle(color: _T.gold, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SUPPORTING WIDGETS
// ─────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: _T.textSec, size: 20),
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  const _IconBtn({required this.icon, required this.color, required this.onTap, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _T.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _T.border),
            ),
            child: const Icon(Icons.shopping_cart_outlined, color: _T.textTer, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No purchases found',
            style: TextStyle(color: _T.textSec, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the + button to create a new purchase',
            style: TextStyle(color: _T.textTer, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _T.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        title,
        style: const TextStyle(color: _T.textPri, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: Text(
        message,
        style: const TextStyle(color: _T.textSec, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _T.textSec)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}