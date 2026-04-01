import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../lanprovider.dart';

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

class ItemPurchasePage extends StatefulWidget {
  final String? initialVendorId;
  final String? initialVendorName;
  final List<Map<String, dynamic>> initialItems;
  final bool isFromPurchaseOrder;
  final bool isEditMode;
  final String? purchaseKey;

  ItemPurchasePage({
    this.initialVendorId,
    this.initialVendorName,
    this.initialItems = const [],
    this.isFromPurchaseOrder = false,
    this.isEditMode = false,
    this.purchaseKey,
  });

  @override
  _ItemPurchasePageState createState() => _ItemPurchasePageState();
}

class _ItemPurchasePageState extends State<ItemPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDateTime;

  late TextEditingController _vendorSearchController;
  late TextEditingController _refNoController;

  bool _isLoadingItems = false;
  bool _isLoadingVendors = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _vendors = [];
  Map<String, dynamic>? _selectedVendor;

  List<PurchaseItem> _purchaseItems = [];
  Map<String, double> _wastageRecords = {};

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
    _vendorSearchController = TextEditingController();
    _refNoController = TextEditingController();

    if (widget.isEditMode && widget.purchaseKey != null) {
      _loadExistingPurchase();
    } else if (widget.initialItems.isNotEmpty) {
      _purchaseItems = widget.initialItems.map((item) {
        return PurchaseItem()
          ..itemNameController.text = item['itemName']?.toString() ?? ''
          ..quantityController.text = (item['quantity'] as num?)?.toString() ?? '0'
          ..priceController.text = (item['purchasePrice'] as num?)?.toString() ?? '0';
      }).toList();
    } else {
      _purchaseItems = List.generate(3, (index) => PurchaseItem());
    }

    if (widget.initialVendorId != null && widget.initialVendorName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedVendor = {
              'key': widget.initialVendorId,
              'name': widget.initialVendorName,
            };
            _vendorSearchController.text = widget.initialVendorName!;
          });
        }
      });
    }
    fetchItems();
    fetchVendors();
  }

  Future<void> _loadExistingPurchase() async {
    if (!widget.isEditMode || widget.purchaseKey == null) return;

    final database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('purchases').child(widget.purchaseKey!).get();

    if (snapshot.exists) {
      final purchaseData = snapshot.value as Map<dynamic, dynamic>;

      if (mounted) {
        setState(() {
          if (purchaseData['timestamp'] != null) {
            _selectedDateTime = DateTime.parse(purchaseData['timestamp'].toString());
          }

          if (purchaseData['vendorId'] != null && purchaseData['vendorName'] != null) {
            _selectedVendor = {
              'key': purchaseData['vendorId'].toString(),
              'name': purchaseData['vendorName'].toString(),
            };
            _vendorSearchController.text = purchaseData['vendorName'].toString();
          }

          if (purchaseData['refNo'] != null) {
            _refNoController.text = purchaseData['refNo'].toString();
          }

          final items = purchaseData['items'] as List<dynamic>?;
          if (items != null) {
            _purchaseItems = items.map((item) {
              final itemMap = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
              return PurchaseItem()
                ..itemNameController.text = itemMap['itemName']?.toString() ?? ''
                ..quantityController.text = (itemMap['quantity'] as num?)?.toString() ?? '0'
                ..priceController.text = (itemMap['purchasePrice'] as num?)?.toString() ?? '0';
            }).toList();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _vendorSearchController.dispose();
    _refNoController.dispose();
    for (var item in _purchaseItems) {
      item.dispose();
    }
    super.dispose();
  }

  double calculateItemTotal(PurchaseItem item) {
    final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
    final price    = double.tryParse(item.priceController.text)    ?? 0.0;
    return quantity * price;
  }

  double calculateTotal() {
    return _purchaseItems.fold(0.0, (sum, item) => sum + calculateItemTotal(item));
  }

  Future<void> _updateInventoryQuantities(List<PurchaseItem> validItems, String purchaseId) async {
    final database = FirebaseDatabase.instance.ref();
    final componentConsumptionRef = database.child('componentConsumption').child(purchaseId);
    Map<String, Map<String, dynamic>> missingComponents = {};

    for (var purchaseItem in validItems) {
      String itemName    = purchaseItem.itemNameController.text;
      double purchasedQty = double.tryParse(purchaseItem.quantityController.text) ?? 0.0;

      var existingItem = _items.firstWhere(
            (inv) => inv['itemName'].toLowerCase() == itemName.toLowerCase(),
        orElse: () => {},
      );

      if (existingItem.isNotEmpty) {
        String itemKey      = existingItem['key'];
        double currentQty   = existingItem['qtyOnHand']?.toDouble() ?? 0.0;
        double purchasePrice = double.tryParse(purchaseItem.priceController.text) ?? 0.0;

        await database.child('items').child(itemKey).update({
          'qtyOnHand': currentQty + purchasedQty,
          'costPrice': purchasePrice,
        });

        if (existingItem['isBOM'] == true) {
          dynamic componentsData = existingItem['components'];
          Map<String, dynamic> components = {};

          if (componentsData is Map) {
            components = componentsData.cast<String, dynamic>();
          } else if (componentsData is List) {
            for (int i = 0; i < componentsData.length; i += 2) {
              if (i + 1 < componentsData.length) {
                components[componentsData[i].toString()] = componentsData[i + 1];
              }
            }
          }

          Map<String, dynamic> consumptionRecord = {
            'bomItemName': itemName,
            'bomItemKey': itemKey,
            'quantityProduced': purchasedQty,
            'timestamp': _selectedDateTime.toString(),
            'components': {},
          };

          for (var componentEntry in components.entries) {
            String componentName = componentEntry.key;
            double qtyPerUnit = 0.0;

            if (componentEntry.value is num) {
              qtyPerUnit = (componentEntry.value as num).toDouble();
            } else if (componentEntry.value is String) {
              qtyPerUnit = double.tryParse(componentEntry.value as String) ?? 0.0;
            }

            double totalQtyRequired = qtyPerUnit * purchasedQty;

            var componentItem = _items.firstWhere(
                  (item) => item['itemName'].toLowerCase() == componentName.toLowerCase(),
              orElse: () => {},
            );

            if (componentItem.isNotEmpty) {
              String componentKey  = componentItem['key'];
              double compCurrentQty = componentItem['qtyOnHand']?.toDouble() ?? 0.0;

              if (compCurrentQty < totalQtyRequired) {
                missingComponents[componentKey] = {
                  'name': componentName,
                  'requiredQty': totalQtyRequired,
                  'availableQty': compCurrentQty,
                  'unit': componentItem['unit'] ?? '',
                };
              }

              consumptionRecord['components'][componentName] = {
                'required': totalQtyRequired,
                'used': compCurrentQty >= totalQtyRequired ? totalQtyRequired : compCurrentQty,
                'remaining': compCurrentQty >= totalQtyRequired
                    ? compCurrentQty - totalQtyRequired
                    : 0.0,
              };
            }
          }

          await componentConsumptionRef.set(consumptionRecord);
        }
      }
    }

    if (missingComponents.isNotEmpty) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

      bool proceed = await showDialog(
        context: context,
        builder: (context) => _ConfirmDialog(
          title: languageProvider.isEnglish ? 'Insufficient Components' : 'اجزاء کی کمی',
          message: languageProvider.isEnglish
              ? 'Some components have insufficient stock. Do you want to proceed anyway?'
              : 'کچھ اجزاء کی اسٹاک ناکافی ہے۔ کیا آپ پھر بھی جاری رکھنا چاہتے ہیں؟',
          confirmLabel: languageProvider.isEnglish ? 'Proceed Anyway' : 'پھر بھی جاری رکھیں',
          confirmColor: _T.orange,
          onConfirm: () {},
        ),
      );

      if (!proceed) {
        await _revertInventoryUpdates(validItems);
        return;
      }
    }

    for (var purchaseItem in validItems) {
      String itemName     = purchaseItem.itemNameController.text;
      double purchasedQty = double.tryParse(purchaseItem.quantityController.text) ?? 0.0;

      var existingItem = _items.firstWhere(
            (inv) => inv['itemName'].toLowerCase() == itemName.toLowerCase(),
        orElse: () => {},
      );

      if (existingItem.isNotEmpty && existingItem['isBOM'] == true) {
        dynamic componentsData = existingItem['components'];
        Map<String, dynamic> components = {};

        if (componentsData is Map) {
          components = componentsData.cast<String, dynamic>();
        } else if (componentsData is List) {
          for (int i = 0; i < componentsData.length; i += 2) {
            if (i + 1 < componentsData.length) {
              components[componentsData[i].toString()] = componentsData[i + 1];
            }
          }
        }

        for (var componentEntry in components.entries) {
          String componentName = componentEntry.key;
          double qtyPerUnit = 0.0;

          if (componentEntry.value is num) {
            qtyPerUnit = (componentEntry.value as num).toDouble();
          } else if (componentEntry.value is String) {
            qtyPerUnit = double.tryParse(componentEntry.value as String) ?? 0.0;
          }

          double totalQtyRequired = qtyPerUnit * purchasedQty;

          var componentItem = _items.firstWhere(
                (item) => item['itemName'].toLowerCase() == componentName.toLowerCase(),
            orElse: () => {},
          );

          if (componentItem.isNotEmpty) {
            String componentKey   = componentItem['key'];
            double compCurrentQty = componentItem['qtyOnHand']?.toDouble() ?? 0.0;
            double qtyToDeduct    = compCurrentQty < totalQtyRequired ? compCurrentQty : totalQtyRequired;

            await database.child('items').child(componentKey).update({
              'qtyOnHand': compCurrentQty - qtyToDeduct,
            });

            if (qtyToDeduct < totalQtyRequired) {
              await database.child('wastage').push().set({
                'itemName': componentName,
                'quantity': totalQtyRequired - qtyToDeduct,
                'date': DateTime.now().toString(),
                'purchaseId': purchaseId,
                'type': 'component_shortage',
                'relatedBOM': itemName,
              });
            }
          }
        }
      }
    }
  }

  Future<void> _revertInventoryUpdates(List<PurchaseItem> validItems) async {
    final database = FirebaseDatabase.instance.ref();

    for (var purchaseItem in validItems) {
      String itemName     = purchaseItem.itemNameController.text;
      double purchasedQty = double.tryParse(purchaseItem.quantityController.text) ?? 0.0;

      var existingItem = _items.firstWhere(
            (inv) => inv['itemName'].toLowerCase() == itemName.toLowerCase(),
        orElse: () => {},
      );

      if (existingItem.isNotEmpty) {
        String itemKey    = existingItem['key'];
        double currentQty = existingItem['qtyOnHand']?.toDouble() ?? 0.0;
        await database.child('items').child(itemKey).update({
          'qtyOnHand': currentQty - purchasedQty,
        });
      }
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    if (mounted) {
      _snack(languageProvider.isEnglish
          ? 'Purchase cancelled due to insufficient components'
          : 'اجزاء کی کمی کی وجہ سے خریداری منسوخ کر دی گئی', error: true);
    }
    throw Exception('Purchase cancelled due to insufficient components');
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? _T.red : _T.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> fetchVendors() async {
    if (!mounted) return;
    setState(() => _isLoadingVendors = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('vendors').get();
      if (snapshot.exists && mounted) {
        final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = vendorData.entries.map((entry) => {
            'key': entry.key,
            'name': entry.value['name'] ?? '',
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) _snack('Error fetching vendors: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoadingVendors = false);
    }
  }

  Future<void> fetchItems() async {
    if (!mounted) return;
    setState(() => _isLoadingItems = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('items').get();
      if (snapshot.exists && mounted) {
        dynamic itemData = snapshot.value;
        Map<dynamic, dynamic> itemsMap = {};

        if (itemData is Map) {
          itemsMap = itemData;
        } else if (itemData is List) {
          itemsMap = {for (var i = 0; i < itemData.length; i++) i.toString(): itemData[i]};
        }

        setState(() {
          _items = itemsMap.entries.map((entry) {
            dynamic componentsData = entry.value['components'];
            Map<String, dynamic> componentsMap = {};

            if (componentsData != null) {
              if (componentsData is Map) {
                componentsMap = componentsData.cast<String, dynamic>();
              } else if (componentsData is List) {
                for (int i = 0; i < componentsData.length; i += 2) {
                  if (i + 1 < componentsData.length) {
                    componentsMap[componentsData[i].toString()] = componentsData[i + 1];
                  }
                }
              }
            }

            return {
              'key': entry.key,
              'itemName': entry.value['itemName']?.toString() ?? '',
              'costPrice': (entry.value['costPrice'] as num?)?.toDouble() ?? 0.0,
              'qtyOnHand': (entry.value['qtyOnHand'] as num?)?.toDouble() ?? 0.0,
              'isBOM': entry.value['isBOM'] == true,
              'components': componentsMap,
              'unit': entry.value['unit']?.toString() ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) _snack('Error fetching items: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDateTime && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year, picked.month, picked.day,
          _selectedDateTime.hour, _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year, _selectedDateTime.month, _selectedDateTime.day,
          picked.hour, picked.minute,
        );
      });
    }
  }

  void addNewItem() => setState(() => _purchaseItems.add(PurchaseItem()));

  void removeItem(int index) {
    if (_purchaseItems.length <= 1 || index < 0 || index >= _purchaseItems.length) return;
    final itemToRemove = _purchaseItems[index];
    setState(() => _purchaseItems = List.from(_purchaseItems)..removeAt(index));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) itemToRemove.dispose();
    });
  }

  void _clearForm() {
    if (!mounted) return;
    final itemsToDispose = List<PurchaseItem>.from(_purchaseItems);
    setState(() {
      _purchaseItems    = List.generate(3, (index) => PurchaseItem());
      _selectedVendor   = null;
      _selectedDateTime = DateTime.now();
      _refNoController.clear();
    });
    _vendorSearchController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var item in itemsToDispose) item.dispose();
    });
  }

  Widget tableHeader(String text) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _T.accent,
            fontSize: 12,
            letterSpacing: 0.5)),
  );

  Future<Uint8List> _generatePdf(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final total      = calculateTotal();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final pdf        = pw.Document();

    pdf.addPage(pw.Page(
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(
            level: 0,
            child: pw.Text(
              widget.isFromPurchaseOrder
                  ? (languageProvider.isEnglish ? 'Purchase Receipt' : 'رسید خرید')
                  : (languageProvider.isEnglish ? 'Purchase Invoice' : 'انوائس خرید'),
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(languageProvider.isEnglish ? 'Vendor: ' : 'فروش: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_selectedVendor?['name'] ?? ''),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(languageProvider.isEnglish ? 'Date: ' : 'تاریخ: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(dateFormat.format(_selectedDateTime)),
            ],
          ),
          if (_refNoController.text.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(languageProvider.isEnglish ? 'Ref No: ' : 'ریف نمبر: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(_refNoController.text),
              ],
            ),
          ],
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FF6B35')),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headers: [
              languageProvider.isEnglish ? 'No.'       : 'نمبر',
              languageProvider.isEnglish ? 'Item Name' : 'آئٹم کا نام',
              languageProvider.isEnglish ? 'Qty'       : 'مقدار',
              languageProvider.isEnglish ? 'Price'     : 'قیمت',
              languageProvider.isEnglish ? 'Total'     : 'کل',
            ],
            data: _purchaseItems
                .where((item) =>
            item.itemNameController.text.isNotEmpty &&
                item.quantityController.text.isNotEmpty &&
                item.priceController.text.isNotEmpty)
                .map((item) {
              final qty   = double.tryParse(item.quantityController.text) ?? 0.0;
              final price = double.tryParse(item.priceController.text) ?? 0.0;
              return [
                '${_purchaseItems.indexOf(item) + 1}',
                item.itemNameController.text,
                qty.toStringAsFixed(2),
                price.toStringAsFixed(2),
                (qty * price).toStringAsFixed(2),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                '${languageProvider.isEnglish ? 'Grand Total: ' : 'کل کل: '}${total.toStringAsFixed(2)} PKR',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  Future<void> _revertOldPurchaseQuantities() async {
    if (!widget.isEditMode || widget.purchaseKey == null) return;
    final database = FirebaseDatabase.instance.ref();
    final oldSnapshot = await database.child('purchases').child(widget.purchaseKey!).get();
    if (!oldSnapshot.exists) return;

    final oldPurchaseData = oldSnapshot.value as Map<dynamic, dynamic>;
    final oldItems = oldPurchaseData['items'] as List<dynamic>?;
    if (oldItems == null) return;

    for (var oldItem in oldItems) {
      final itemName    = oldItem['itemName']?.toString() ?? '';
      final oldQuantity = (oldItem['quantity'] as num?)?.toDouble() ?? 0.0;

      if (itemName.isNotEmpty) {
        var existingItem = _items.firstWhere(
              (inv) => inv['itemName'].toLowerCase() == itemName.toLowerCase(),
          orElse: () => {},
        );
        if (existingItem.isNotEmpty) {
          String itemKey    = existingItem['key'];
          double currentQty = existingItem['qtyOnHand']?.toDouble() ?? 0.0;
          await database.child('items').child(itemKey).update({
            'qtyOnHand': currentQty - oldQuantity,
          });
        }
      }
    }
  }

  Future<void> savePurchase() async {
    if (!mounted) return;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_formKey.currentState!.validate()) {
      if (_selectedVendor == null) {
        _snack(languageProvider.isEnglish
            ? 'Please select a vendor' : 'براہ کرم فروش منتخب کریں', error: true);
        return;
      }

      List<PurchaseItem> validItems = _purchaseItems.where((item) =>
      item.itemNameController.text.isNotEmpty &&
          item.quantityController.text.isNotEmpty &&
          item.priceController.text.isNotEmpty).toList();

      if (validItems.isEmpty) {
        _snack(languageProvider.isEnglish
            ? 'Please add at least one item' : 'براہ کرم کم از کم ایک آئٹم شامل کریں', error: true);
        return;
      }

      try {
        final database = FirebaseDatabase.instance.ref();
        _wastageRecords.clear();

        final purchaseData = {
          'items': validItems.map((item) => {
            'itemName':      item.itemNameController.text,
            'quantity':      double.tryParse(item.quantityController.text) ?? 0.0,
            'purchasePrice': double.tryParse(item.priceController.text)    ?? 0.0,
            'total':         calculateItemTotal(item),
            'isBOM': _items.any((inv) =>
            inv['itemName'].toLowerCase() ==
                item.itemNameController.text.toLowerCase() &&
                inv['isBOM'] == true),
          }).toList(),
          'vendorId':   _selectedVendor!['key'],
          'vendorName': _selectedVendor!['name'],
          'refNo':      _refNoController.text,
          'grandTotal': calculateTotal(),
          'timestamp':  _selectedDateTime.toString(),
          'type':       'credit',
          'hasBOM': validItems.any((item) =>
              _items.any((inv) =>
              inv['itemName'].toLowerCase() ==
                  item.itemNameController.text.toLowerCase() &&
                  inv['isBOM'] == true)),
        };

        DatabaseReference purchaseRef;
        String purchaseId;

        if (widget.isEditMode && widget.purchaseKey != null) {
          purchaseId  = widget.purchaseKey!;
          purchaseRef = database.child('purchases').child(purchaseId);
          await _revertOldPurchaseQuantities();
          await purchaseRef.update(purchaseData);
        } else {
          purchaseRef = database.child('purchases').push();
          purchaseId  = purchaseRef.key!;
          await purchaseRef.set(purchaseData);
        }

        await _updateInventoryQuantities(validItems, purchaseId);

        if (mounted) {
          _snack(languageProvider.isEnglish
              ? (widget.isEditMode ? 'Purchase updated successfully!' : 'Purchase recorded successfully!')
              : (widget.isEditMode ? 'خریداری کامیابی سے اپ ڈیٹ ہو گئی!' : 'خریداری کامیابی سے ریکارڈ ہو گئی!'));
          if (!widget.isEditMode) {
            _clearForm();
          } else {
            Navigator.of(context).pop();
          }
        }
      } catch (error) {
        if (error.toString().contains('cancelled due to insufficient components')) return;
        if (mounted) {
          _snack(languageProvider.isEnglish
              ? 'Failed to ${widget.isEditMode ? 'update' : 'record'} purchase: $error'
              : 'خریداری ${widget.isEditMode ? 'اپ ڈیٹ' : 'ریکارڈ'} کرنے میں ناکامی: $error', error: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final total = calculateTotal();

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(languageProvider),
      body: _isLoadingItems || _isLoadingVendors
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vendor Section
              _buildVendorSection(languageProvider),
              const SizedBox(height: 20),

              // Reference Number
              _buildRefNoSection(languageProvider),
              const SizedBox(height: 24),

              // Items Table
              _buildItemsTable(languageProvider),
              const SizedBox(height: 24),

              // Date/Time Section
              _buildDateTimeSection(languageProvider),
              const SizedBox(height: 16),

              // Grand Total
              _buildGrandTotalCard(total, languageProvider),
              const SizedBox(height: 24),

              // Save Button
              _buildSaveButton(languageProvider),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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
          child: Icon(
            widget.isEditMode ? Icons.edit_outlined : Icons.shopping_cart_outlined,
            color: _T.accent,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          widget.isEditMode
              ? (lang.isEnglish ? 'Edit Purchase' : 'خریداری میں ترمیم کریں')
              : widget.isFromPurchaseOrder
              ? (lang.isEnglish ? 'Receive Items' : 'آئٹمز وصول کریں')
              : (lang.isEnglish ? 'Purchase Items' : 'آئٹمز خریداری'),
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
          onTap: () async {
            try {
              final pdfBytes = await _generatePdf(context);
              await Printing.layoutPdf(onLayout: (format) => pdfBytes);
            } catch (e) {
              _snack(lang.isEnglish
                  ? 'Error generating PDF: $e'
                  : 'PDF بنانے میں خرابی: $e', error: true);
            }
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
    );
  }

  Widget _buildVendorSection(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: lang.isEnglish ? 'Vendor Information' : 'وینڈر کی معلومات'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable.empty();
              return _vendors.where((v) =>
                  v['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            displayStringForOption: (vendor) => vendor['name'],
            onSelected: (vendor) => setState(() => _selectedVendor = vendor),
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              _vendorSearchController = controller;
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: _T.textPri),
                decoration: InputDecoration(
                  hintText: lang.isEnglish ? 'Search vendor...' : 'وینڈر تلاش کریں...',
                  hintStyle: const TextStyle(color: _T.textTer),
                  prefixIcon: const Icon(Icons.business, color: _T.textTer, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRefNoSection(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: lang.isEnglish ? 'Reference Number' : 'ریفیرنس نمبر'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: TextFormField(
            controller: _refNoController,
            style: const TextStyle(color: _T.textPri),
            decoration: InputDecoration(
              hintText: lang.isEnglish ? 'Enter reference number...' : 'ریفیرنس نمبر درج کریں...',
              hintStyle: const TextStyle(color: _T.textTer),
              prefixIcon: const Icon(Icons.numbers, color: _T.textTer, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(label: lang.isEnglish ? 'Purchase Items' : 'خریداری کے آئٹمز'),
            _AddItemButton(onPressed: addNewItem),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 48,
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(50),
                  1: FlexColumnWidth(3),
                  2: FixedColumnWidth(100),
                  3: FixedColumnWidth(100),
                  4: FixedColumnWidth(50),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: _T.border),
                  verticalInside: BorderSide(color: _T.border),
                  bottom: BorderSide(color: _T.border),
                  top: BorderSide(color: _T.border),
                  right: BorderSide(color: _T.border),
                  left: BorderSide(color: _T.border),
                ),
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(color: _T.surfaceAlt),
                    children: [
                      _tableHeader('No.'),
                      _tableHeader(lang.isEnglish ? 'Item Name' : 'آئٹم کا نام'),
                      _tableHeader(lang.isEnglish ? 'Qty' : 'مقدار'),
                      _tableHeader(lang.isEnglish ? 'Price' : 'قیمت'),
                      const SizedBox(),
                    ],
                  ),
                  // Rows
                  ..._purchaseItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('${index + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _T.textSec, fontWeight: FontWeight.w600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: _ItemAutocomplete(
                            item: item,
                            items: _items,
                            languageProvider: lang,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextFormField(
                            controller: item.quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: _T.textPri, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _T.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _T.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _T.accent),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextFormField(
                            controller: item.priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: _T.textPri, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _T.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _T.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _T.accent),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              prefixText: 'PKR ',
                              prefixStyle: const TextStyle(color: _T.textTer, fontSize: 12),
                            ),
                          ),
                        ),
                        Center(
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: _T.red, size: 20),
                            onPressed: _purchaseItems.length > 1 ? () => removeItem(index) : null,
                            tooltip: 'Remove item',
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: _T.accent,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: lang.isEnglish ? 'Date & Time' : 'تاریخ اور وقت'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateTimeButton(
                icon: Icons.calendar_today,
                label: lang.isEnglish ? 'Select Date' : 'تاریخ منتخب کریں',
                onPressed: () => _selectDate(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimeButton(
                icon: Icons.access_time,
                label: lang.isEnglish ? 'Select Time' : 'وقت منتخب کریں',
                onPressed: () => _selectTime(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _T.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, color: _T.textTer, size: 16),
              const SizedBox(width: 8),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime),
                style: const TextStyle(color: _T.accent, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrandTotalCard(double total, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_T.accent.withOpacity(0.1), _T.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            lang.isEnglish ? 'Grand Total' : 'کل کل',
            style: const TextStyle(
              color: _T.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'PKR ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _T.gold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(LanguageProvider lang) {
    return Center(
      child: ElevatedButton(
        onPressed: savePurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          widget.isFromPurchaseOrder
              ? (lang.isEnglish ? 'Receive Items' : 'آئٹمز وصول کریں')
              : (lang.isEnglish ? 'Record Purchase' : 'خریداری ریکارڈ کریں'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
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

class _AddItemButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddItemButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _T.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _T.accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: _T.accent, size: 16),
            const SizedBox(width: 4),
            Text(
              'Add Item',
              style: TextStyle(color: _T.accent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _DateTimeButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _T.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: _T.textSec, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemAutocomplete extends StatelessWidget {
  final PurchaseItem item;
  final List<Map<String, dynamic>> items;
  final LanguageProvider languageProvider;

  const _ItemAutocomplete({
    required this.item,
    required this.items,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      initialValue: TextEditingValue(text: item.itemNameController.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable.empty();
        return items.where((i) =>
            i['itemName'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (i) => i['itemName'],
      onSelected: (selectedItem) {
        item.selectedItem = selectedItem;
        item.itemNameController.text = selectedItem['itemName'];
        item.priceController.text = selectedItem['costPrice'].toStringAsFixed(2);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        controller.text = item.itemNameController.text;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) => item.itemNameController.text = value,
          style: const TextStyle(color: _T.textPri, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _T.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _T.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _T.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: languageProvider.isEnglish ? 'Enter item name' : 'آئٹم کا نام درج کریں',
            hintStyle: const TextStyle(color: _T.textTer, fontSize: 12),
          ),
        );
      },
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
          onPressed: () => Navigator.pop(context, false),
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
            Navigator.pop(context, true);
            onConfirm();
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
class PurchaseItem {
  late TextEditingController itemNameController;
  late TextEditingController quantityController;
  late TextEditingController priceController;
  Map<String, dynamic>? selectedItem;

  PurchaseItem() {
    itemNameController = TextEditingController();
    quantityController = TextEditingController();
    priceController    = TextEditingController();
    selectedItem       = null;
  }

  void dispose() {
    itemNameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}