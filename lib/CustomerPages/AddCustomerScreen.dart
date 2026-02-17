// screens/add_customer_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../Models/customer_model.dart';

class AddCustomerScreen extends StatefulWidget {
  final String? teamId;
  final String? teamName;
  final String? assignedTo;
  final String? assignedToName; // Add this line

  const AddCustomerScreen({
    super.key,
    this.teamId,
    this.teamName,
    this.assignedTo,
    this.assignedToName, // Add this line
  });

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _customersRef =
  FirebaseDatabase.instance.ref().child('customers');
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _teamsRef =
  FirebaseDatabase.instance.ref().child('teams');

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedStatus = 'Lead';
  bool _isLoading = false;
  Map<String, dynamic> _currentUser = {};
  List<Map<String, dynamic>> _availableTeams = [];
  List<Map<String, dynamic>> _availableWorkers = [];
  String? _selectedTeamId;
  String? _selectedTeamName;
  String? _selectedWorkerId;
  String? _selectedWorkerName;

  final List<String> _statusOptions = [
    'Lead',
    'Prospect',
    'Active',
    'Inactive',
  ];

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
    _loadInitialData();

    // Pre-fill team if provided
    if (widget.teamId != null && widget.teamName != null) {
      _selectedTeamId = widget.teamId;
      _selectedTeamName = widget.teamName;
    }

