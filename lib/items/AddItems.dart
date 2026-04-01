import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../lanprovider.dart';

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
}

class RegisterItemPage extends StatefulWidget {
  final Map<String, dynamic>? itemData;

  RegisterItemPage({this.itemData});

  @override
  _RegisterItemPageState createState() => _RegisterItemPageState();
}

class _RegisterItemPageState extends State<RegisterItemPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  String? _imageBase64;
  html.File? _webImageFile;

  // Controllers
  late TextEditingController _itemNameController;
  late TextEditingController _costPriceController;
  late TextEditingController _salePriceController;
  late TextEditingController _qtyOnHandController;
  final TextEditingController _vendorSearchController = TextEditingController();

  // Dropdown values
  String? _selectedVendor;
  List<String> _vendors = [];

  // State management
  bool _isLoadingVendors = false;
  List<String> _filteredVendors = [];

  @override
  void initState() {
    super.initState();

    _itemNameController = TextEditingController(text: widget.itemData?['itemName'] ?? '');
    _costPriceController = TextEditingController(text: widget.itemData?['costPrice']?.toString() ?? '');
    _salePriceController = TextEditingController(text: widget.itemData?['salePrice']?.toString() ?? '');
    _qtyOnHandController = TextEditingController(text: widget.itemData?['qtyOnHand']?.toString() ?? '');

    _selectedVendor = widget.itemData?['vendor'];

    _vendorSearchController.addListener(() => _filterVendors(_vendorSearchController.text));

    fetchVendors();

    if (widget.itemData != null && widget.itemData!['image'] != null) {
      _imageBase64 = widget.itemData!['image'];
    }
  }

  Future<void> fetchVendors() async {
    setState(() => _isLoadingVendors = true);
    try {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('vendors').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = vendorData.entries.map((entry) => entry.value['name'] as String).toList();
          _filteredVendors = List.from(_vendors);
        });
      }
    } catch (e) {
      print('Error fetching vendors: $e');
    } finally {
      setState(() => _isLoadingVendors = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        uploadInput.onChange.listen((e) {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final reader = html.FileReader();

            reader.onLoadEnd.listen((e) {
              setState(() {
                _webImageFile = file;
                _imageBase64 = reader.result.toString().split(',').last;
              });
            });

            reader.readAsDataUrl(file);
          }
        });
      } else {
        final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          final bytes = await File(pickedFile.path).readAsBytes();
          setState(() {
            _imageFile = pickedFile;
            _imageBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', error: true);
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _imageBase64 = null;
    });
  }

  void _filterVendors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVendors = List.from(_vendors);
      } else {
        _filteredVendors = _vendors
            .where((vendor) => vendor.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<bool> checkIfItemExists(String itemName) async {
    final DatabaseReference database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('items').get();

    if (snapshot.exists && snapshot.value is Map) {
      Map<dynamic, dynamic> items = snapshot.value as Map<dynamic, dynamic>;
      for (var key in items.keys) {
        if (items[key]['itemName'].toString().toLowerCase() == itemName.toLowerCase()) {
          return true;
        }
      }
    }
    return false;
  }

  void _clearFormFields() {
    setState(() {
      _itemNameController.clear();
      _costPriceController.clear();
      _salePriceController.clear();
      _qtyOnHandController.clear();
      _selectedVendor = null;
    });
  }

  void _showSnackBar(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? _T.red : _T.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void saveOrUpdateItem() async {
    if (_formKey.currentState!.validate()) {
      final itemName = _itemNameController.text;

      if (widget.itemData == null) {
        bool itemExists = await checkIfItemExists(itemName);
        if (itemExists) {
          _showSnackBar('Item with this name already exists!', error: true);
          return;
        }
      }

      final DatabaseReference database = FirebaseDatabase.instance.ref();

      final newItem = {
        'itemName': itemName,
        'unit': 'Pcs',
        'costPrice': double.tryParse(_costPriceController.text) ?? 0.0,
        'salePrice': double.tryParse(_salePriceController.text) ?? 0.0,
        'qtyOnHand': int.tryParse(_qtyOnHandController.text) ?? 0,
        'vendor': _selectedVendor,
        'image': _imageBase64,
        'isBOM': false,
        'createdAt': ServerValue.timestamp,
      };

      if (widget.itemData == null) {
        database.child('items').push().set(newItem).then((_) {
          _showSnackBar('Item registered successfully!');
          _clearFormFields();
        }).catchError((error) {
          print(error);
          _showSnackBar('Failed to register item: $error', error: true);
        });
      } else {
        database.child('items/${widget.itemData!['key']}').set(newItem).then((_) {
          _showSnackBar('Item updated successfully!');
        }).catchError((error) {
          _showSnackBar('Failed to update item: $error', error: true);
        });
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageBase64 != null) {
      return Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _T.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _T.border),
              image: DecorationImage(
                image: kIsWeb
                    ? Image.network('data:image/png;base64,$_imageBase64').image
                    : MemoryImage(base64Decode(_imageBase64!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _removeImage,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _T.red.withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: _T.surface, width: 1.5),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: _T.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, color: _T.textTer, size: 32),
              const SizedBox(height: 8),
              Text(
                'Upload Image',
                style: TextStyle(color: _T.textTer, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: _T.textPri, fontSize: 14),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _T.textSec, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

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
              child: Icon(
                widget.itemData == null ? Icons.add_rounded : Icons.edit_outlined,
                color: _T.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.itemData == null
                  ? (languageProvider.isEnglish ? 'New Item' : 'نیا آئٹم')
                  : (languageProvider.isEnglish ? 'Edit Item' : 'آئٹم میں ترمیم کریں'),
              style: const TextStyle(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image Upload Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _T.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _T.border),
                ),
                child: Column(
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Item Image' : 'آئٹم کی تصویر',
                      style: const TextStyle(
                        color: _T.textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildImagePreview(),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.photo_library_outlined, color: _T.accent, size: 18),
                      label: Text(
                        languageProvider.isEnglish ? 'Choose Image' : 'تصویر منتخب کریں',
                        style: TextStyle(color: _T.accent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Item Details Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _T.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _T.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _T.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          languageProvider.isEnglish ? 'BASIC INFORMATION' : 'بنیادی معلومات',
                          style: const TextStyle(
                            color: _T.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _itemNameController,
                      label: languageProvider.isEnglish ? 'Item Name' : 'آئٹم کا نام',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.isEnglish
                              ? 'Please enter item name'
                              : 'براہ کرم آئٹم کا نام درج کریں';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _costPriceController,
                            label: languageProvider.isEnglish ? 'Cost Price (PKR)' : 'لاگت کی قیمت (روپے)',
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _salePriceController,
                            label: languageProvider.isEnglish ? 'Sale Price (PKR)' : 'فروخت کی قیمت (روپے)',
                            isNumber: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return languageProvider.isEnglish
                                    ? 'Required'
                                    : 'مطلوبہ';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _qtyOnHandController,
                      label: languageProvider.isEnglish ? 'Quantity on Hand (Pcs)' : 'موجود مقدار (پِیس)',
                      isNumber: true,
                      readOnly: widget.itemData != null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.isEnglish
                              ? 'Please enter quantity'
                              : 'براہ کرم مقدار درج کریں';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Vendor Selection Section
              if (_vendors.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _T.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _T.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _T.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            languageProvider.isEnglish ? 'VENDOR INFORMATION' : 'وینڈر کی معلومات',
                            style: const TextStyle(
                              color: _T.textSec,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isLoadingVendors)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        Container(
                          decoration: BoxDecoration(
                            color: _T.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _T.border),
                          ),
                          child: TextField(
                            controller: _vendorSearchController,
                            style: const TextStyle(color: _T.textPri, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: languageProvider.isEnglish
                                  ? 'Search vendor...'
                                  : 'وینڈر تلاش کریں...',
                              hintStyle: TextStyle(color: _T.textTer, fontSize: 13),
                              prefixIcon: Icon(Icons.search, color: _T.textTer, size: 18),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_vendorSearchController.text.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: _T.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _T.border),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredVendors.length,
                              itemBuilder: (context, index) {
                                final vendor = _filteredVendors[index];
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedVendor = vendor;
                                      _vendorSearchController.clear();
                                      _filteredVendors = List.from(_vendors);
                                    });
                                    _showSnackBar(
                                      '${languageProvider.isEnglish ? 'Selected: ' : 'منتخب: '}$vendor',
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Text(
                                      vendor,
                                      style: const TextStyle(color: _T.textPri, fontSize: 13),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (_selectedVendor != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _T.accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _T.accent.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: _T.accent, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedVendor!,
                                    style: const TextStyle(color: _T.textPri, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saveOrUpdateItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.itemData == null
                        ? (languageProvider.isEnglish ? 'Create Item' : 'آئٹم بنائیں')
                        : (languageProvider.isEnglish ? 'Update Item' : 'آئٹم اپ ڈیٹ کریں'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _qtyOnHandController.dispose();
    _vendorSearchController.dispose();
    super.dispose();
  }
}