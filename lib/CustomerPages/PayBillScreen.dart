// // BillPages/PayBillScreen.dart
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import '../Models/bill_model.dart';
//
// class PayBillScreen extends StatefulWidget {
//   final BillModel bill;
//   final String? teamId;
//   final String? teamName;
//
//   const PayBillScreen({
//     super.key,
//     required this.bill,
//     this.teamId,
//     this.teamName,
//   });
//
//   @override
//   State<PayBillScreen> createState() => _PayBillScreenState();
// }
//
// class _PayBillScreenState extends State<PayBillScreen> {
//   final DatabaseReference _billsRef = FirebaseDatabase.instance.ref().child('bills');
//   final _formKey = GlobalKey<FormState>();
//   bool _isProcessing = false;
//
//   // Payment details
//   late double _remainingBalance;
//   late double _amountToPay;
//   String _selectedPaymentMethod = 'Cash';
//   String? _paymentReference;
//   DateTime _paymentDate = DateTime.now();
//   bool _applyDiscount = false;
//   double _discountAmount = 0.0;
//   String _discountReason = '';
//
//   // Payment methods
//   final List<String> _paymentMethods = [
//     'Cash',
//     'Credit Card',
//     'Debit Card',
//     'Bank Transfer',
//     'Check',
//     'Online Payment',
//     'Other'
//   ];
//
//   // Premium color palette
//   static const Color _deepPurple = Color(0xFF6B4EFF);
//   static const Color _electricIndigo = Color(0xFF4A3AFF);
//   static const Color _royalBlue = Color(0xFF2563EB);
//   static const Color _skyBlue = Color(0xFF38BDF8);
//   static const Color _emeraldGreen = Color(0xFF10B981);
//   static const Color _amberGlow = Color(0xFFF59E0B);
//   static const Color _crimsonRed = Color(0xFFEF4444);
//   static const Color _darkNavy = Color(0xFF0B1120);
//   static const Color _slateGray = Color(0xFF1E293B);
//   static const Color _charcoalBlue = Color(0xFF0F172A);
//   static const Color _steelGray = Color(0xFF334155);
//   static const Color _pearlWhite = Color(0xFFF8FAFC);
//
//   @override
//   void initState() {
//     super.initState();
//     _remainingBalance = widget.bill.balanceDue;
//     _amountToPay = _remainingBalance; // Default to full payment
//   }
//
//   Future<void> _processPayment() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     if (_amountToPay <= 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Payment amount must be greater than 0'),
//           backgroundColor: _crimsonRed,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//       return;
//     }
//
//     if (_amountToPay > _remainingBalance) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Payment amount cannot exceed remaining balance'),
//           backgroundColor: _crimsonRed,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//       return;
//     }
//
//     // Validate discount if applied
//     if (_applyDiscount) {
//       if (_discountAmount <= 0) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Discount amount must be greater than 0'),
//             backgroundColor: _crimsonRed,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         );
//         return;
//       }
//
//       if (_discountAmount > _amountToPay) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Discount cannot exceed payment amount'),
//             backgroundColor: _crimsonRed,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         );
//         return;
//       }
//     }
//
//     // Show confirmation dialog
//     bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: _charcoalBlue,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
//         title: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: _emeraldGreen.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Icon(Icons.payment_rounded, color: _emeraldGreen, size: 24),
//             ),
//             const SizedBox(width: 12),
//             const Text(
//               'Confirm Payment',
//               style: TextStyle(color: _pearlWhite, fontSize: 18, fontWeight: FontWeight.w600),
//             ),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: _slateGray,
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Column(
//                 children: [
//                   _buildConfirmRow('Bill Number', widget.bill.billNumber),
//                   const SizedBox(height: 12),
//                   _buildConfirmRow('Payment Amount', '\$${_amountToPay.toStringAsFixed(2)}'),
//                   if (_applyDiscount && _discountAmount > 0) ...[
//                     const SizedBox(height: 8),
//                     _buildConfirmRow('Discount Applied', '-\$${_discountAmount.toStringAsFixed(2)}'),
//                   ],
//                   const SizedBox(height: 8),
//                   Divider(color: _pearlWhite.withOpacity(0.2)),
//                   const SizedBox(height: 8),
//                   _buildConfirmRow(
//                     'New Balance',
//                     '\$${(_remainingBalance - _amountToPay - (_applyDiscount ? _discountAmount : 0)).toStringAsFixed(2)}',
//                     isBold: true,
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Payment Method: $_selectedPaymentMethod',
//               style: TextStyle(color: _pearlWhite.withOpacity(0.9), fontSize: 14),
//             ),
//             if (_paymentReference != null && _paymentReference!.isNotEmpty) ...[
//               const SizedBox(height: 8),
//               Text(
//                 'Reference: $_paymentReference',
//                 style: TextStyle(color: _pearlWhite.withOpacity(0.7), fontSize: 13),
//               ),
//             ],
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             style: TextButton.styleFrom(
//               foregroundColor: _pearlWhite.withOpacity(0.7),
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//             ),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _emeraldGreen,
//               foregroundColor: _pearlWhite,
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             ),
//             child: const Text('Confirm Payment'),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm != true) {
//       setState(() => _isProcessing = false);
//       return;
//     }
//
//     setState(() => _isProcessing = true);
//
//     try {
//       final User? currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) throw Exception('User not authenticated');
//
//       // Get user details from database
//       DatabaseEvent userEvent = await FirebaseDatabase.instance
//           .ref()
//           .child('users')
//           .child(currentUser.uid)
//           .once();
//
//       String processedByName = 'Unknown';
//       if (userEvent.snapshot.value != null) {
//         Map<String, dynamic> userData = Map<String, dynamic>.from(
//           userEvent.snapshot.value as Map,
//         );
//         processedByName = userData['name'] ?? userData['email'] ?? 'Unknown';
//       }
//
//       // Calculate new values
//       double newAmountPaid = widget.bill.amountPaid + _amountToPay;
//       double effectiveDiscount = _applyDiscount ? _discountAmount : 0.0;
//       double newGrandTotal = widget.bill.grandTotal - effectiveDiscount;
//       double newBalanceDue = newGrandTotal - newAmountPaid;
//
//       // Determine payment status
//       String newPaymentStatus;
//       if (newBalanceDue <= 0.01) { // Handle floating point precision
//         newPaymentStatus = 'Paid';
//         newBalanceDue = 0.0;
//       } else if (newAmountPaid > 0) {
//         newPaymentStatus = 'Partial';
//       } else {
//         newPaymentStatus = 'Unpaid';
//       }
//
//       // Prepare update data
//       Map<String, dynamic> updateData = {
//         'amountPaid': newAmountPaid,
//         'balanceDue': newBalanceDue,
//         'paymentStatus': newPaymentStatus,
//         'paymentMethod': _selectedPaymentMethod,
//         'paymentDate': _paymentDate.toIso8601String(),
//         'updatedAt': DateTime.now().toIso8601String(),
//         'lastPayment': {
//           'amount': _amountToPay,
//           'date': _paymentDate.toIso8601String(),
//           'method': _selectedPaymentMethod,
//           'reference': _paymentReference,
//           'processedBy': currentUser.uid,
//           'processedByName': processedByName,
//         },
//       };
//
//       // If discount applied, update grand total and discount fields
//       if (_applyDiscount && _discountAmount > 0) {
//         updateData.addAll({
//           'grandDiscountType': 'amount',
//           'grandDiscountValue': widget.bill.grandDiscountValue + _discountAmount,
//           'grandDiscountAmount': widget.bill.grandDiscountAmount + _discountAmount,
//           'grandTotal': newGrandTotal,
//           'discountHistory': [
//             ...?widget.bill.toMap()['discountHistory'],
//             {
//               'amount': _discountAmount,
//               'reason': _discountReason,
//               'date': DateTime.now().toIso8601String(),
//               'appliedBy': currentUser.uid,
//               'appliedByName': processedByName,
//             }
//           ],
//         });
//       }
//
//       // Update in Firebase
//       await _billsRef.child(widget.bill.id).update(updateData);
//
//       // Save payment history (optional - create payments node)
//       try {
//         DatabaseReference paymentsRef = FirebaseDatabase.instance.ref().child('payments');
//         String paymentId = paymentsRef.push().key!;
//
//         Map<String, dynamic> paymentRecord = {
//           'id': paymentId,
//           'billId': widget.bill.id,
//           'billNumber': widget.bill.billNumber,
//           'amount': _amountToPay,
//           'discountApplied': effectiveDiscount,
//           'discountReason': _discountReason,
//           'paymentDate': _paymentDate.toIso8601String(),
//           'paymentMethod': _selectedPaymentMethod,
//           'reference': _paymentReference,
//           'processedBy': currentUser.uid,
//           'processedByName': processedByName,
//           'teamId': widget.teamId,
//           'teamName': widget.teamName,
//           'createdAt': DateTime.now().toIso8601String(),
//         };
//
//         await paymentsRef.child(paymentId).set(paymentRecord);
//       } catch (e) {
//         debugPrint('Error saving payment history: $e');
//         // Don't fail the main transaction if history save fails
//       }
//
//       if (mounted) {
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(4),
//                   decoration: BoxDecoration(
//                     color: _pearlWhite.withOpacity(0.2),
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(Icons.check_rounded, color: _pearlWhite, size: 18),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         _applyDiscount && _discountAmount > 0
//                             ? 'Payment processed with discount!'
//                             : 'Payment processed successfully!',
//                         style: const TextStyle(color: _pearlWhite, fontWeight: FontWeight.w600),
//                       ),
//                       Text(
//                         'New balance: \$${newBalanceDue.toStringAsFixed(2)}',
//                         style: const TextStyle(color: _pearlWhite, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             backgroundColor: _emeraldGreen,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             margin: const EdgeInsets.all(16),
//             duration: const Duration(seconds: 4),
//           ),
//         );
//
//         // Return true to indicate success
//         Navigator.pop(context, true);
//       }
//     } catch (e) {
//       debugPrint('Payment processing error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 const Icon(Icons.error_outline_rounded, color: _pearlWhite),
//                 const SizedBox(width: 12),
//                 Expanded(child: Text('Error processing payment: $e')),
//               ],
//             ),
//             backgroundColor: _crimsonRed,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             margin: const EdgeInsets.all(16),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isProcessing = false);
//       }
//     }
//   }
//
// // Helper method for confirmation dialog
//   Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             color: _pearlWhite.withOpacity(0.7),
//             fontSize: isBold ? 14 : 13,
//           ),
//         ),
//         Text(
//           value,
//           style: TextStyle(
//             color: _pearlWhite,
//             fontSize: isBold ? 16 : 14,
//             fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }
//
//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year}';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _darkNavy,
//       appBar: AppBar(
//         backgroundColor: _charcoalBlue,
//         elevation: 0,
//         leading: IconButton(
//           icon: Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: _slateGray,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: const Icon(Icons.arrow_back_rounded, color: _pearlWhite, size: 20),
//           ),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [_emeraldGreen, _deepPurple],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Icon(Icons.payment_rounded, color: _pearlWhite, size: 24),
//             ),
//             const SizedBox(width: 12),
//             const Text(
//               'Process Payment',
//               style: TextStyle(color: _pearlWhite, fontSize: 20, fontWeight: FontWeight.w600),
//             ),
//           ],
//         ),
//       ),
//       body: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           physics: const BouncingScrollPhysics(),
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Bill Summary Card
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [_charcoalBlue, _charcoalBlue.withOpacity(0.8)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: Colors.white.withOpacity(0.05)),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: _skyBlue.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: const Icon(Icons.receipt_rounded, color: _skyBlue, size: 20),
//                         ),
//                         const SizedBox(width: 12),
//                         const Text(
//                           'Bill Summary',
//                           style: TextStyle(color: _pearlWhite, fontSize: 16, fontWeight: FontWeight.w600),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//
//                     // Bill details
//                     _buildInfoRow('Bill Number', widget.bill.billNumber, Icons.numbers_rounded, _deepPurple),
//                     const SizedBox(height: 12),
//                     _buildInfoRow('Customer', widget.bill.customerName, Icons.person_rounded, _skyBlue),
//                     const SizedBox(height: 12),
//
//                     // Amounts
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: _slateGray,
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: Column(
//                         children: [
//                           _buildAmountRow('Grand Total', widget.bill.grandTotal, _pearlWhite),
//                           const SizedBox(height: 8),
//                           _buildAmountRow('Already Paid', widget.bill.amountPaid, _emeraldGreen),
//                           const SizedBox(height: 8),
//                           Divider(color: _pearlWhite.withOpacity(0.2)),
//                           const SizedBox(height: 8),
//                           _buildAmountRow('Balance Due', _remainingBalance, _amberGlow, isBold: true),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//
//               // Payment Details Card
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [_charcoalBlue, _charcoalBlue.withOpacity(0.8)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: Colors.white.withOpacity(0.05)),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: _emeraldGreen.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: const Icon(Icons.payment_rounded, color: _emeraldGreen, size: 20),
//                         ),
//                         const SizedBox(width: 12),
//                         const Text(
//                           'Payment Details',
//                           style: TextStyle(color: _pearlWhite, fontSize: 16, fontWeight: FontWeight.w600),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//
//                     // Payment Amount
//                     TextFormField(
//                       style: const TextStyle(color: _pearlWhite),
//                       decoration: InputDecoration(
//                         labelText: 'Payment Amount',
//                         labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
//                         prefixIcon: Icon(Icons.attach_money_rounded, color: _emeraldGreen),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: const BorderSide(color: _emeraldGreen),
//                         ),
//                         filled: true,
//                         fillColor: _slateGray,
//                       ),
//                       keyboardType: TextInputType.number,
//                       initialValue: _amountToPay.toStringAsFixed(2),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter payment amount';
//                         }
//                         double? amount = double.tryParse(value);
//                         if (amount == null) {
//                           return 'Please enter a valid number';
//                         }
//                         if (amount <= 0) {
//                           return 'Amount must be greater than 0';
//                         }
//                         if (amount > _remainingBalance) {
//                           return 'Amount cannot exceed remaining balance';
//                         }
//                         return null;
//                       },
//                       onChanged: (value) {
//                         double? amount = double.tryParse(value);
//                         if (amount != null) {
//                           setState(() => _amountToPay = amount);
//                         }
//                       },
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     // Quick amount buttons
//                     SingleChildScrollView(
//                       scrollDirection: Axis.horizontal,
//                       child: Row(
//                         children: [
//                           _buildQuickAmountButton('Full', _remainingBalance),
//                           const SizedBox(width: 8),
//                           _buildQuickAmountButton('Half', _remainingBalance / 2),
//                           const SizedBox(width: 8),
//                           _buildQuickAmountButton('25%', _remainingBalance * 0.25),
//                           const SizedBox(width: 8),
//                           _buildQuickAmountButton('10%', _remainingBalance * 0.1),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     // Payment Method
//                     DropdownButtonFormField<String>(
//                       value: _selectedPaymentMethod,
//                       style: const TextStyle(color: _pearlWhite),
//                       dropdownColor: _charcoalBlue,
//                       decoration: InputDecoration(
//                         labelText: 'Payment Method',
//                         labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
//                         prefixIcon: Icon(Icons.credit_card_rounded, color: _amberGlow),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: const BorderSide(color: _amberGlow),
//                         ),
//                         filled: true,
//                         fillColor: _slateGray,
//                       ),
//                       items: _paymentMethods.map((method) {
//                         return DropdownMenuItem(
//                           value: method,
//                           child: Text(method),
//                         );
//                       }).toList(),
//                       onChanged: (value) {
//                         setState(() => _selectedPaymentMethod = value!);
//                       },
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     // Payment Reference (optional)
//                     TextFormField(
//                       style: const TextStyle(color: _pearlWhite),
//                       decoration: InputDecoration(
//                         labelText: 'Reference / Transaction ID (Optional)',
//                         labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
//                         prefixIcon: Icon(Icons.receipt_rounded, color: _skyBlue),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: const BorderSide(color: _skyBlue),
//                         ),
//                         filled: true,
//                         fillColor: _slateGray,
//                       ),
//                       onChanged: (value) => _paymentReference = value,
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     // Payment Date
//                     InkWell(
//                       onTap: () async {
//                         DateTime? picked = await showDatePicker(
//                           context: context,
//                           initialDate: _paymentDate,
//                           firstDate: DateTime.now().subtract(const Duration(days: 30)),
//                           lastDate: DateTime.now(),
//                           builder: (context, child) {
//                             return Theme(
//                               data: ThemeData.dark().copyWith(
//                                 colorScheme: const ColorScheme.dark(
//                                   primary: _deepPurple,
//                                   onPrimary: _pearlWhite,
//                                   surface: _charcoalBlue,
//                                   onSurface: _pearlWhite,
//                                 ),
//                               ),
//                               child: child!,
//                             );
//                           },
//                         );
//                         if (picked != null) {
//                           setState(() => _paymentDate = picked);
//                         }
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//                         decoration: BoxDecoration(
//                           color: _slateGray,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: _pearlWhite.withOpacity(0.1)),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.calendar_today_rounded, color: _deepPurple, size: 20),
//                             const SizedBox(width: 12),
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Payment Date',
//                                   style: TextStyle(
//                                     color: _pearlWhite.withOpacity(0.7),
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 Text(
//                                   _formatDate(_paymentDate),
//                                   style: const TextStyle(
//                                     color: _pearlWhite,
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//
//               // Discount Section
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [_charcoalBlue, _charcoalBlue.withOpacity(0.8)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(
//                     color: _applyDiscount ? _amberGlow.withOpacity(0.3) : Colors.white.withOpacity(0.05),
//                   ),
//                 ),
//                 child: Column(
//                   children: [
//                     // Discount toggle
//                     SwitchListTile(
//                       title: Row(
//                         children: [
//                           Icon(Icons.discount_rounded, color: _applyDiscount ? _amberGlow : _pearlWhite.withOpacity(0.5)),
//                           const SizedBox(width: 12),
//                           const Text(
//                             'Apply Discount',
//                             style: TextStyle(color: _pearlWhite, fontSize: 16, fontWeight: FontWeight.w600),
//                           ),
//                         ],
//                       ),
//                       value: _applyDiscount,
//                       activeColor: _amberGlow,
//                       onChanged: (value) {
//                         setState(() => _applyDiscount = value);
//                       },
//                     ),
//
//                     if (_applyDiscount) ...[
//                       const SizedBox(height: 16),
//
//                       // Discount amount
//                       TextFormField(
//                         style: const TextStyle(color: _pearlWhite),
//                         decoration: InputDecoration(
//                           labelText: 'Discount Amount',
//                           labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
//                           prefixIcon: Icon(Icons.discount_rounded, color: _amberGlow),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: const BorderSide(color: _amberGlow),
//                           ),
//                           filled: true,
//                           fillColor: _slateGray,
//                         ),
//                         keyboardType: TextInputType.number,
//                         initialValue: _discountAmount.toString(),
//                         onChanged: (value) {
//                           double? amount = double.tryParse(value);
//                           if (amount != null) {
//                             setState(() => _discountAmount = amount);
//                           }
//                         },
//                       ),
//
//                       const SizedBox(height: 12),
//
//                       // Discount reason
//                       TextFormField(
//                         style: const TextStyle(color: _pearlWhite),
//                         decoration: InputDecoration(
//                           labelText: 'Discount Reason (Optional)',
//                           labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
//                           prefixIcon: Icon(Icons.note_rounded, color: _skyBlue),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: const BorderSide(color: _skyBlue),
//                           ),
//                           filled: true,
//                           fillColor: _slateGray,
//                         ),
//                         onChanged: (value) => _discountReason = value,
//                       ),
//
//                       if (_discountAmount > 0) ...[
//                         const SizedBox(height: 12),
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: _amberGlow.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(color: _amberGlow.withOpacity(0.3)),
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text(
//                                 'New Balance After Discount:',
//                                 style: TextStyle(color: _pearlWhite, fontSize: 13),
//                               ),
//                               Text(
//                                 '\$${(_remainingBalance - _discountAmount - _amountToPay).toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                   color: _amberGlow,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ],
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 30),
//
//               // Action Buttons
//               Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton(
//                       onPressed: _isProcessing ? null : () => Navigator.pop(context),
//                       style: OutlinedButton.styleFrom(
//                         foregroundColor: _pearlWhite,
//                         side: BorderSide(color: _pearlWhite.withOpacity(0.3)),
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                       ),
//                       child: const Text('Cancel'),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: _isProcessing ? null : _processPayment,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: _emeraldGreen,
//                         foregroundColor: _pearlWhite,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                       ),
//                       child: _isProcessing
//                           ? const SizedBox(
//                         height: 20,
//                         width: 20,
//                         child: CircularProgressIndicator(color: _pearlWhite, strokeWidth: 2),
//                       )
//                           : const Text('Process Payment'),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
//     return Row(
//       children: [
//         Icon(icon, size: 16, color: color),
//         const SizedBox(width: 8),
//         Text(
//           '$label: ',
//           style: TextStyle(color: _pearlWhite.withOpacity(0.6), fontSize: 13),
//         ),
//         Expanded(
//           child: Text(
//             value,
//             style: const TextStyle(color: _pearlWhite, fontSize: 13, fontWeight: FontWeight.w600),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildAmountRow(String label, double amount, Color color, {bool isBold = false}) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             color: _pearlWhite.withOpacity(0.7),
//             fontSize: isBold ? 15 : 13,
//             fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
//           ),
//         ),
//         Text(
//           '\$${amount.toStringAsFixed(2)}',
//           style: TextStyle(
//             color: color,
//             fontSize: isBold ? 18 : 15,
//             fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildQuickAmountButton(String label, double amount) {
//     return MaterialButton(
//       onPressed: () {
//         setState(() {
//           _amountToPay = amount;
//         });
//       },
//       color: _slateGray,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//       child: Column(
//         children: [
//           Text(
//             label,
//             style: TextStyle(color: _pearlWhite.withOpacity(0.7), fontSize: 11),
//           ),
//           Text(
//             '\$${amount.toStringAsFixed(2)}',
//             style: const TextStyle(color: _emeraldGreen, fontSize: 13, fontWeight: FontWeight.w600),
//           ),
//         ],
//       ),
//     );
//   }
// }

// BillPages/PayBillScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../Models/bill_model.dart';
import '../BankManagement/banktransactionpage.dart'; // Adjust import path as needed
import '../CashBook/cashbookform.dart';
import '../Models/cashbookModel.dart';
import '../bankmanagement/addbank.dart';
import '../lanprovider.dart';

class PayBillScreen extends StatefulWidget {
  final BillModel bill;
  final String? teamId;
  final String? teamName;

  const PayBillScreen({
    super.key,
    required this.bill,
    this.teamId,
    this.teamName,
  });

  @override
  State<PayBillScreen> createState() => _PayBillScreenState();
}

class _PayBillScreenState extends State<PayBillScreen> {
  final DatabaseReference _billsRef = FirebaseDatabase.instance.ref().child('bills');
  final DatabaseReference _banksRef = FirebaseDatabase.instance.ref().child('banks');
  final DatabaseReference _cashbookRef = FirebaseDatabase.instance.ref().child('cashbook');
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  // Payment details
  late double _remainingBalance;
  late double _amountToPay;
  String _selectedPaymentMethod = 'Cash';
  String? _paymentReference;
  DateTime _paymentDate = DateTime.now();
  bool _applyDiscount = false;
  double _discountAmount = 0.0;
  String _discountReason = '';

  // Bank selection
  String? _selectedBankId;
  String? _selectedBankName;
  Map<String, dynamic> _bankDetails = {};
  bool _isLoadingBanks = false;

  // Payment methods with icons
  final List<Map<String, dynamic>> _paymentMethods = [
    {'name': 'Cash', 'icon': Icons.money_rounded, 'color': Color(0xFF10B981)},
    {'name': 'Bank Transfer', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF6B4EFF)},
    {'name': 'Credit Card', 'icon': Icons.credit_card_rounded, 'color': Color(0xFF2563EB)},
    {'name': 'Debit Card', 'icon': Icons.credit_card_rounded, 'color': Color(0xFF38BDF8)},
    {'name': 'Check', 'icon': Icons.receipt_rounded, 'color': Color(0xFFF59E0B)},
    {'name': 'Online Payment', 'icon': Icons.payment_rounded, 'color': Color(0xFF10B981)},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Color(0xFF6B7280)},
  ];

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
    _remainingBalance = widget.bill.balanceDue;
    _amountToPay = _remainingBalance;
  }

  // Update these methods in your PayBillScreen

  Future<bool> _processBankTransaction(double amount) async {
    if (_selectedBankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a bank'),
          backgroundColor: _crimsonRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }

    try {
      // Get current bank balance
      final bankSnapshot = await _banksRef.child(_selectedBankId!).get();
      if (!bankSnapshot.exists) {
        throw Exception('Bank not found');
      }

      final bankData = Map<String, dynamic>.from(bankSnapshot.value as Map);
      double currentBalance = (bankData['balance'] as num?)?.toDouble() ?? 0;

      // For customer payments, it's always cash_in (money coming into the bank)
      // No need to check for sufficient balance since we're adding money

      // Create transaction
      final transaction = {
        'amount': amount,
        'description': 'Bill Payment Received - ${widget.bill.billNumber} - ${widget.bill.customerName}',
        'type': 'cash_in', // Changed to cash_in for receiving payments
        'timestamp': _paymentDate.millisecondsSinceEpoch,
        'reference': _paymentReference,
        'billId': widget.bill.id,
        'billNumber': widget.bill.billNumber,
        'customerName': widget.bill.customerName,
      };

      // Add to bank transactions
      await _banksRef
          .child(_selectedBankId!)
          .child('transactions')
          .push()
          .set(transaction);

      // Update bank balance (adding money)
      double newBalance = currentBalance + amount; // Adding money for cash_in

      await _banksRef.child(_selectedBankId!).child('balance').set(newBalance);

      return true;
    } catch (e) {
      debugPrint('Bank transaction error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bank transaction failed: $e'),
          backgroundColor: _crimsonRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<bool> _processCashTransaction(double amount) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get user details
      DatabaseEvent userEvent = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .once();

      String processedByName = 'Unknown';
      if (userEvent.snapshot.value != null) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(
          userEvent.snapshot.value as Map,
        );
        processedByName = userData['name'] ?? userData['email'] ?? 'Unknown';
      }

      // Create cashbook entry for cash payment received
      final entry = CashbookEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: 'Bill Payment Received - ${widget.bill.billNumber} - ${widget.bill.customerName}',
        amount: amount,
        dateTime: _paymentDate,
        type: 'cash_in', // Always cash_in for customer payments
      );

      // Save to cashbook with additional info
      Map<String, dynamic> paymentRecord = {
        ...entry.toJson(),
        'billId': widget.bill.id,
        'billNumber': widget.bill.billNumber,
        'customerName': widget.bill.customerName,
        'paymentMethod': _selectedPaymentMethod,
        'reference': _paymentReference,
        'processedBy': currentUser.uid,
        'processedByName': processedByName,
        'teamId': widget.teamId,
        'teamName': widget.teamName,
      };

      await _cashbookRef.child(entry.id!).set(paymentRecord);

      return true;
    } catch (e) {
      debugPrint('Cash transaction error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cash transaction failed: $e'),
          backgroundColor: _crimsonRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

// Update the _processPayment method to use the updated functions
  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_amountToPay <= 0) {
      _showErrorSnackBar('Payment amount must be greater than 0');
      return;
    }

    if (_amountToPay > _remainingBalance) {
      _showErrorSnackBar('Payment amount cannot exceed remaining balance');
      return;
    }

    // Validate discount if applied
    if (_applyDiscount) {
      if (_discountAmount <= 0) {
        _showErrorSnackBar('Discount amount must be greater than 0');
        return;
      }
      if (_discountAmount > _amountToPay) {
        _showErrorSnackBar('Discount cannot exceed payment amount');
        return;
      }
    }

    // Validate bank selection if payment method involves bank
    if (_selectedPaymentMethod == 'Bank Transfer' && _selectedBankId == null) {
      _showErrorSnackBar('Please select a bank for transfer');
      return;
    }

    // Show confirmation dialog
    bool? confirm = await _showConfirmationDialog();
    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      // Process based on payment method
      bool transactionSuccess = false;

      if (_selectedPaymentMethod == 'Cash') {
        transactionSuccess = await _processCashTransaction(_amountToPay);
      } else if (_selectedPaymentMethod == 'Bank Transfer') {
        transactionSuccess = await _processBankTransaction(_amountToPay);
      }
      // Add other payment methods as needed

      if (!transactionSuccess) {
        setState(() => _isProcessing = false);
        return;
      }

      // Update bill in Firebase
      await _updateBillInFirebase();

      if (mounted) {
        _showSuccessSnackBar();
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Payment processing error: $e');
      if (mounted) {
        _showErrorSnackBar('Error processing payment: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _loadBanks() async {
    setState(() => _isLoadingBanks = true);
    try {
      final snapshot = await _banksRef.get();
      if (snapshot.value != null) {
        final banks = Map<String, dynamic>.from(snapshot.value as Map);
        // Store banks for selection
        _bankDetails = banks;
      }
    } catch (e) {
      debugPrint('Error loading banks: $e');
    } finally {
      setState(() => _isLoadingBanks = false);
    }
  }

  Future<void> _updateBillInFirebase() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    // Get user details
    DatabaseEvent userEvent = await FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(currentUser.uid)
        .once();

    String processedByName = 'Unknown';
    if (userEvent.snapshot.value != null) {
      Map<String, dynamic> userData = Map<String, dynamic>.from(
        userEvent.snapshot.value as Map,
      );
      processedByName = userData['name'] ?? userData['email'] ?? 'Unknown';
    }

    // Calculate new values
    double newAmountPaid = widget.bill.amountPaid + _amountToPay;
    double effectiveDiscount = _applyDiscount ? _discountAmount : 0.0;
    double newGrandTotal = widget.bill.grandTotal - effectiveDiscount;
    double newBalanceDue = newGrandTotal - newAmountPaid;

    // Determine payment status
    String newPaymentStatus;
    if (newBalanceDue <= 0.01) {
      newPaymentStatus = 'Paid';
      newBalanceDue = 0.0;
    } else if (newAmountPaid > 0) {
      newPaymentStatus = 'Partial';
    } else {
      newPaymentStatus = 'Unpaid';
    }

    // Prepare update data
    Map<String, dynamic> updateData = {
      'amountPaid': newAmountPaid,
      'balanceDue': newBalanceDue,
      'paymentStatus': newPaymentStatus,
      'paymentMethod': _selectedPaymentMethod,
      'paymentDate': _paymentDate.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'lastPayment': {
        'amount': _amountToPay,
        'date': _paymentDate.toIso8601String(),
        'method': _selectedPaymentMethod,
        'reference': _paymentReference,
        'processedBy': currentUser.uid,
        'processedByName': processedByName,
        'bankId': _selectedPaymentMethod == 'Bank Transfer' ? _selectedBankId : null,
        'bankName': _selectedPaymentMethod == 'Bank Transfer' ? _selectedBankName : null,
      },
    };

    // If discount applied
    if (_applyDiscount && _discountAmount > 0) {
      updateData.addAll({
        'grandDiscountType': 'amount',
        'grandDiscountValue': (widget.bill.grandDiscountValue ?? 0) + _discountAmount,
        'grandDiscountAmount': (widget.bill.grandDiscountAmount ?? 0) + _discountAmount,
        'grandTotal': newGrandTotal,
      });
    }

    await _billsRef.child(widget.bill.id).update(updateData);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: _pearlWhite),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _crimsonRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar() {
    double newBalance = _remainingBalance - _amountToPay - (_applyDiscount ? _discountAmount : 0);
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
              child: const Icon(Icons.check_rounded, color: _pearlWhite, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _applyDiscount && _discountAmount > 0
                        ? 'Payment processed with discount!'
                        : 'Payment processed successfully!',
                    style: const TextStyle(color: _pearlWhite, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'New balance: \$${newBalance.toStringAsFixed(2)}',
                    style: const TextStyle(color: _pearlWhite, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _emeraldGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emeraldGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payment_rounded, color: _emeraldGreen, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Payment',
              style: TextStyle(color: _pearlWhite, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildConfirmRow('Bill Number', widget.bill.billNumber),
                  const SizedBox(height: 12),
                  _buildConfirmRow('Customer', widget.bill.customerName),
                  const SizedBox(height: 12),
                  _buildConfirmRow('Payment Amount', '\$${_amountToPay.toStringAsFixed(2)}'),
                  if (_applyDiscount && _discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildConfirmRow('Discount Applied', '-\$${_discountAmount.toStringAsFixed(2)}'),
                  ],
                  const SizedBox(height: 8),
                  Divider(color: _pearlWhite.withOpacity(0.2)),
                  const SizedBox(height: 8),
                  _buildConfirmRow(
                    'New Balance',
                    '\$${(_remainingBalance - _amountToPay - (_applyDiscount ? _discountAmount : 0)).toStringAsFixed(2)}',
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedPaymentMethod == 'Bank Transfer'
                    ? _deepPurple.withOpacity(0.1)
                    : _emeraldGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedPaymentMethod == 'Bank Transfer'
                        ? Icons.account_balance_rounded
                        : Icons.money_rounded,
                    color: _selectedPaymentMethod == 'Bank Transfer' ? _deepPurple : _emeraldGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method: $_selectedPaymentMethod',
                          style: TextStyle(color: _pearlWhite, fontSize: 14),
                        ),
                        if (_selectedBankName != null)
                          Text(
                            'Bank: $_selectedBankName',
                            style: TextStyle(color: _pearlWhite.withOpacity(0.7), fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_paymentReference != null && _paymentReference!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reference: $_paymentReference',
                style: TextStyle(color: _pearlWhite.withOpacity(0.7), fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _pearlWhite.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _emeraldGreen,
              foregroundColor: _pearlWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _pearlWhite.withOpacity(0.7),
            fontSize: isBold ? 14 : 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: _pearlWhite,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectBank() async {
    await _loadBanks();

    if (_bankDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No banks found. Please add a bank first.'),
          backgroundColor: _amberGlow,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Add Bank',
            textColor: _pearlWhite,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BankManagementPage(),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _charcoalBlue,
      isScrollControlled: true, // Added for better control
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          // Set max height to 70% of screen height
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Fixed at top
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: _deepPurple),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Bank',
                    style: TextStyle(
                      color: _pearlWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BankManagementPage(),
                        ),
                      );
                    },
                    child: const Text('Add Bank'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable content
              if (_isLoadingBanks)
                const Center(child: CircularProgressIndicator())
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _bankDetails.length,
                    itemBuilder: (context, index) {
                      final entry = _bankDetails.entries.elementAt(index);
                      final bankData = Map<String, dynamic>.from(entry.value as Map);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _deepPurple.withOpacity(0.1),
                          child: Text(
                            bankData['name'][0],
                            style: const TextStyle(
                              color: _deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          bankData['name'],
                          style: const TextStyle(color: _pearlWhite),
                        ),
                        subtitle: Text(
                          'Balance: ${bankData['balance'] ?? 0} Rs',
                          style: TextStyle(color: _pearlWhite.withOpacity(0.7)),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedBankId = entry.key;
                            _selectedBankName = bankData['name'];
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
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
            child: const Icon(Icons.arrow_back_rounded, color: _pearlWhite, size: 20),
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
              child: const Icon(Icons.payment_rounded, color: _pearlWhite, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Process Payment',
              style: TextStyle(color: _pearlWhite, fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bill Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_charcoalBlue, _charcoalBlue.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                          child: const Icon(Icons.receipt_rounded, color: _skyBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Bill Summary',
                          style: TextStyle(color: _pearlWhite, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildInfoRow('Bill Number', widget.bill.billNumber, Icons.numbers_rounded, _deepPurple),
                    const SizedBox(height: 12),
                    _buildInfoRow('Customer', widget.bill.customerName, Icons.person_rounded, _skyBlue),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildAmountRow('Grand Total', widget.bill.grandTotal, _pearlWhite),
                          const SizedBox(height: 8),
                          _buildAmountRow('Already Paid', widget.bill.amountPaid, _emeraldGreen),
                          const SizedBox(height: 8),
                          Divider(color: _pearlWhite.withOpacity(0.2)),
                          const SizedBox(height: 8),
                          _buildAmountRow('Balance Due', _remainingBalance, _amberGlow, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Payment Method Selection
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_charcoalBlue, _charcoalBlue.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                          child: const Icon(Icons.payment_rounded, color: _amberGlow, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Payment Method',
                          style: TextStyle(color: _pearlWhite, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payment method chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _paymentMethods.map((method) {
                        bool isSelected = _selectedPaymentMethod == method['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPaymentMethod = method['name'];
                              if (_selectedPaymentMethod != 'Bank Transfer') {
                                _selectedBankId = null;
                                _selectedBankName = null;
                              }
                            });
                            if (_selectedPaymentMethod == 'Bank Transfer') {
                              _selectBank();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? method['color'].withOpacity(0.2)
                                  : _slateGray,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected
                                    ? method['color']
                                    : _pearlWhite.withOpacity(0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  method['icon'],
                                  color: isSelected ? method['color'] : _pearlWhite.withOpacity(0.5),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  method['name'],
                                  style: TextStyle(
                                    color: isSelected ? method['color'] : _pearlWhite.withOpacity(0.7),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (_selectedPaymentMethod == 'Bank Transfer' && _selectedBankName != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _deepPurple.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, color: _deepPurple),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Bank',
                                    style: TextStyle(
                                      color: _pearlWhite.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _selectedBankName!,
                                    style: const TextStyle(
                                      color: _pearlWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: _deepPurple),
                              onPressed: _selectBank,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Payment Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_charcoalBlue, _charcoalBlue.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                          child: const Icon(Icons.payment_rounded, color: _emeraldGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Payment Details',
                          style: TextStyle(color: _pearlWhite, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Payment Amount
                    TextFormField(
                      style: const TextStyle(color: _pearlWhite),
                      decoration: InputDecoration(
                        labelText: 'Payment Amount',
                        labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.attach_money_rounded, color: _emeraldGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _emeraldGreen),
                        ),
                        filled: true,
                        fillColor: _slateGray,
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _amountToPay.toStringAsFixed(2),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter payment amount';
                        }
                        double? amount = double.tryParse(value);
                        if (amount == null) {
                          return 'Please enter a valid number';
                        }
                        if (amount <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        if (amount > _remainingBalance) {
                          return 'Amount cannot exceed remaining balance';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        double? amount = double.tryParse(value);
                        if (amount != null) {
                          setState(() => _amountToPay = amount);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Quick amount buttons
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickAmountButton('Full', _remainingBalance),
                          const SizedBox(width: 8),
                          _buildQuickAmountButton('Half', _remainingBalance / 2),
                          const SizedBox(width: 8),
                          _buildQuickAmountButton('25%', _remainingBalance * 0.25),
                          const SizedBox(width: 8),
                          _buildQuickAmountButton('10%', _remainingBalance * 0.1),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Reference (optional)
                    TextFormField(
                      style: const TextStyle(color: _pearlWhite),
                      decoration: InputDecoration(
                        labelText: 'Reference / Transaction ID (Optional)',
                        labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.receipt_rounded, color: _skyBlue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _skyBlue),
                        ),
                        filled: true,
                        fillColor: _slateGray,
                      ),
                      onChanged: (value) => _paymentReference = value,
                    ),

                    const SizedBox(height: 16),

                    // Payment Date
                    InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now(),
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
                          setState(() => _paymentDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: _slateGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _pearlWhite.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: _deepPurple, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Date',
                                  style: TextStyle(
                                    color: _pearlWhite.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDate(_paymentDate),
                                  style: const TextStyle(
                                    color: _pearlWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Discount Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_charcoalBlue, _charcoalBlue.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _applyDiscount ? _amberGlow.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Row(
                        children: [
                          Icon(Icons.discount_rounded, color: _applyDiscount ? _amberGlow : _pearlWhite.withOpacity(0.5)),
                          const SizedBox(width: 12),
                          const Text(
                            'Apply Discount',
                            style: TextStyle(color: _pearlWhite, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      value: _applyDiscount,
                      activeColor: _amberGlow,
                      onChanged: (value) {
                        setState(() => _applyDiscount = value);
                      },
                    ),

                    if (_applyDiscount) ...[
                      const SizedBox(height: 16),

                      TextFormField(
                        style: const TextStyle(color: _pearlWhite),
                        decoration: InputDecoration(
                          labelText: 'Discount Amount',
                          labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.discount_rounded, color: _amberGlow),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _amberGlow),
                          ),
                          filled: true,
                          fillColor: _slateGray,
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _discountAmount.toString(),
                        onChanged: (value) {
                          double? amount = double.tryParse(value);
                          if (amount != null) {
                            setState(() => _discountAmount = amount);
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        style: const TextStyle(color: _pearlWhite),
                        decoration: InputDecoration(
                          labelText: 'Discount Reason (Optional)',
                          labelStyle: TextStyle(color: _pearlWhite.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.note_rounded, color: _skyBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _pearlWhite.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _skyBlue),
                          ),
                          filled: true,
                          fillColor: _slateGray,
                        ),
                        onChanged: (value) => _discountReason = value,
                      ),

                      if (_discountAmount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _amberGlow.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _amberGlow.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'New Balance After Discount:',
                                style: TextStyle(color: _pearlWhite, fontSize: 13),
                              ),
                              Text(
                                '\$${(_remainingBalance - _discountAmount - _amountToPay).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: _amberGlow,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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

              const SizedBox(height: 30),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _pearlWhite,
                        side: BorderSide(color: _pearlWhite.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _emeraldGreen,
                        foregroundColor: _pearlWhite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: _pearlWhite, strokeWidth: 2),
                      )
                          : const Text('Process Payment'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: _pearlWhite.withOpacity(0.6), fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: _pearlWhite, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(String label, double amount, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _pearlWhite.withOpacity(0.7),
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmountButton(String label, double amount) {
    return MaterialButton(
      onPressed: () {
        setState(() {
          _amountToPay = amount;
        });
      },
      color: _slateGray,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: _pearlWhite.withOpacity(0.7), fontSize: 11),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(color: _emeraldGreen, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}