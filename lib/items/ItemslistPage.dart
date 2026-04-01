import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:fnsolutions/items/purchaselistpage.dart';
import 'package:fnsolutions/items/stockreportpage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import '../lanprovider.dart';
import '../vendors/viewvendors.dart';
import 'AddItems.dart';
import 'editphysicalqty.dart';

// ─────────────────────────────────────────────
//  DESIGN TOKENS
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
  static const bomBadge   = Color(0xFF1E3A5F);
  static const bomText    = Color(0xFF4D9EFF);
}

class ItemsListPage extends StatefulWidget {
  @override
  _ItemsListPageState createState() => _ItemsListPageState();
}

class _ItemsListPageState extends State<ItemsListPage>
    with TickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _items          = [];
  List<Map<String, dynamic>> _filteredItems  = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedItem;
  String? _savedPdfPath;
  Uint8List? _pdfBytes;
  Map<String, String> customerIdNameMap = {};

  // Return tracking
  Map<String, List<Map<String, dynamic>>> _itemReturns = {};
  bool _showReturnHistory = false;

  late AnimationController _detailAnim;
  late Animation<double>    _detailFade;
  late Animation<Offset>    _detailSlide;

  // ── lifecycle ────────────────────────────────
  @override
  void initState() {
    super.initState();
    _detailAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _detailFade = CurvedAnimation(parent: _detailAnim, curve: Curves.easeOut);
    _detailSlide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _detailAnim, curve: Curves.easeOutCubic));

    fetchItems();
    _fetchCustomerNames();
    _fetchReturnHistory();
    _searchController.addListener(_searchItems);
  }

  @override
  void dispose() {
    _detailAnim.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── data ─────────────────────────────────────
  Future<void> _fetchCustomerNames() async {
    final snapshot = await FirebaseDatabase.instance.ref('customers').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final Map<String, String> map = {};
      data.forEach((k, v) {
        if (v is Map && v.containsKey('name')) map[k] = v['name'].toString();
      });
      setState(() => customerIdNameMap = map);
    }
  }

  Future<void> _fetchReturnHistory() async {
    final returnsSnapshot = await _database.child('returns').get();
    if (returnsSnapshot.exists) {
      final returnsData = Map<String, dynamic>.from(returnsSnapshot.value as Map);
      final Map<String, List<Map<String, dynamic>>> returnsMap = {};

      returnsData.forEach((returnId, returnValue) {
        if (returnValue is Map) {
          final items = returnValue['items'] as List?;
          if (items != null) {
            for (var item in items) {
              final itemName = item['itemName']?.toString();
              if (itemName != null) {
                returnsMap.putIfAbsent(itemName, () => []);
                returnsMap[itemName]!.add({
                  'returnId': returnId,
                  'returnDate': returnValue['returnDate'],
                  'quantity': item['returnedQuantity'],
                  'reason': item['reason'],
                  'billNumber': returnValue['billNumber'],
                  'customerName': returnValue['customerName'],
                  'returnType': returnValue['returnType'],
                  'grandTotal': returnValue['grandTotal'],
                });
              }
            }
          }
        }
      });

      setState(() => _itemReturns = returnsMap);
    }
  }

  Future<void> fetchItems() async {
    _database.child('items').onValue.listen((event) {
      final Map? data = event.snapshot.value as Map?;
      if (data != null) {
        final list = data.entries.map<Map<String, dynamic>>((e) => {
          'key': e.key,
          ...Map<String, dynamic>.from(e.value as Map),
        }).toList();
        setState(() {
          _items         = list;
          _filteredItems = list;
        });
      }
    });
  }

  void _searchItems() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) =>
          (item['itemName']?.toString().toLowerCase() ?? '').contains(q)).toList();
    });
  }

  void _selectItem(Map<String, dynamic> item) {
    setState(() => _selectedItem = item);
    _detailAnim.forward(from: 0);
  }

  double _effectiveCost(Map<String, dynamic> item) {
    if (item['isBOM'] == true && item['components'] != null) {
      double total = 0;
      for (var c in item['components']) {
        total += (double.tryParse(c['quantity'].toString()) ?? 0) *
            (double.tryParse(c['price'].toString()) ?? 0);
      }
      return total;
    }
    return double.tryParse(item['costPrice']?.toString() ?? '0') ?? 0;
  }

  double _profitMargin(Map<String, dynamic> item) {
    final cost  = _effectiveCost(item);
    final sale  = double.tryParse(item['salePrice']?.toString() ?? '0') ?? 0;
    if (cost <= 0) return 0;
    return ((sale - cost) / cost) * 100;
  }

  double _totalReturnedQuantity(String itemName) {
    final returns = _itemReturns[itemName];
    if (returns == null) return 0;
    return returns.fold(0.0, (sum, r) => sum + (r['quantity'] as num).toDouble());
  }

  double _netQuantity(Map<String, dynamic> item) {
    final originalQty = (item['qtyOnHand'] as num?)?.toDouble() ?? 0;
    final returnedQty = _totalReturnedQuantity(item['itemName']?.toString() ?? '');
    return originalQty + returnedQty;
  }


  // ── actions ───────────────────────────────────
  void _confirmDelete(String key) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete Item',
        message: 'This action cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: _T.red,
        onConfirm: () => deleteItem(key),
      ),
    );
  }

  void deleteItem(String key) {
    _database.child('items/$key').remove().then((_) {
      if (_selectedItem?['key'] == key) setState(() => _selectedItem = null);
      _snack('Item deleted successfully');
    }).catchError((e) => _snack('Failed to delete: $e', error: true));
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? _T.red : _T.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _updateItem(Map<String, dynamic> item) {
    List<Map<String, dynamic>>? components;
    if (item['components'] != null && item['components'] is List) {
      components = (item['components'] as List).map((c) =>
      c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{}).toList();
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RegisterItemPage(itemData: {
        'key': item['key'],
        'itemName': item['itemName'],
        'image': item['image'],
        'unit': item['unit'] ?? '',
        'costPrice': item['costPrice'] ?? 0.0,
        'salePrice': item['salePrice'] ?? 0.0,
        'qtyOnHand': item['qtyOnHand'] ?? 0,
        'vendor': item['vendor'] ?? '',
        'category': item['category'] ?? '',
        'customerBasePrices': item['customerBasePrices'] is Map
            ? Map<String, dynamic>.from(item['customerBasePrices']) : null,
        'isBOM': item['isBOM'] ?? false,
        'components': components,
      }),
    )).then((_) {
      fetchItems();
      _fetchReturnHistory();
    });
  }

  // ── PDF ───────────────────────────────────────
  Future<void> _createPDFAndSave() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      final pdf  = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 80, height: 80),
              pw.Text('Items List', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Item Name', 'Qty', 'Returned', 'Net Qty', 'Sale Price', 'Unit'],
            data: _filteredItems.map((item) {
              final itemName = item['itemName'].toString();
              final returned = _totalReturnedQuantity(itemName);
              final netQty = _netQuantity(item);
              return [
                itemName,
                item['qtyOnHand'].toString(),
                returned.toStringAsFixed(1),
                netQty.toStringAsFixed(1),
                item['salePrice'].toString(),
                item['unit']?.toString() ?? '',
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
        final dir  = await getTemporaryDirectory();
        final file = File('${dir.path}/items_list.pdf');
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
      if (_pdfBytes == null) { _snack('Generate PDF first', error: true); return; }
      await Printing.sharePdf(bytes: _pdfBytes!, filename: 'items_list.pdf');
    } else {
      if (_savedPdfPath == null) { _snack('Generate PDF first', error: true); return; }
      await Share.shareXFiles([XFile(_savedPdfPath!)], text: 'Items List PDF');
    }
  }

  // ── BUILD ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // ── LEFT: item list ──
          SizedBox(
            width: 300,
            child: _ItemListPanel(
              items:            _filteredItems,
              selectedKey:      _selectedItem?['key'],
              searchController: _searchController,
              onTap:            _selectItem,
              onDelete:         _confirmDelete,
              onEdit:           (item) => Navigator.push(context, MaterialPageRoute(
                builder: (_) => EditQtyPage(itemData: item),
              )),
              itemReturns:      _itemReturns,
            ),
          ),

          // ── RIGHT: detail ──
          Expanded(
            child: _selectedItem == null
                ? _EmptyState()
                : FadeTransition(
              opacity: _detailFade,
              child: SlideTransition(
                position: _detailSlide,
                child: _ItemDetailPanel(
                  item:          _selectedItem!,
                  effectiveCost: _effectiveCost(_selectedItem!),
                  profitMargin:  _profitMargin(_selectedItem!),
                  customerNames: customerIdNameMap,
                  onEdit:        () => _updateItem(_selectedItem!),
                  onDelete:      () => _confirmDelete(_selectedItem!['key']),
                  onShowImage:   () => _showImageDialog(_selectedItem!['image']),
                  itemReturns:   _itemReturns[_selectedItem!['itemName']?.toString()] ?? [],
                  onRefresh:     _fetchReturnHistory,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
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

      backgroundColor: _T.surface,
      elevation: 0,
      titleSpacing: 20,
      title: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: _T.accent, size: 18),
        ),
        const SizedBox(width: 12),
        const Text('Inventory',
            style: TextStyle(color: _T.textPri, fontSize: 17, fontWeight: FontWeight.w600,
                letterSpacing: 0.2)),
      ]),
      actions: [
        _AppBarBtn(icon: Icons.list, onTap: (){
          Navigator.push(context, MaterialPageRoute(builder: (context)=>PurchaseListPage()));
        }),
        _AppBarBtn(icon: Icons.add, onTap: (){
          Navigator.push(context, MaterialPageRoute(builder: (context)=>ViewVendorsPage()));
        }),
        _AppBarBtn(
          icon: Icons.history_outlined,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => StockReportPage())),
        ),
        _AppBarBtn(
          icon: Icons.assignment_return_rounded,
          onTap: () => _showAllReturnsDialog(),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
    );
  }

  void _showAllReturnsDialog() {
    showDialog(
      context: context,
      builder: (_) => _AllReturnsDialog(
        itemReturns: _itemReturns,
        customerNames: customerIdNameMap,
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      backgroundColor: _T.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('New Item', style: TextStyle(fontWeight: FontWeight.w600)),
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RegisterItemPage())).then((_) {
        fetchItems();
        _fetchReturnHistory();
      }),
    );
  }

  void _showImageDialog(String? base64) {
    if (base64 == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(children: [
          InteractiveViewer(
            panEnabled: true, minScale: 0.5, maxScale: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: kIsWeb
                  ? Image.network('data:image/png;base64,$base64')
                  : Image.memory(base64Decode(base64)),
            ),
          ),
          Positioned(top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LEFT PANEL – Item list
// ─────────────────────────────────────────────
class _ItemListPanel extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String?                    selectedKey;
  final TextEditingController      searchController;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(String)      onDelete;
  final void Function(Map<String, dynamic>) onEdit;
  final Map<String, List<Map<String, dynamic>>> itemReturns;

  const _ItemListPanel({
    required this.items, required this.selectedKey,
    required this.searchController, required this.onTap,
    required this.onDelete, required this.onEdit,
    required this.itemReturns,
  });

  double _totalReturned(String itemName) {
    final returns = itemReturns[itemName];
    if (returns == null) return 0;
    return returns.fold(0.0, (sum, r) => sum + (r['quantity'] as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _T.surface,
        border: Border(right: BorderSide(color: _T.border)),
      ),
      child: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _T.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _T.border),
            ),
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: _T.textPri, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search items…',
                hintStyle: TextStyle(color: _T.textTer, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: _T.textTer, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Text('${items.length} items',
                style: const TextStyle(color: _T.textSec, fontSize: 11, letterSpacing: 0.5)),
          ]),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item     = items[i];
              final selected = item['key'] == selectedKey;
              final isBOM    = item['isBOM'] == true;
              final qty      = item['qtyOnHand'] ?? 0;
              final low      = (qty as num) < 5;
              final returned = _totalReturned(item['itemName']?.toString() ?? '');
              final hasReturns = returned > 0;

              return GestureDetector(
                onTap: () => onTap(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? _T.accent.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? _T.accent.withOpacity(0.4) : Colors.transparent,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      // Avatar / image
                      _ItemAvatar(item: item, size: 38),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(item['itemName'] ?? '',
                                style: TextStyle(
                                    color: selected ? _T.accent : _T.textPri,
                                    fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (isBOM) _MiniTag(label: 'BOM', color: _T.bomText, bg: _T.bomBadge),
                            if (hasReturns) _MiniTag(label: 'RET', color: _T.orange, bg: _T.orange.withOpacity(0.15)),
                          ]),
                          const SizedBox(height: 3),
                          Row(children: [
                            Text('PKR ${item['salePrice'] ?? 0}',
                                style: const TextStyle(color: _T.textSec, fontSize: 11)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: low ? _T.red.withOpacity(0.15) : _T.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('$qty pcs',
                                  style: TextStyle(
                                      color: low ? _T.red : _T.green,
                                      fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          if (hasReturns)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('$returned returned',
                                  style: const TextStyle(color: _T.orange, fontSize: 9)),
                            ),
                        ],
                      )),
                      // actions
                      PopupMenuButton<String>(
                        color: _T.surfaceAlt,
                        icon: const Icon(Icons.more_vert, color: _T.textTer, size: 16),
                        onSelected: (v) {
                          if (v == 'edit')   onEdit(item);
                          if (v == 'delete') onDelete(item['key']);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_note, color: _T.blue, size: 16),
                                SizedBox(width: 8),
                                Text('Edit Qty', style: TextStyle(color: _T.textPri, fontSize: 13)),
                              ])),
                          const PopupMenuItem(value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline, color: _T.red, size: 16),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: _T.red, fontSize: 13)),
                              ])),
                        ],
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  RIGHT PANEL – Item detail
// ─────────────────────────────────────────────
class _ItemDetailPanel extends StatelessWidget {
  final Map<String, dynamic> item;
  final double               effectiveCost;
  final double               profitMargin;
  final Map<String, String>  customerNames;
  final VoidCallback         onEdit;
  final VoidCallback         onDelete;
  final VoidCallback         onShowImage;
  final List<Map<String, dynamic>> itemReturns;
  final VoidCallback         onRefresh;

