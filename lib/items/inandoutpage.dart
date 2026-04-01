import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../lanprovider.dart';

class ItemTransactionReportPage extends StatefulWidget {
  @override
  _ItemTransactionReportPageState createState() => _ItemTransactionReportPageState();
}

class _ItemTransactionReportPageState extends State<ItemTransactionReportPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  bool _dataLoaded = false;
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String? _selectedItem;
  List<String> _itemNames = [];
  pw.MemoryImage? _cachedHeaderLogo;
  pw.MemoryImage? _cachedFooterLogo;
  bool _resourcesLoaded = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadItemNames();
    _loadPdfResources();
  }

  Future<void> _loadPdfResources() async {
    try {
      final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
      final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');

      _cachedFooterLogo = pw.MemoryImage(footerBytes.buffer.asUint8List());
      _cachedHeaderLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      _resourcesLoaded = true;
    } catch (e) {
      print("Error loading PDF resources: $e");
    }
  }

  Future<void> _loadItemNames() async {
    try {
      final itemsSnapshot = await _db.child('items').once();
      final itemsData = itemsSnapshot.snapshot.value;

      if (itemsData is Map) {
        _itemNames = itemsData.values
            .where((item) => item != null && item['itemName'] != null)
            .map((item) => item['itemName'].toString())
            .toList();
      } else if (itemsData is List) {
        _itemNames = itemsData
            .where((item) => item != null && item['itemName'] != null)
            .map((item) => item['itemName'].toString())
            .toList();
      }

      setState(() {});
    } catch (e) {
      print("Error loading items: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading items: $e')),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _dataLoaded = false;
    });

    try {
      final invoiceData = await _fetchInvoiceData();
      final filledData = await _fetchFilledData();
      final purchaseData = await _fetchPurchaseData();

      List<Map<String, dynamic>> allTransactions = [...invoiceData, ...filledData, ...purchaseData];

      // Filter out transactions with null item names
      allTransactions = allTransactions.where((transaction) =>
      transaction['itemName'] != null && transaction['itemName'].toString().isNotEmpty).toList();

      // If an item is selected, filter by it
      if (_selectedItem != null) {
        allTransactions = allTransactions.where((transaction) =>
        transaction['itemName'] == _selectedItem).toList();
      }

      allTransactions.sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        _allTransactions = allTransactions;
        _filterTransactions(); // Apply date filters
        _dataLoaded = true;
      });

    } catch (e) {
      print("Error loading data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchInvoiceData() async {
    List<Map<String, dynamic>> results = [];
    try {
      final snapshot = await _db.child('invoices').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final invoicesData = snapshot.snapshot.value;
        Map<dynamic, dynamic> invoicesMap = {};

        if (invoicesData is Map) {
          invoicesMap = invoicesData;
        } else if (invoicesData is List) {
          for (int i = 0; i < invoicesData.length; i++) {
            if (invoicesData[i] != null) invoicesMap[i] = invoicesData[i];
          }
        }

        invoicesMap.forEach((invoiceKey, invoiceData) {
          if (invoiceData != null && invoiceData is Map) {
            try {
              final items = invoiceData['items'];
              final createdAt = invoiceData['createdAt'];

              if (createdAt != null) {
                final date = DateTime.parse(createdAt.toString());
                List<dynamic> itemsList = [];
                if (items is List) itemsList = items;
                else if (items is Map) itemsList = items.values.toList();

                for (var item in itemsList) {
                  if (item != null && item is Map) {
                    results.add({
                      'type': 'Invoice Sale',
                      'date': date,
                      'invoiceNumber': invoiceData['invoiceNumber']?.toString() ?? '',
                      'referenceNumber': invoiceData['referenceNumber']?.toString() ?? '', // Add this
                      'customerName': invoiceData['customerName']?.toString() ?? '',
                      'itemName': item['itemName']?.toString() ?? '',
                      'quantity': _parseDouble(item['qty']),
                      'weight': _parseDouble(item['weight']),
                      'rate': _parseDouble(item['rate']),
                      'total': _parseDouble(item['total']),
                    });
                  }
                }
              }
            } catch (e) {
              print("Error processing invoice $invoiceKey: $e");
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching invoice data: $e");
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchFilledData() async {
    List<Map<String, dynamic>> results = [];
    try {
      final snapshot = await _db.child('filled').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final filledData = snapshot.snapshot.value;
        Map<dynamic, dynamic> filledMap = {};

        if (filledData is Map) {
          filledMap = filledData;
        } else if (filledData is List) {
          for (int i = 0; i < filledData.length; i++) {
            if (filledData[i] != null) filledMap[i] = filledData[i];
          }
        }

        filledMap.forEach((filledKey, filledDataItem) {
          if (filledDataItem != null && filledDataItem is Map) {
            try {
              final items = filledDataItem['items'];
              final createdAt = filledDataItem['createdAt'];

              if (createdAt != null) {
                final date = DateTime.parse(createdAt.toString());
                List<dynamic> itemsList = [];
                if (items is List) itemsList = items;
                else if (items is Map) itemsList = items.values.toList();

                for (var item in itemsList) {
                  if (item != null && item is Map) {
                    results.add({
                      'type': 'Filled Sale',
                      'date': date,
                      'filledNumber': filledDataItem['filledNumber']?.toString() ?? '',
                      'referenceNumber': filledDataItem['referenceNumber']?.toString() ?? '', // Add this
                      'customerName': filledDataItem['customerName']?.toString() ?? '',
                      'itemName': item['itemName']?.toString() ?? '',
                      'quantity': _parseDouble(item['qty']),
                      'rate': _parseDouble(item['rate']),
                      'total': _parseDouble(item['total']),
                    });
                  }
                }
              }
            } catch (e) {
              print("Error processing filled $filledKey: $e");
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching filled data: $e");
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchPurchaseData() async {
    List<Map<String, dynamic>> results = [];
    try {
      final snapshot = await _db.child('purchases').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final purchasesData = snapshot.snapshot.value;
        Map<dynamic, dynamic> purchasesMap = {};

        if (purchasesData is Map) {
          purchasesMap = purchasesData;
        } else if (purchasesData is List) {
          for (int i = 0; i < purchasesData.length; i++) {
            if (purchasesData[i] != null) purchasesMap[i] = purchasesData[i];
          }
        }

        purchasesMap.forEach((purchaseKey, purchaseData) {
          if (purchaseData != null && purchaseData is Map) {
            try {
              final timestamp = purchaseData['timestamp'];
              if (timestamp != null) {
                final date = DateTime.parse(timestamp.toString());

                // Check if purchases have multiple items
                if (purchaseData['items'] != null) {
                  // Handle multiple items in a purchase
                  final items = purchaseData['items'];
                  List<dynamic> itemsList = [];

                  if (items is List) {
                    itemsList = items;
                  } else if (items is Map) {
                    itemsList = items.values.toList();
                  }

                  for (var item in itemsList) {
                    if (item != null && item is Map) {
                      results.add({
                        'type': 'Purchase',
                        'date': date,
                        'vendorName': purchaseData['vendorName']?.toString() ?? '',
                        'itemName': item['itemName']?.toString() ?? '',
                        'quantity': _parseDouble(item['quantity']),
                        'rate': _parseDouble(item['purchasePrice']),
                        'referenceNumber': purchaseData['referenceNumber']?.toString() ?? '', // Add this
                        'total': _parseDouble(item['total'] ?? (_parseDouble(item['quantity']) * _parseDouble(item['purchasePrice']))),
                      });
                    }
                  }
                } else {
                  // Single item purchase (old format)
                  results.add({
                    'type': 'Purchase',
                    'date': date,
                    'vendorName': purchaseData['vendorName']?.toString() ?? '',
                    'itemName': purchaseData['itemName']?.toString() ?? '',
                    'quantity': _parseDouble(purchaseData['quantity']),
                    'rate': _parseDouble(purchaseData['purchasePrice']),
                    'referenceNumber': purchaseData['referenceNumber']?.toString() ?? '',
                    'total': _parseDouble(purchaseData['total']),
                  });
                }
              }
            } catch (e) {
              print("Error processing purchase $purchaseKey: $e");
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching purchase data: $e");
    }
    return results;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _filterTransactions() {
    setState(() {
      List<Map<String, dynamic>> filtered = List.from(_allTransactions);

      // Apply date filters
      if (_selectedStartDate != null && _selectedEndDate != null) {
        // Create date-only versions for comparison (ignore time)
        final startDateOnly = DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day);
        final endDateOnly = DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day);

        // Ensure start date is before or equal to end date
        if (startDateOnly.isAfter(endDateOnly)) {
          // Swap dates if start is after end
          final temp = startDateOnly;
          final correctedStartDateOnly = endDateOnly;
          final correctedEndDateOnly = temp;

          filtered = filtered.where((transaction) {
            final transactionDate = transaction['date'] as DateTime;
            final transDateOnly = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);

            // Check if transaction date is within range (inclusive)
            return !transDateOnly.isBefore(correctedStartDateOnly) &&
                !transDateOnly.isAfter(correctedEndDateOnly);
          }).toList();
        } else {
          filtered = filtered.where((transaction) {
            final transactionDate = transaction['date'] as DateTime;
            final transDateOnly = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);

            // Check if transaction date is within range (inclusive)
            return !transDateOnly.isBefore(startDateOnly) &&
                !transDateOnly.isAfter(endDateOnly);
          }).toList();
        }
      } else if (_selectedStartDate != null) {
        final startDateOnly = DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day);
        filtered = filtered.where((transaction) {
          final transactionDate = transaction['date'] as DateTime;
          final transDateOnly = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
          return !transDateOnly.isBefore(startDateOnly);
        }).toList();
      } else if (_selectedEndDate != null) {
        final endDateOnly = DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day);
        filtered = filtered.where((transaction) {
          final transactionDate = transaction['date'] as DateTime;
          final transDateOnly = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
          return !transDateOnly.isAfter(endDateOnly);
        }).toList();
      }

      _filteredTransactions = filtered;
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: _selectedStartDate != null && _selectedEndDate != null
          ? DateTimeRange(start: _selectedStartDate!, end: _selectedEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
        if (_dataLoaded) _filterTransactions();
      });
    }
  }

  Future<Uint8List> _generatePdf() async {
    if (!_resourcesLoaded) {
      await _loadPdfResources();
    }

    final pdf = pw.Document();
    final now = DateTime.now();
    final filteredTransactions = List<Map<String, dynamic>>.from(_filteredTransactions);

    // Calculate totals for summary
    double totalSales = filteredTransactions
        .where((t) => t['type'] == 'Filled Sale')
        .fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0));

    double totalPurchases = filteredTransactions
        .where((t) => t['type'] == 'Purchase')
        .fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0));

    // Prepare data for table - do this once
    // final tableData = filteredTransactions.map((t) {
    //   final List<dynamic> row = [
    //     DateFormat('yyyy-MM-dd').format(t['date']),
    //     t['type'] == 'Invoice Sale' ? 'Inv Sale' :
    //     t['type'] == 'Filled Sale' ? 'Sale' : 'Purchase',
    //     t['type'] == 'Invoice Sale' ? t['invoiceNumber']?.toString() ?? '' :
    //     t['type'] == 'Filled Sale' ? t['filledNumber']?.toString() ?? '' : '-',
    //     t['type'] == 'Purchase' ? (t['vendorName'] ?? '-') : (t['customerName'] ?? '-'),
    //     t['itemName']?.toString() ?? '',
    //     t['quantity']?.toStringAsFixed(2) ?? '0.00',
    //   ];
    //
    //   // Add weight column only if needed
    //   if (filteredTransactions.any((tr) => tr['weight'] != null && tr['weight'] > 0)) {
    //     row.add(t['weight']?.toStringAsFixed(2) ?? '-');
    //   }
    //
    //   row.addAll([
    //     t['rate']?.toStringAsFixed(2) ?? '0.00',
    //     t['total']?.toStringAsFixed(2) ?? '0.00',
    //   ]);
    //
    //   return row;
    // }).toList();
    // In _generatePdf() method, update the tableData preparation:
    final tableData = filteredTransactions.map((t) {
      // Get document number - prioritize referenceNumber
      String docNumber = '';
      if (t['referenceNumber'] != null && t['referenceNumber'].toString().isNotEmpty) {
        docNumber = t['referenceNumber'].toString();
      } else if (t['type'] == 'Invoice Sale') {
        docNumber = t['invoiceNumber']?.toString() ?? '';
      } else if (t['type'] == 'Filled Sale') {
        docNumber = t['filledNumber']?.toString() ?? '';
      } else {
        docNumber = '-';
      }

      final List<dynamic> row = [
        DateFormat('yyyy-MM-dd').format(t['date']),
        t['type'] == 'Invoice Sale' ? 'Inv Sale' :
        t['type'] == 'Filled Sale' ? 'Sale' : 'Purchase',
        docNumber, // Use the docNumber determined above
        t['type'] == 'Purchase' ? (t['vendorName'] ?? '-') : (t['customerName'] ?? '-'),
        t['itemName']?.toString() ?? '',
        t['quantity']?.toStringAsFixed(2) ?? '0.00',
      ];

      // Add weight column only if needed
      if (filteredTransactions.any((tr) => tr['weight'] != null && tr['weight'] > 0)) {
        row.add(t['weight']?.toStringAsFixed(2) ?? '-');
      }

      row.addAll([
        t['rate']?.toStringAsFixed(2) ?? '0.00',
        t['total']?.toStringAsFixed(2) ?? '0.00',
      ]);

      return row;
    }).toList();

    // Determine headers based on data
    final headers = <String>[
      'Date', 'Type', 'Doc No.', 'Customer/Vendor', 'Item', 'Qty',
    ];

    if (filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0)) {
      headers.add('Weight');
    }

    headers.addAll(['Rate', 'Total']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        header: (pw.Context context) {
          // Header only on first page
          if (context.pageNumber == 1) {
            return pw.Column(
              children: [
                if (_cachedHeaderLogo != null)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(_cachedHeaderLogo!, width: 80, height: 80),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Item Transactions Report',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          if (_selectedItem != null)
                            pw.Text(
                              'Item: $_selectedItem',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          if (_selectedStartDate != null && _selectedEndDate != null)
                            pw.Text(
                              'Period: ${DateFormat('yyyy-MM-dd').format(_selectedStartDate!)} - ${DateFormat('yyyy-MM-dd').format(_selectedEndDate!)}',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                        ],
                      ),
                    ],
                  ),
                pw.SizedBox(height: 10),
                // Summary section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryBox('Total Sales', totalSales),
                    pw.SizedBox(width: 10),
                    _buildSummaryBox('Total Purchases', totalPurchases),
                    pw.SizedBox(width: 10),
                    _buildSummaryBox('Net Balance', totalSales - totalPurchases),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),
              ],
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (pw.Context context) {
          // Footer only on last page
          if (context.pageNumber == context.pagesCount) {
            return pw.Column(
              children: [
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (_cachedFooterLogo != null)
                      pw.Image(_cachedFooterLogo!, width: 25, height: 25),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Developed By: Umair Arshad',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Contact: 0307-6455926',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
              ],
            );
          }
          return pw.SizedBox.shrink();
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 5),
            pw.Table.fromTextArray(
              headers: headers,
              data: tableData,
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              headerDecoration: pw.BoxDecoration(
                color: PdfColors.blueGrey,
              ),
              border: pw.TableBorder.all(width: 0.3),
              columnWidths: _getColumnWidths(headers.length),
              headerHeight: 25,
              cellHeight: 20,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Map<int, pw.TableColumnWidth> _getColumnWidths(int headersCount) {
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.2), // Date
      1: const pw.FlexColumnWidth(0.8), // Type
      2: const pw.FlexColumnWidth(1.0), // Doc No.
      3: const pw.FlexColumnWidth(1.8), // Customer/Vendor
      4: const pw.FlexColumnWidth(2.0), // Item
      5: const pw.FlexColumnWidth(0.8), // Qty
    };

    int index = 6;
    if (headersCount == 9) { // With weight column
      widths[index] = const pw.FlexColumnWidth(0.8); // Weight
      index++;
    }

    widths[index] = const pw.FlexColumnWidth(0.9); // Rate
    widths[index + 1] = const pw.FlexColumnWidth(1.0); // Total

    return widths;
  }

  pw.Widget _buildSummaryBox(String title, double value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${value.toStringAsFixed(2)} PKR',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: value >= 0 ? PdfColors.green : PdfColors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf() async {
    try {
      final pdfBytes = await _generatePdf();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/item_report.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Item Transactions Report');
    } catch (e) {
      print('Error sharing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF')));
    }
  }

  Future<void> _previewPdf() async {
    if (_isGeneratingPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF is already being generated...')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Generating PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    try {
      final pdfBytes = await _generatePdf();
      Navigator.of(context).pop(); // Close loading dialog

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }

  String _getDateRangeText(LanguageProvider languageProvider) {
    if (_selectedStartDate != null && _selectedEndDate != null) {
      return '${DateFormat('yyyy-MM-dd').format(_selectedStartDate!)} - ${DateFormat('yyyy-MM-dd').format(_selectedEndDate!)}';
    }
    return languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں';
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Item Transactions Report' : 'آئٹم لین دین کی رپورٹ',
          style: TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_dataLoaded) // Only show when data is loaded
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                  onPressed: _previewPdf,
                  tooltip: 'Preview PDF',
                ),
                IconButton(
                  icon: Icon(Icons.share, color: Colors.white),
                  onPressed: _sharePdf,
                  tooltip: 'Share PDF',
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _selectDateRange(context),
                      icon: Icon(Icons.date_range),
                      label: Text(
                        _getDateRangeText(languageProvider),
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_selectedStartDate != null && _selectedEndDate != null)
                            ? Colors.blue[50]
                            : null,
                        foregroundColor: (_selectedStartDate != null && _selectedEndDate != null)
                            ? Colors.blue
                            : null,
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                    if (_selectedStartDate != null || _selectedEndDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedStartDate = null;
                              _selectedEndDate = null;
                            });
                            if (_dataLoaded) _filterTransactions();
                          },
                          icon: Icon(Icons.clear, size: 16),
                          label: Text(languageProvider.isEnglish ? 'Clear Dates' : 'تاریخیں صاف کریں'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[50],
                            foregroundColor: Colors.red,
                            minimumSize: Size(double.infinity, 40),
                          ),
                        ),
                      ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedItem,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Item' : 'آئٹم',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text(languageProvider.isEnglish ? 'All Items' : 'تمام آئٹمز')),
                        ..._itemNames.map((item) =>
                            DropdownMenuItem(value: item, child: Text(item))).toList(),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedItem = value);
                      },
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadData,
                      icon: _isLoading
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Icon(Icons.bar_chart),
                      label: Text(_isLoading
                          ? (languageProvider.isEnglish ? 'Loading...' : 'لوڈ ہو رہا ہے...')
                          : (languageProvider.isEnglish ? 'Generate Report' : 'رپورٹ تیار کریں')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[300],
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator()
          else if (!_dataLoaded)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      languageProvider.isEnglish
                          ? 'Select filters and generate report'
                          : 'فلٹرز منتخب کریں اور رپورٹ تیار کریں',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  if (_filteredTransactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          _buildSummaryCard(
                            languageProvider.isEnglish ? 'Sales' : 'فروخت',
                            _filteredTransactions
                                .where((t) => t['type'] == 'Filled Sale')
                                .fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0)),
                            _filteredTransactions
                                .where((t) => t['type'] == 'Filled Sale')
                                .fold(0.0, (sum, t) => sum + (t['quantity'] ?? 0.0)),
                            languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                            Colors.white,
                          ),
                          SizedBox(width: 8),
                          _buildSummaryCard(
                            languageProvider.isEnglish ? 'Purchases' : 'خریداری',
                            _filteredTransactions
                                .where((t) => t['type'] == 'Purchase')
                                .fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0)),
                            _filteredTransactions
                                .where((t) => t['type'] == 'Purchase')
                                .fold(0.0, (sum, t) => sum + (t['quantity'] ?? 0.0)),
                            languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _filteredTransactions.isEmpty
                        ? Center(
                      child: Text(
                        languageProvider.isEnglish
                            ? 'No matching transactions'
                            : 'کوئی مماثل لین دین نہیں',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                        : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Date' : 'تاریخ')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Type' : 'قسم')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Doc No.' : 'نمبر')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Customer/Vendor' : 'نام')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Item' : 'آئٹم')),
                            DataColumn(
                                label: Text(languageProvider.isEnglish ? 'Qty' : 'مقدار'),
                                numeric: true),
                            if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0))
                              DataColumn(
                                  label: Text(languageProvider.isEnglish ? 'Wt.' : 'وزن'),
                                  numeric: true),
                            DataColumn(
                                label: Text(languageProvider.isEnglish ? 'Rate' : 'ریٹ'),
                                numeric: true),
                            DataColumn(
                                label: Text(languageProvider.isEnglish ? 'Total' : 'کل'),
                                numeric: true),
                          ],
                          rows: _filteredTransactions.map((transaction) {
                            return DataRow(cells: [
                              DataCell(Text(DateFormat('yyyy-MM-dd').format(transaction['date']))),
                              DataCell(Text(
                                transaction['type'] == 'Filled Sale'
                                    ? 'Sale'
                                    : transaction['type'],
                              )),
                              // DataCell(Text(
                              //     transaction['type'] == 'Invoice Sale'
                              //         ? transaction['invoiceNumber'].toString()
                              //         : transaction['type'] == 'Filled Sale'
                              //         ? transaction['filledNumber'].toString()
                              //         : '-')),
                              DataCell(Text(
                                // First check for referenceNumber, fallback to other numbers
                                  (transaction['referenceNumber'] != null && transaction['referenceNumber'].toString().isNotEmpty)
                                      ? transaction['referenceNumber'].toString()
                                      : transaction['type'] == 'Invoice Sale'
                                      ? transaction['invoiceNumber'].toString()
                                      : transaction['type'] == 'Filled Sale'
                                      ? transaction['filledNumber'].toString()
                                      : '-'
                              )),
                              DataCell(Text(
                                transaction['type'] == 'Purchase'
                                    ? transaction['vendorName']
                                    : transaction['customerName'] ?? '-',
                                overflow: TextOverflow.ellipsis,
                              )),
                              DataCell(Text(transaction['itemName'])),
                              DataCell(Text(transaction['quantity'].toStringAsFixed(2))),
                              if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0))
                                DataCell(Text(transaction['weight']?.toStringAsFixed(2) ?? '-')),
                              DataCell(Text(transaction['rate'].toStringAsFixed(2))),
                              DataCell(Text(transaction['total'].toStringAsFixed(2))),
                            ]);
                          }).toList(),
                        ),
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

  Widget _buildSummaryCard(
      String title,
      double totalValue,
      double totalWeightOrQty,
      String weightLabel,
      Color color,
      )
  {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              SizedBox(height: 4),
              Text(
                '${totalValue.toStringAsFixed(2)} PKR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
              SizedBox(height: 4),
              Text(
                '$weightLabel: ${totalWeightOrQty.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}