    // Pre-fill assigned worker if provided
    if (widget.assignedTo != null) {
      _selectedWorkerId = widget.assignedTo;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load current user data
      DatabaseEvent userEvent = await _usersRef.child(user.uid).once();
      if (userEvent.snapshot.value != null) {
        _currentUser =
        Map<String, dynamic>.from(userEvent.snapshot.value as Map);
      }

      // Load teams based on role
      await _loadTeams();

      // Load workers if manager
      if (_currentUser['role'] == 'Manager') {
        await _loadWorkers();
      }
    }
  }

  Future<void> _loadTeams() async {
    _availableTeams.clear();
    User? user = FirebaseAuth.instance.currentUser;

    DatabaseEvent teamsEvent = await _teamsRef.once();
    if (teamsEvent.snapshot.value != null) {
      Map<dynamic, dynamic> teamsMap =
      teamsEvent.snapshot.value as Map<dynamic, dynamic>;

      teamsMap.forEach((teamId, teamData) {
        Map<String, dynamic> team = Map<String, dynamic>.from(teamData as Map);

        // Managers see only their teams, Workers see their team
        if (_currentUser['role'] == 'Manager' && team['managerId'] == user?.uid) {
          team['id'] = teamId;
          _availableTeams.add(team);
        } else if (_currentUser['role'] == 'Worker' &&
            team['id'] == _currentUser['teamId']) {
          team['id'] = teamId;
          _availableTeams.add(team);
        }
      });
    }
  }

  Future<void> _loadWorkers() async {
    _availableWorkers.clear();
    User? currentUser = FirebaseAuth.instance.currentUser;

    DatabaseEvent usersEvent = await _usersRef.once();
    if (usersEvent.snapshot.value != null) {
      Map<dynamic, dynamic> usersMap =
      usersEvent.snapshot.value as Map<dynamic, dynamic>;

      usersMap.forEach((uid, userData) {
        Map<String, dynamic> user = Map<String, dynamic>.from(userData as Map);
        // Fix: workers whose manager is the current user
        if (user['role'] == 'Worker' &&
            user['managerId'] == currentUser?.uid &&
            user['isActive'] == true) {
          user['uid'] = uid;
          _availableWorkers.add(user);
        }
      });
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String customerId = _customersRef.push().key ??
          DateTime.now().millisecondsSinceEpoch.toString();

      CustomerModel customer = CustomerModel(
        id: customerId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        company: _companyController.text.trim().isNotEmpty
            ? _companyController.text.trim()
            : null,
        status: _selectedStatus,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user?.uid ?? '',
        createdByName: _currentUser['name'] ?? 'Unknown',
        createdByRole: _currentUser['role'] ?? 'Worker',
        assignedTo: _selectedWorkerId,
        assignedToName: _selectedWorkerName,
        teamId: _selectedTeamId,
        teamName: _selectedTeamName,
      );

      await _customersRef.child(customerId).set(customer.toMap());

      // Update team customer count if team is selected
      if (_selectedTeamId != null) {
        DatabaseEvent teamEvent =
        await _teamsRef.child(_selectedTeamId!).child('customerCount').once();
        int currentCount = teamEvent.snapshot.value as int? ?? 0;
        await _teamsRef
            .child(_selectedTeamId!)
            .child('customerCount')
            .set(currentCount + 1);
      }

      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackBar('✅ Customer added successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to add customer: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      case 'Lead':
        return _skyBlue;
      case 'Prospect':
        return _amberGlow;
      case 'Active':
        return _emeraldGreen;
      case 'Inactive':
        return _steelGray;
      default:
        return _steelGray;
    }
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
                Icons.person_add_alt_1_rounded,
                color: _pearlWhite,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Customer',
              style: TextStyle(
                color: _pearlWhite,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _currentUser['role'] == 'Manager'
                  ? _deepPurple.withOpacity(0.2)
                  : _skyBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _currentUser['role'] == 'Manager'
                      ? Icons.manage_accounts_rounded
                      : Icons.engineering_rounded,
                  size: 16,
                  color: _currentUser['role'] == 'Manager'
                      ? _deepPurple
                      : _skyBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  _currentUser['role'] ?? 'Worker',
                  style: TextStyle(
                    color: _currentUser['role'] == 'Manager'
                        ? _deepPurple
                        : _skyBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Selection
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
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
                        const Text(
                          'Customer Status',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _statusOptions.map((status) {
                              bool isSelected = _selectedStatus == status;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedStatus = status;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                      colors: [
                                        _getStatusColor(status),
                                        _getStatusColor(status)
                                            .withOpacity(0.7),
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
                                          ? _getStatusColor(status)
                                          : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _pearlWhite
                                              : _getStatusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          color: isSelected
                                              ? _pearlWhite
                                              : _getStatusColor(status),
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          fontSize: 14,
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

                  // Basic Information
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
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
                                color: _deepPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: _deepPurple,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Basic Information',
                              style: TextStyle(
                                color: _pearlWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'John Doe',
                          icon: Icons.person_outline_rounded,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'john@company.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Invalid email format';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: '+1 (555) 000-0000',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  // Additional Details
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
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
                                Icons.business_center_rounded,
                                color: _skyBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Additional Details',
                              style: TextStyle(
                                color: _pearlWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _companyController,
                          label: 'Company (Optional)',
                          hint: 'Acme Inc.',
                          icon: Icons.business_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address (Optional)',
                          hint: '123 Main St, City, State',
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                  // Assignment Section
                  if (_currentUser['role'] == 'Manager' ||
                      _availableTeams.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
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
                                  Icons.assignment_rounded,
                                  color: _amberGlow,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Assignment',
                                style: TextStyle(
                                  color: _pearlWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Team Selection
                          if (_availableTeams.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: _slateGray,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedTeamId,
                                dropdownColor: _charcoalBlue,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _pearlWhite.withOpacity(0.5),
                                ),
                                style: const TextStyle(
                                  color: _pearlWhite,
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 12,
                                  ),
                                ),
                                hint: Text(
                                  'Select Team (Optional)',
                                  style: TextStyle(
                                    color: _pearlWhite.withOpacity(0.5),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'None',
                                      style: TextStyle(color: _pearlWhite),
                                    ),
                                  ),
                                  ..._availableTeams.map((team) {
                                    return DropdownMenuItem(
                                      value: team['id'],
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.group_rounded,
                                            size: 16,
                                            color: _deepPurple,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            team['name'],
                                            style: const TextStyle(
                                              color: _pearlWhite,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTeamId = value;
                                    if (value != null) {
                                      var team = _availableTeams.firstWhere(
                                              (t) => t['id'] == value);
                                      _selectedTeamName = team['name'];
                                    } else {
                                      _selectedTeamName = null;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Worker Assignment (for Managers)
                          if (_currentUser['role'] == 'Manager' &&
                              _availableWorkers.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: _slateGray,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedWorkerId,
                                dropdownColor: _charcoalBlue,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _pearlWhite.withOpacity(0.5),
                                ),
                                style: const TextStyle(
                                  color: _pearlWhite,
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 12,
                                  ),
                                ),
                                hint: Text(
                                  'Assign to Worker (Optional)',
                                  style: TextStyle(
                                    color: _pearlWhite.withOpacity(0.5),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'Unassigned',
                                      style: TextStyle(color: _pearlWhite),
                                    ),
                                  ),
                                  ..._availableWorkers.map((worker) {
                                    return DropdownMenuItem(
                                      value: worker['uid'],
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: _skyBlue,
                                            child: Text(
                                              (worker['name'] ?? 'W')[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: _pearlWhite,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            worker['name'],
                                            style: const TextStyle(
                                              color: _pearlWhite,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedWorkerId = value;
                                    if (value != null) {
                                      var worker = _availableWorkers.firstWhere(
                                              (w) => w['uid'] == value);
                                      _selectedWorkerName = worker['name'];
                                    } else {
                                      _selectedWorkerName = null;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Notes
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
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
                              'Notes',
                              style: TextStyle(
                                color: _pearlWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _notesController,
                          label: 'Additional Notes (Optional)',
                          hint: 'Any special requirements, preferences, etc.',
                          icon: Icons.edit_note_rounded,
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),

                  // Submit Button
                  Container(
                    width: double.infinity,
                    height: 56,
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
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _pearlWhite),
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.save_rounded),
                          SizedBox(width: 12),
                          Text(
                            'Save Customer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _pearlWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: _pearlWhite, fontSize: 15),
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                icon,
                color: _deepPurple.withOpacity(0.8),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}