  const _ItemDetailPanel({
    required this.item, required this.effectiveCost,
    required this.profitMargin, required this.customerNames,
    required this.onEdit, required this.onDelete, required this.onShowImage,
    required this.itemReturns, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isBOM   = item['isBOM'] == true;
    final salePrice = double.tryParse(item['salePrice']?.toString() ?? '0') ?? 0;
    final qty       = (item['qtyOnHand'] as num?)?.toDouble() ?? 0;
    final stockVal  = qty * salePrice;
    final marginPos = profitMargin >= 0;
    final totalReturned = itemReturns.fold(0.0, (sum, r) => sum + (r['quantity'] as num).toDouble());
    final netQty = qty + totalReturned;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── HEADER ───────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Big image
          GestureDetector(
            onTap: onShowImage,
            child: _ItemAvatar(item: item, size: 72, cornerRadius: 16),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item['itemName'] ?? '',
                  style: const TextStyle(color: _T.textPri, fontSize: 22,
                      fontWeight: FontWeight.w700, height: 1.2))),
              if (isBOM)
                _MiniTag(label: 'BOM', color: _T.bomText, bg: _T.bomBadge, size: 12),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              if (!isBOM && item['vendor'] != null && item['vendor'].toString().isNotEmpty) ...[
                const Icon(Icons.storefront_outlined, color: _T.textTer, size: 13),
                const SizedBox(width: 4),
                Text(item['vendor'].toString(),
                    style: const TextStyle(color: _T.textSec, fontSize: 12)),
                const SizedBox(width: 12),
              ],
              if (!isBOM && item['unit'] != null && item['unit'].toString().isNotEmpty) ...[
                const Icon(Icons.straighten_outlined, color: _T.textTer, size: 13),
                const SizedBox(width: 4),
                Text(item['unit'].toString(),
                    style: const TextStyle(color: _T.textSec, fontSize: 12)),
              ],
            ]),
          ])),
          // Action buttons
          Row(children: [
            _IconBtn(icon: Icons.edit_outlined, color: _T.blue, onTap: onEdit),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.delete_outline, color: _T.red, onTap: onDelete),
          ]),
        ]),

        const SizedBox(height: 28),

        // ── KPI CARDS ─────────────────────────────
        Row(children: [
          _KpiCard(
            label: 'Sale Price',
            value: 'PKR ${_fmt(salePrice)}',
            icon: Icons.sell_outlined,
            color: _T.accent,
          ),
          const SizedBox(width: 12),
          _KpiCard(
            label: 'Effective Cost',
            value: 'PKR ${_fmt(effectiveCost)}',
            icon: Icons.price_change_outlined,
            color: _T.gold,
          ),
          const SizedBox(width: 12),
          _KpiCard(
            label: 'Profit Margin',
            value: '${profitMargin.toStringAsFixed(1)}%',
            icon: Icons.trending_up_outlined,
            color: marginPos ? _T.green : _T.red,
          ),
          const SizedBox(width: 12),
          _KpiCard(
            label: 'Stock Value',
            value: 'PKR ${_fmt(stockVal)}',
            icon: Icons.account_balance_wallet_outlined,
            color: _T.blue,
          ),
        ]),

        const SizedBox(height: 16),

        // ── RETURN SUMMARY CARD ───────────────────
        if (totalReturned > 0)
          _ReturnSummaryCard(
            totalReturned: totalReturned,
            netQuantity: netQty-1,
            currentQuantity: qty-1,
            onViewReturns: () => _showReturnHistoryDialog(context),
          ),

        if (totalReturned > 0) const SizedBox(height: 16),

        // ── QUANTITY BAR ──────────────────────────
        _QuantityBar(qty: qty.toInt(), returned: totalReturned),

        const SizedBox(height: 28),

        // ── BOM COMPONENTS or COST TABLE ──────────
        if (isBOM && item['components'] != null) ...[
          _SectionHeader(label: 'Bill of Materials'),
          const SizedBox(height: 12),
          _BomTable(components: item['components'], total: effectiveCost),
          const SizedBox(height: 28),
        ],

        // ── CUSTOMER PRICES ───────────────────────
        if (item['customerBasePrices'] != null &&
            (item['customerBasePrices'] as Map).isNotEmpty) ...[
          _SectionHeader(label: 'Customer-Specific Prices'),
          const SizedBox(height: 12),
          _CustomerPriceList(
            prices: Map<String, dynamic>.from(item['customerBasePrices']),
            customerNames: customerNames,
          ),
          const SizedBox(height: 28),
        ],

        // ── RETURN HISTORY ─────────────────────────
        if (itemReturns.isNotEmpty) ...[
          _SectionHeader(label: 'Return History'),
          const SizedBox(height: 12),
          _ReturnHistoryList(
            returns: itemReturns,
            customerNames: customerNames,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 28),
        ],

        // ── METADATA ──────────────────────────────
        _SectionHeader(label: 'Details'),
        const SizedBox(height: 12),
        _MetaGrid(item: item, isBOM: isBOM, totalReturned: totalReturned),

      ]),
    );
  }

  void _showReturnHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ReturnHistoryDialog(
        returns: itemReturns,
        itemName: item['itemName']?.toString() ?? '',
        customerNames: customerNames,
        onRefresh: onRefresh,
      ),
    );
  }

  String _fmt(double v) =>
      NumberFormat('#,##0.00').format(v);
}

// ── RETURN SUMMARY CARD ───────────────────────────
class _ReturnSummaryCard extends StatelessWidget {
  final double totalReturned;
  final double netQuantity;
  final double currentQuantity;
  final VoidCallback onViewReturns;

  const _ReturnSummaryCard({
    required this.totalReturned,
    required this.netQuantity,
    required this.currentQuantity,
    required this.onViewReturns,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _T.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_return_rounded, color: _T.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Return Summary',
                  style: TextStyle(color: _T.textPri, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: onViewReturns,
                child: const Text('View Details', style: TextStyle(color: _T.orange, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      totalReturned.toStringAsFixed(1),
                      style: const TextStyle(color: _T.orange, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Returned', style: TextStyle(color: _T.textSec, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      netQuantity.toStringAsFixed(1),
                      style: const TextStyle(color: _T.green, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Net Quantity', style: TextStyle(color: _T.textSec, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      currentQuantity.toStringAsFixed(1),
                      style: const TextStyle(color: _T.textPri, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Original Stock', style: TextStyle(color: _T.textSec, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── RETURN HISTORY LIST ───────────────────────────
class _ReturnHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> returns;
  final Map<String, String> customerNames;
  final VoidCallback onRefresh;

  const _ReturnHistoryList({
    required this.returns,
    required this.customerNames,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: List.generate(returns.length, (index) {
          final returnItem = returns[index];
          final returnDate = returnItem['returnDate'] != null
              ? DateTime.tryParse(returnItem['returnDate'].toString())
              : null;

          final quantity = returnItem['quantity'];
          final quantityValue = quantity is num ? quantity.toDouble() : 0.0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _T.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_return_rounded, color: _T.orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            returnItem['billNumber']?.toString() ?? 'Unknown Bill',
                            style: const TextStyle(color: _T.textPri, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${quantityValue.toStringAsFixed(1)} pcs returned - ${returnItem['reason']?.toString() ?? 'No reason'}',
                            style: const TextStyle(color: _T.textSec, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (returnDate != null)
                            Text(
                              DateFormat('dd MMM yyyy').format(returnDate),
                              style: const TextStyle(color: _T.textTer, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          returnItem['customerName']?.toString() ?? 'Unknown',
                          style: const TextStyle(color: _T.accent, fontSize: 11, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (returnItem['returnType'] == 'full' ? _T.red : _T.orange).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            returnItem['returnType'] == 'full' ? 'Full Return' : 'Partial',
                            style: TextStyle(
                              color: returnItem['returnType'] == 'full' ? _T.red : _T.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (index < returns.length - 1) const Divider(color: _T.border, height: 1),
            ],
          );
        }),
      ),
    );
  }
}

// ── RETURN HISTORY DIALOG ─────────────────────────
class _ReturnHistoryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> returns;
  final String itemName;
  final Map<String, String> customerNames;
  final VoidCallback onRefresh;

  const _ReturnHistoryDialog({
    required this.returns,
    required this.itemName,
    required this.customerNames,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _T.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_return_rounded, color: _T.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return History',
                        style: const TextStyle(color: _T.textPri, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        itemName,
                        style: const TextStyle(color: _T.textSec, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _T.textTer),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: returns.isEmpty
                  ? const Center(
                child: Text('No returns recorded', style: TextStyle(color: _T.textTer)),
              )
                  : ListView.builder(
                itemCount: returns.length,
                itemBuilder: (context, index) {
                  final returnItem = returns[index];
                  final returnDate = returnItem['returnDate'] != null
                      ? DateTime.tryParse(returnItem['returnDate'].toString())
                      : null;

                  final quantity = returnItem['quantity'];
                  final quantityValue = quantity is num ? quantity.toDouble() : 0.0;

                  final grandTotal = returnItem['grandTotal'];
                  final grandTotalValue = grandTotal is num ? grandTotal.toDouble() : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _T.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _T.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                returnItem['billNumber']?.toString() ?? 'Unknown Bill',
                                style: const TextStyle(color: _T.accent, fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (returnItem['returnType'] == 'full' ? _T.red : _T.orange).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                returnItem['returnType'] == 'full' ? 'Full Return' : 'Partial',
                                style: TextStyle(
                                  color: returnItem['returnType'] == 'full' ? _T.red : _T.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quantity: ${quantityValue.toStringAsFixed(1)} pcs',
                          style: const TextStyle(color: _T.textPri, fontSize: 13),
                        ),
                        Text(
                          'Reason: ${returnItem['reason']?.toString() ?? 'No reason provided'}',
                          style: const TextStyle(color: _T.textSec, fontSize: 12),
                        ),
                        if (returnDate != null)
                          Text(
                            'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(returnDate)}',
                            style: const TextStyle(color: _T.textTer, fontSize: 11),
                          ),
                        Text(
                          'Customer: ${returnItem['customerName']?.toString() ?? 'Unknown'}',
                          style: const TextStyle(color: _T.textSec, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (grandTotalValue > 0)
                          Text(
                            'Refund Amount: PKR ${grandTotalValue.toStringAsFixed(2)}',
                            style: const TextStyle(color: _T.gold, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ALL RETURNS DIALOG ───────────────────────────
class _AllReturnsDialog extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> itemReturns;
  final Map<String, String> customerNames;

  const _AllReturnsDialog({
    required this.itemReturns,
    required this.customerNames,
  });

  @override
  Widget build(BuildContext context) {
    // Convert map entries to list safely
    final allReturns = itemReturns.entries.toList();

    return Dialog(
      backgroundColor: _T.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _T.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_return_rounded, color: _T.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'All Returns',
                        style: TextStyle(color: _T.textPri, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${allReturns.length} items have returns',
                        style: const TextStyle(color: _T.textSec, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _T.textTer),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: allReturns.isEmpty
                  ? const Center(
                child: Text('No returns recorded', style: TextStyle(color: _T.textTer)),
              )
                  : ListView.builder(
                itemCount: allReturns.length,
                itemBuilder: (context, index) {
                  final entry = allReturns[index];
                  final itemName = entry.key;
                  final returns = entry.value;
                  final totalQty = returns.fold<double>(0.0, (sum, r) {
                    final quantity = r['quantity'];
                    if (quantity is num) {
                      return sum + quantity.toDouble();
                    }
                    return sum;
                  });

                  return Card(
                    color: _T.surface,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: _T.border),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => _ReturnHistoryDialog(
                            returns: returns,
                            itemName: itemName,
                            customerNames: customerNames,
                            onRefresh: () {},
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    itemName,
                                    style: const TextStyle(color: _T.textPri, fontSize: 14, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _T.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${totalQty.toStringAsFixed(1)} pcs returned',
                                    style: const TextStyle(color: _T.orange, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Last return: ${returns.isNotEmpty ? (returns.last['billNumber'] ?? 'Unknown') : 'N/A'}',
                              style: const TextStyle(color: _T.textSec, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── QUANTITY BAR WITH RETURN INFO ─────────────────
class _QuantityBar extends StatelessWidget {
  final int qty;
  final double returned;

  const _QuantityBar({required this.qty, this.returned = 0});

  @override
  Widget build(BuildContext context) {
    final max = 100.0;
    final currentQty = qty.toDouble()-1;
    final fill = (currentQty / max).clamp(0.0, 1.0);
    final low = currentQty < 5;
    final medium = currentQty < 20;
    final color = low ? _T.red : medium ? _T.gold : _T.green;
    final netQty = currentQty + returned-1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Stock Level',
              style: TextStyle(color: _T.textSec, fontSize: 12, letterSpacing: 0.3)),
          const Spacer(),
          Text('Current: $qty pcs',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(low ? 'LOW' : medium ? 'MEDIUM' : 'GOOD',
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fill,
            backgroundColor: _T.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
        if (returned > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _T.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: _T.orange, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${returned.toStringAsFixed(1)} units have been returned. Net quantity available: ${netQty.toStringAsFixed(1)}',
                    style: const TextStyle(color: _T.textSec, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// ── META GRID WITH RETURN INFO ───────────────────
class _MetaGrid extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isBOM;
  final double totalReturned;

  const _MetaGrid({required this.item, required this.isBOM, required this.totalReturned});

  @override
  Widget build(BuildContext context) {
    final pairs = <_MetaPair>[
      if (!isBOM) _MetaPair('Vendor',     item['vendor']?.toString()    ?? '—'),
      if (!isBOM) _MetaPair('Unit',       item['unit']?.toString()      ?? '—'),
      if (!isBOM) _MetaPair('Cost Price', 'PKR ${item['costPrice'] ?? 0}'),
      _MetaPair('Category',   item['category']?.toString() ?? '—'),
      _MetaPair('Type',       isBOM ? 'Bill of Materials' : 'Single Item'),
      if (totalReturned > 0) _MetaPair('Total Returned', '${totalReturned.toStringAsFixed(1)} pcs'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: pairs.asMap().entries.map((e) {
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                SizedBox(width: 110,
                    child: Text(e.value.label,
                        style: const TextStyle(color: _T.textSec, fontSize: 12))),
                Expanded(child: Text(e.value.value,
                    style: TextStyle(
                      color: e.value.label == 'Total Returned' ? _T.orange : _T.textPri,
                      fontSize: 13,
                      fontWeight: e.value.label == 'Total Returned' ? FontWeight.w600 : FontWeight.w500,
                    ))),
              ]),
            ),
            if (e.key < pairs.length - 1) const Divider(color: _T.border, height: 1),
          ]);
        }).toList(),
      ),
    );
  }
}

// Rest of the widgets remain the same (_ItemAvatar, _KpiCard, _BomTable, _CustomerPriceList, etc.)
// I've omitted them for brevity but they should be kept as is

class _MetaPair {
  final String label, value;
  const _MetaPair(this.label, this.value);
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(
            color: _T.accent,
            borderRadius: BorderRadius.circular(2),
          )),
      const SizedBox(width: 8),
      Text(label.toUpperCase(),
          style: const TextStyle(color: _T.textSec, fontSize: 11,
              fontWeight: FontWeight.w600, letterSpacing: 1.0)),
    ]);
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color, bg;
  final double size;
  const _MiniTag({required this.label, required this.color, required this.bg, this.size = 10});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _T.border),
          ),
          child: const Icon(Icons.touch_app_outlined, color: _T.textTer, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Select an item', style: TextStyle(color: _T.textSec, fontSize: 15,
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        const Text('Tap any item on the left to see details',
            style: TextStyle(color: _T.textTer, fontSize: 12)),
      ]),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  const _ConfirmDialog({required this.title, required this.message,
    required this.confirmLabel, required this.confirmColor, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _T.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title, style: const TextStyle(color: _T.textPri, fontSize: 16,
          fontWeight: FontWeight.w600)),
      content: Text(message, style: const TextStyle(color: _T.textSec, fontSize: 13)),
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
          onPressed: () { Navigator.pop(context); onConfirm(); },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// Keep these widgets as they were in the original code
class _ItemAvatar extends StatelessWidget {
  final Map<String, dynamic> item;
  final double size;
  final double cornerRadius;
  const _ItemAvatar({required this.item, required this.size, this.cornerRadius = 10});

  @override
  Widget build(BuildContext context) {
    final img = item['image'];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _T.surfaceAlt,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: _T.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: img != null
          ? (kIsWeb
          ? Image.network('data:image/png;base64,$img', fit: BoxFit.cover)
          : Image.memory(base64Decode(img), fit: BoxFit.cover))
          : Icon(Icons.inventory_2_outlined,
          color: _T.textTer, size: size * 0.4),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
          ]),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: _T.textSec, fontSize: 11, letterSpacing: 0.3)),
        ]),
      ),
    );
  }
}

class _BomTable extends StatelessWidget {
  final dynamic components;
  final double  total;
  const _BomTable({required this.components, required this.total});

  @override
  Widget build(BuildContext context) {
    final list = (components as List).cast<Map>();
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(children: [
        // header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: const [
            Expanded(flex: 3, child: Text('Component',
                style: TextStyle(color: _T.textTer, fontSize: 11, letterSpacing: 0.5))),
            Expanded(child: Text('Qty', textAlign: TextAlign.center,
                style: TextStyle(color: _T.textTer, fontSize: 11, letterSpacing: 0.5))),
            Expanded(child: Text('Rate', textAlign: TextAlign.center,
                style: TextStyle(color: _T.textTer, fontSize: 11, letterSpacing: 0.5))),
            Expanded(child: Text('Amount', textAlign: TextAlign.right,
                style: TextStyle(color: _T.textTer, fontSize: 11, letterSpacing: 0.5))),
          ]),
        ),
        const Divider(color: _T.border, height: 1),
        ...list.asMap().entries.map((e) {
          final c   = e.value;
          final qty = double.tryParse(c['quantity'].toString()) ?? 0;
          final px  = double.tryParse(c['price'].toString()) ?? 0;
          final amt = qty * px;
          final neg = qty < 0;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                Expanded(flex: 3, child: Row(children: [
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: neg ? _T.red : _T.accent,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c['name'] ?? '',
                      style: const TextStyle(color: _T.textPri, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
                Expanded(child: Text('$qty ${c['unit'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _T.textSec, fontSize: 12))),
                Expanded(child: Text('PKR $px',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _T.textSec, fontSize: 12))),
                Expanded(child: Text(
                    '${neg ? '-' : ''}PKR ${amt.abs().toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: neg ? _T.red : _T.textPri,
                        fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
            if (e.key < list.length - 1) const Divider(color: _T.border, height: 1),
          ]);
        }).toList(),
        const Divider(color: _T.border, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Expanded(flex: 5,
                child: Text('Total Cost', style: TextStyle(color: _T.textPri,
                    fontSize: 13, fontWeight: FontWeight.w600))),
            Text('PKR ${total.toStringAsFixed(2)}',
                style: const TextStyle(color: _T.gold,
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

class _CustomerPriceList extends StatelessWidget {
  final Map<String, dynamic> prices;
  final Map<String, String>  customerNames;
  const _CustomerPriceList({required this.prices, required this.customerNames});

  @override
  Widget build(BuildContext context) {
    final entries = prices.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: entries.asMap().entries.map((e) {
          final idx  = e.key;
          final entry = e.value;
          final name = customerNames[entry.key] ?? 'Unknown';
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _T.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline, color: _T.blue, size: 15),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(name,
                    style: const TextStyle(color: _T.textPri, fontSize: 13))),
                Text('PKR ${entry.value}',
                    style: const TextStyle(color: _T.accentSoft, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            if (idx < entries.length - 1) const Divider(color: _T.border, height: 1),
          ]);
        }).toList(),
      ),
    );
  }
}